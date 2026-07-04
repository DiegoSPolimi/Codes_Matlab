# MATLAB → Python Translation Plan

This document is the working brief for translating this repository to Python.
It is written for **Fable 5**, which will perform the actual code translation.
Claude (Sonnet 5) prepared this brief by reading every `.m` file and the sample
data in `Example_Acquisitions/`; it will not write the Python code itself.

## 1. What this project does

This is a biomechanics motion-capture pipeline built around **Movella DOT IMU
sensors** (quaternion-output wearables) and, secondarily, an **EMG envelope
viewer**. The pipeline:

1. Records raw per-sensor CSVs (one file per IMU per trial) with quaternion,
   accelerometer, gyroscope, and (on some sensors) EMG-envelope channels.
2. **Calibrates** each sensor: from a static "N-pose" (or supine/seated) trial,
   computes a fixed **sensor-to-segment rotation matrix** so that a segment's
   anatomical axes (Mediolateral/Anteroposterior/Longitudinal, i.e. ML/AP/Long)
   can be recovered from the raw sensor orientation at any later time.
3. **Reorders/synchronizes** movement trial CSVs across sensors (timestamps
   can arrive out of order; sensors must be time-aligned before joint angles
   are computed). Two alignment strategies exist: accelerometer-peak sync and
   quaternion-rotation-cycle sync (for cyclic motions like pedalling).
4. Computes **segment orientation** over time (sensor quaternion → global
   rotation matrix → anatomical segment rotation matrix).
5. Computes **3D joint angles** (hip, knee, and pelvis-vs-global) using the
   **Grood & Suntay (1983) Joint Coordinate System** (JCS) — the ISB-standard
   floating-axis method that avoids gimbal-lock/cross-talk of Euler sequences.
6. Plots and exports (Excel) the resulting joint angle time series, including
   pedalling-cycle-normalized ensemble averages (mean ± std across cycles).
7. Separately, plots EMG envelope channels (independent of the IMU pipeline).

The codebase is a **research script collection**, not a polished library: most
files were iterated on directly in MATLAB, with older attempts left in as
commented-out blocks above the current, active code. Section 3 tells you
exactly which block is "live" per file.

## 2. Data contract (must be preserved exactly)

- CSV columns (see `Example_Acquisitions/*.csv`):
  `Timestamp_Local_Human, Timestamp_Local_EpochMs, Timestamp_Arduino,
  DeviceName, DeviceAddress, Ax, Ay, Az, Gx, Gy, Gz, Q0, Q1, Q2, Q3,
  Env1, Env2, Env3, Env4`.
- Quaternion columns `Q0,Q1,Q2,Q3` are **scalar-first** (`w,x,y,z`), the
  Movella DOT convention. **This is the single biggest source of silent bugs
  in translation**: SciPy's `Rotation.from_quat` expects **scalar-last**
  `(x,y,z,w)`. Any Python quaternion code must explicitly reorder
  `[Q1,Q2,Q3,Q0]` before handing off to SciPy, or implement rotation-matrix
  conversion by hand to match MATLAB's `quat2rotm`/`quaternion`/`rotmat`
  behavior. Get this wrong and every downstream angle is wrong but
  plausible-looking — validate numerically (see Section 7).
- **CONVENTION LOCKED (confirmed while building the reference generator):**
  the repo uses `quat2rotm(q)` (in `computeStaticCalibration`) and
  `rotmat(quaternion(q),'point')` (in `computeSegmentOrientation`). Both are
  the **standard ACTIVE rotation matrix from a scalar-first unit quaternion**,
  i.e. the explicit matrix:
  `R = [[1-2(y²+z²), 2(xy-wz), 2(xz+wy)], [2(xy+wz), 1-2(x²+z²), 2(yz-wx)], [2(xz-wy), 2(yz+wx), 1-2(x²+y²)]]`.
  The Python equivalent is `Rotation.from_quat([x,y,z,w]).as_matrix()` (after
  the scalar-first→scalar-last reorder) — SciPy's `as_matrix()` is active, so
  it matches `'point'`/`quat2rotm`. Centralize this one function in
  `quaternion.py` and test it against the explicit formula above.
- **Toolbox dependency:** `quat2rotm`/`quaternion`/`rotmat` require MATLAB's
  Robotics/Navigation/UAV Toolbox, which the user does **not** have. This
  means the original `.m` pipeline is not runnable end-to-end on the user's
  machine as-is; the Python port removes that dependency (NumPy/SciPy only),
  which is a real benefit to call out. The reference generator
  (`generate_reference.m`) reproduces the two conversions with plain math
  (`local_q2R`) so golden files can still be produced toolbox-free.
- Sensor name prefixes encode the body segment and are used for file
  matching: `S2` = pelvis/sacrum, `LT`/`RT` = left/right thigh, `LShank`
  (right shank never appears in current scripts, only left), `LFoot`
  (referenced in one plotting label but never actually loaded/used anywhere).
- Filenames encode metadata by substring match (case-insensitive), e.g.
  `LT_20260703_172624_Static_N_Pose.csv`, `<prefix>_<timestamp>.csv`, or a
  free keyword like `Bike_test_1` / `Knee_FE_movement` / `Hip_AA_movement`.
  Calibration files are matched by sensor prefix + posture keywords
  (`static`+`n_pose` / `static`+`supine` / `static`+`seated`).
- Segment orientation matrices `R(:,:,k)` are 3×3, **columns = segment axes
  in global coordinates**: column 1 = ML, column 2 = AP, column 3 =
  Longitudinal. This convention is load-bearing for every JCS computation —
  keep it as the convention in Python (e.g. a `(N,3,3)` NumPy array with the
  same column meaning, not transposed).
- Angles are always in **degrees** on output (`atan2d`, `asind`, `acosd`).
- Sampling rate is hardcoded in scripts as `Fs = 60` (Hz).

## 3. File-by-file inventory and "which code is actually live"

Several files contain 3–5 stacked historical versions of the same function,
each fully commented out, with only the final block active. **Only translate
the active (uncommented) code.** The commented history is useful *context*
(it explains why a design choice was made) but should not become dead code or
alternate code paths in Python unless explicitly noted below as worth keeping
as an option.

| File | Role | Active code = | Notes |
|---|---|---|---|
| `normalizeVector.m` | util | whole file | trivial `v/norm(v)` |
| `meanQuaternion.m` | util | whole file | Markley eigenvector method: builds `A = Σ qᵢqᵢᵀ`, returns eigenvector of largest eigenvalue. Standard, keep as-is. |
| `computeStaticCalibration.m` | calibration | whole file | mean quaternion → normalize → `quat2rotm` → **transpose** → `RsegSens`. Preserve the transpose exactly; it's what converts "segment orientation" to "sensor-to-segment". |
| `computeSegmentOrientation.m` | core | function starting at line 32 (the top ~30 lines are the superseded first draft) | Builds `RsegGlobal(:,:,k) = RsensGlobal * RsegSens` per frame, where `RsensGlobal = rotmat(quaternion(Quat(k,:)), 'point')`. The `'point'` vs `'frame'` MATLAB convention matters — validate against MATLAB output on sample data, don't assume SciPy's `as_matrix()` is a 1:1 match without checking. |
| `computeHipJCS.m` | core | whole file | Grood & Suntay hip angles from `RPelvis`, `RThigh`. **Offset removal is currently disabled** (the block near the bottom that would subtract a static-frame baseline is commented out) — Python output must also apply **no offset** to match current behavior. Field names: `Hip.FlexExt`, `Hip.AbdAdd`, `Hip.IntExt` (note: the file's own header comment says `Hip.AddAbd` — that's a stale comment, the real field is `AbdAdd`; trust the code, not the docstring). |
| `computeKneeJCS.m` | core | the block starting `%% MAYBE BETTER VERSION FROM MODIFIED VERSION OF COMPUTE SEGMENT ORIENTATION` (currently lines ~302–368; search for `function Knee = computeKneeJCS(RThigh,RShank)` that is **not** prefixed with `%`) | Everything above and below that block (4 other full alternate implementations) is dead/commented. The live version uses `e1=It, e3=Ks, e2=cross(e3,e1)` floating axis, then applies **"Strategy A" offset removal**: `offset_FE = max(FlexExt)`, `offset_VV = VarusValgus(1)`, `offset_IE = IntExt(1)` (Strategies B/C are commented alternatives — worth exposing as a Python parameter/enum rather than deleting, since they're clearly deliberate design options the author was comparing). |
| `loadIMUcsv.m` | io | function at line 41 (bottom) | Reads CSV, requires columns `Q0..Q3`, returns `Data.Quat` only (an earlier draft also extracted Time/Acc/Gyr — not used downstream by the live code, but harmless to include in Python for completeness/EMG reuse). |
| `exportExcel.m` | io | whole file | Builds a table with `Time`, `FlexExt`, and any of `AbdAdd`/`VarusValgus`/`IntExt` present on the struct, writes `<JointName>_Angles.xlsx`. In Python: pandas `DataFrame.to_excel` (needs `openpyxl`). |
| `plotAngles.m` | viz | function at line 49 (bottom); ignore the earlier commented draft | 3-subplot figure; adapts row 1/2 titles based on which fields are present (`FlexExt`/`Tilt`, `AbdAdd`/`VarusValgus`/`Obliquity`, `IntExt`/`Rotation`) so it works for Hip, Knee, and Pelvis-global structs alike. |
| `plotCalibrationFrames.m` | viz | whole file | 3D quiver plot comparing sensor axes vs. calibrated anatomical axes for segments `{'LT','S2'}` (hardcoded list — note this ignores RT/LShank even if calibrated). |
| `main_Calibration_STATIC.m` | entry point | whole file | Auto-detects calibration files per sensor (`S2`,`LT`,`RT`) via folder picker + posture menu, computes `RsegSens` per sensor, saves `CalibrationResults.mat`, plots frames, prints orthogonality/determinant checks. No axis-correction, no reordering. |
| `Calibration_STATIC_V2.m` | entry point | bottom block only (everything above the line `%%%%...%\n%\n% 01_CALIBRATION (With Axis Swapping for S2)` is dead history) | Same as above but loads via `loadAndReorderIMUcsv` (sorts rows by `Timestamp_Arduino`, writes a `_REORDERED` copy) and has an **S2 axis-swap correction block present but commented out** (swaps ML/Long columns with a sign flip to keep det=+1). Sensor list here is `{'S2','LT','LShank'}` (differs from the other calibration scripts — likely stale). |
| `Calibration_STATIC_V2_MANUAL.m` | entry point | whole file | Manual multi-select file picker (no folder/posture menu) that infers sensor identity from filename substring (`s2`/`lt`/`rt`/`lshank`). Same S2 axis-swap block, also present but commented out. Sensor list `{'S2','LT','RT'}`. |
| `main_lowerLimbAngles_V2.m` | entry point | bottom block only (search for the last `clear\nclc\nclose all` — everything above, including an entirely different earlier "Bike_test_1 / reordering" attempt, is dead) | Auto file-matching by `movementKeyword` (currently hardcoded `'Knee_FE_movement'`), computes left Hip + Knee, plots, exports Excel. Uses `Calibration.LT` (not `LThigh`) — keep this naming consistent. |
| `main_Compute_LL_Angles_V2.m` | entry point | bottom block only (2 dead history blocks above: a plain "Bike_test_1" version and a fully commented `_SYNCHRONIZED` version whose only diff from the live one is variable/section renaming) | Same as above but expects pre-synchronized files tagged `REORDERED` and loads with `loadCleanIMUcsv` (no timestamp sort, assumes already clean). |
| `main_Compute_Angles_MANUAL.m` | entry point | bottom block only (one large dead history block above computing only `LThigh`, superseded by the bilateral version) | The richest script: manual file picks for Pelvis/LThigh/RThigh, computes **left hip, right hip, and pelvis-vs-global angles**, crops all to common minimum length, detects pedalling cycles from left-hip flexion (`findpeaks` on `-hipFlexion`), time-normalizes each cycle to 0–100% (`interp1 ... 'spline'`, 101 points), computes per-cycle mean±std, and produces "journal quality" ensemble plots (individual gray traces + std band + bold mean) for hip×2 and pelvis. Also has a local `computePelvisGlobalAngles`/`ea2euler` (pitch/roll/yaw from a rotation matrix via a custom gimbal-safe formula). Exports only Left/Right hip Excel (pelvis not exported — matches current behavior). |
| `main_Compute_Angles_MANUAL.asv` | **discard** | — | Stale MATLAB autosave, superseded by the `.m` file (diffed, confirmed to be an older bilateral-in-progress edit). Do not translate; do not carry into the Python repo. |
| `main_Reordering.m` | entry point | bottom block only (2 dead history blocks: plain timestamp-sort-only, and an accelerometer-peak-to-peak sync version) | Live version: reorders by timestamp, then finds "trough" boundaries in a smoothed quaternion-rotation-angle signal (`findpeaks` on negated signal) to bound one full movement window, then resamples every column (`interp1 linear` for numeric, nearest-neighbor index mapping for non-numeric) to a common `targetLength` across all selected files, saving `<name>_REORDERED.csv`. |
| `Main_VISUALIZATION.m` | entry point | whole file (single version, no dead history) | Manual multi-file picker, synchronizes via **accelerometer-magnitude peak** within first `SyncWindowSeconds`, truncates to common length, then opens an **interactive plot with `ginput(2)`** for the user to click a start/end crop window, applies the crop, writes `_CROPPED` CSVs (full original columns, not just Quat), then plots Acc/Gyr/Quat per sensor. |
| `EMG_Plotting.m` | entry point, independent | bottom block (~line 54 on); the top block is an older single-file-path version, now replaced by a `uigetfile` picker | Reads `Env1..Env4` as `Right_TFL, Right_GMed, Left_TFL, Left_GMed` (note: **column-to-label mapping changed** between the dead top block and the live bottom block — the live one maps `Env2→Right_GMed` and `Env3→Left_TFL`, swapped from the dead version's `Env2→Left_TFL`. Trust the live mapping.). Plots 4 stacked subplots. Currently plots by **sample index, not time** (the `time` x-axis code is present but commented out in the live block) — preserve that (no x-axis time conversion in the default plot). |

## 4. MATLAB → Python mapping

| MATLAB | Python replacement |
|---|---|
| `readtable`, `detectImportOptions`, `writetable` | `pandas.read_csv`, `pandas.DataFrame.to_csv` |
| `quaternion(q)`, `rotmat(q,'point'/'frame')`, `quat2rotm` | `scipy.spatial.transform.Rotation` — **reorder scalar-first → scalar-last first** (see Section 2). Validate `'point'` vs `'frame'` against MATLAB numerically; don't assume. |
| `eig`, `vecnorm`, `cross`, `dot`, `norm` | `numpy.linalg.eig`, `numpy.linalg.norm(axis=...)`, `numpy.cross`, `numpy.dot`/`@`, `numpy.linalg.norm` |
| `atan2d`, `asind`, `acosd`, `rad2deg`/`deg2rad` | `numpy.degrees(numpy.arctan2(...))`, `numpy.degrees(numpy.arcsin(...))`, etc. (NumPy trig has no `*d` degree variants — wrap every call) |
| `findpeaks(..., 'MinPeakDistance', 'MinPeakProminence')` | `scipy.signal.find_peaks(..., distance=..., prominence=...)` |
| `interp1(..., 'spline')` / `'linear'` | `scipy.interpolate.CubicSpline` (or `interp1d(kind='cubic')`) / `numpy.interp` |
| `movmean` | `pandas.Series.rolling(window, center=True).mean()` |
| `writetable` to `.xlsx` | `pandas.DataFrame.to_excel` (needs `openpyxl`) |
| `save(...,'.mat')` / `load` | Prefer a Python-native format (`json`/`npz`/`pickle`) for `CalibrationResults`; **only** use `scipy.io.savemat`/`loadmat` if the user needs the `.mat` file to remain interoperable with existing MATLAB tooling — ask if unsure. |
| `uigetdir`, `uigetfile(...,'MultiSelect','on')` | `tkinter.filedialog.askdirectory` / `askopenfilenames` — see open decision in Section 6 |
| `menu(...)` | simple `input()` prompt, or a tiny `tkinter` dialog for parity |
| `ginput(2)` | `matplotlib`'s `plt.ginput(2)` is a near-exact drop-in replacement |
| `figure/subplot/quiver3/plot3` | `matplotlib` (`mpl_toolkits.mplot3d` for `quiver3`/`plot3`) |
| 3-D arrays `R(:,:,k)` (3×3×N) | NumPy array shaped `(N,3,3)` (put the frame index first — more natural for vectorized NumPy ops); just be consistent and update every consumer |

## 5. Proposed Python architecture

Consolidate the duplicated boilerplate (`findFileCaseInsensitive`,
`loadAndReorderIMUcsv`/`loadCleanIMUcsv`, calibration file-matching) that is
currently copy-pasted across 6+ scripts into shared modules. Recommended
layout:

```
imu_kinematics/
  io.py            # CSV loading (raw / reordered / clean), sensor-file matching, Excel export
  quaternion.py    # normalizeVector, meanQuaternion, quat<->rotmat helpers (with the scalar-first/last reorder centralized here)
  calibration.py   # computeStaticCalibration, optional S2 axis-swap correction
  orientation.py   # computeSegmentOrientation
  joint_angles.py  # computeHipJCS, computeKneeJCS (with Strategy A/B/C offset as a parameter), computePelvisGlobalAngles/ea2euler
  cycles.py        # pedalling cycle detection + time-normalization + ensemble stats (from main_Compute_Angles_MANUAL.m)
  sync.py          # accelerometer-peak sync (Main_VISUALIZATION) + quaternion-cycle sync/resample (main_Reordering)
  plotting.py       # plotAngles, plotCalibrationFrames, EMG plot, sync/crop plots
scripts/
  calibrate.py       # replaces main_Calibration_STATIC / Calibration_STATIC_V2 / Calibration_STATIC_V2_MANUAL, unified via CLI flags: --manual/--auto, --reorder, --fix-s2-axis
  compute_angles.py  # replaces main_lowerLimbAngles_V2 / main_Compute_LL_Angles_V2 / main_Compute_Angles_MANUAL, unified via a --mode flag (auto | presynced | manual-bilateral)
  reorder_sync.py    # replaces main_Reordering.m
  visualize_sync.py  # replaces Main_VISUALIZATION.m
  emg_plot.py         # replaces EMG_Plotting.m
tests/
  ...
requirements.txt   # numpy, scipy, pandas, matplotlib, openpyxl
```

Do **not** collapse the three calibration scripts or three angle-computation
scripts silently — they have real behavioral differences (sensor lists,
axis-correction toggle, manual vs. auto file discovery, bilateral vs.
unilateral, cycle-normalization). Unify them behind explicit flags/parameters
so no functionality is lost, and document each flag's MATLAB origin in a
docstring or comment.

## 6. Open decisions to confirm with the user before/while translating

- **GUI parity**: keep interactive folder/file pickers (`tkinter.filedialog`)
  and an interactive click-crop (`plt.ginput`), or move to a non-interactive
  CLI (`argparse` with explicit paths) for scriptability/testability? Given
  this is a fairly manual research workflow, recommend: keep interactive
  dialogs as the default entry point, but make every underlying function
  accept explicit paths so it's independently testable/scriptable.
- **`.mat` calibration file**: keep `CalibrationResults.mat` for
  interoperability, or switch to a Python-native format? Only keep `.mat` if
  the user still needs to load it from MATLAB elsewhere.
- **Dead alternate strategies** (Strategy B/C offset removal in
  `computeKneeJCS`, S2 axis-swap correction, hip offset removal): expose as
  optional parameters (recommended, since they're clearly considered
  alternatives) vs. drop entirely to match only the exact current behavior.

## 7. Validation strategy (important — do not skip)

This pipeline has subtle rotation-convention pitfalls (Section 2). Before
trusting any Python output:

1. Use the real sample data in `Example_Acquisitions/` (`S2`/`LT`/`RT`,
   static N-pose + two movement trials) as the golden test input — it's
   already in the repo and covers calibration + at least one full
   angle-computation pass (pelvis + bilateral thigh, no shank data present,
   so knee angles can't be validated end-to-end with this sample — hip and
   pelvis can).
2. If MATLAB is available, run the equivalent `.m` pipeline once on this
   sample data and save the intermediate `RsegSens`, per-frame `RsegGlobal`,
   and final joint-angle arrays as reference CSVs. Write a Python test that
   reproduces them within a small numeric tolerance (e.g. 1e-6 for rotation
   matrices, 1e-3 deg for angles).
3. At minimum, without MATLAB available, unit-test the invariants MATLAB
   itself checks: `det(RsegSens) ≈ +1`, `RᵀR ≈ I` (orthogonality), quaternion
   unit norm after `meanQuaternion`.
4. Specifically unit-test the quaternion→rotation-matrix conversion against a
   few hand-computed cases (e.g. 90° rotations about each axis) to lock down
   the scalar-first/last and point/frame conventions before building anything
   on top of it — this is the highest-risk translation step in the whole
   project.

## 8. Suggested translation order

1. `quaternion.py` (normalizeVector, meanQuaternion) + its convention unit
   tests (Section 7.4) — get this exactly right first, everything else
   depends on it.
2. `calibration.py` (computeStaticCalibration) + `orientation.py`
   (computeSegmentOrientation).
3. `joint_angles.py` (computeHipJCS, computeKneeJCS, computePelvisGlobalAngles).
4. `io.py` (CSV load/save, sensor-file matching) + `plotting.py` (plotAngles,
   plotCalibrationFrames) + Excel export.
5. `scripts/calibrate.py` (merges the 3 calibration entry points).
6. `sync.py` + `scripts/reorder_sync.py` + `scripts/visualize_sync.py`.
7. `cycles.py` + `scripts/compute_angles.py` (merges the 3 angle-computation
   entry points, including the pedalling-cycle ensemble-average path).
8. `scripts/emg_plot.py` (independent, can also be done in parallel any time).
