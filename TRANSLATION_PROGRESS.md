# MATLAB → Python Translation Progress

Tracker for the `/loop` translation. Order follows Section 8 of
`PYTHON_TRANSLATION_PLAN.md`. One item per iteration; each must be green
(golden-file match where a reference exists, else invariant tests) before the
next starts.

## Checklist

- [x] 1. `imu_kinematics/quaternion.py` — normalizeVector, meanQuaternion, quat↔rotmat helpers. **Done:** 10 tests green — convention lock (scalar-first→last + active rotation == `quat2rotm` == SciPy scalar-last) AND golden `ref_meanQuaternion_LT.csv` matched to 1e-6 (with eigenvector sign alignment).
- [x] 2. `imu_kinematics/calibration.py` (computeStaticCalibration + opt-in `apply_s2_axis_swap`) + `imu_kinematics/orientation.py` (computeSegmentOrientation → `(N,3,3)`). **Done:** 10 tests green — `ref_RsegSens_{S2,LT,RT}` and `ref_RsegGlobal_{S2,LT,RT}` matched to 1e-6, plus orthonormality/det invariants. S2 axis-swap exposed as optional per Section 6.
- [x] 3. `imu_kinematics/joint_angles.py` — computeHipJCS (no offset), computeKneeJCS (Strategy A default; B/C/None param), computePelvisGlobalAngles/ea2euler. **Done:** hip L/R, knee, pelvis-global all matched golden files to 1e-3°; full suite 24/24 green. Hip field is `AbdAdd` (code, not the stale `AddAbd` docstring).
- [x] 4. `imu_kinematics/io.py` (load_imu_csv[+reorder], load_raw_imu_csv, find_file_case_insensitive, export_excel) + `imu_kinematics/plotting.py` (plot_angles, plot_calibration_frames). **Done (invariant/structural — no golden refs):** 8 tests green — load shapes, reorder actually sorts by Timestamp_Arduino, file-matching + missing-raises, Excel round-trip columns, both plot funcs build correct axes under Agg backend.
- [x] 5. `scripts/calibrate.py` — merges the 3 calibration entry points behind `--data-folder/--manual`, `--posture`, `--reorder`, `--fix-s2-axis`, `--mat`. **Done:** 4 tests green — auto-match → `run_calibration` reproduces golden `RsegSens` to 1e-6, JSON write, `--fix-s2-axis` changes only S2. Interactive tkinter fallback kept; JSON default output (Section 6), `--mat` opt-in.
- [x] 6. `imu_kinematics/sync.py` (movmean, acc_peak_index, synchronize_by_acc_peak, quaternion_rotation_angle, detect_cycle_troughs, resample_table) + `scripts/reorder_sync.py` + `scripts/visualize_sync.py`. **Done (invariant/structural):** 7 tests green — movmean vs hand calc, acc peak in-window, equal-length sync, rotation-angle≈0 at frame 0, resample length/endpoints, reorder writes equal-length outputs (cycle detection ran on sample data), acc-peak sync+crop equal length. Interactive ginput/pickers isolated in scripts; testable cores take explicit crop fractions/paths.
- [x] 7. `imu_kinematics/cycles.py` (detect_pedalling_cycles, normalize_cycles [not-a-knot cubic spline == MATLAB 'spline'], ensemble_stats [ddof=0]) + `scripts/compute_angles.py` (--mode auto|presynced|manual-bilateral, loads JSON/.mat calibration, Fs=60). **Done:** 4 tests green — cycle detection/normalization/stats invariants AND full pipeline `compute_manual_bilateral` reproduces golden L/R hip + pelvis-global to 1e-3° through calibration JSON → orientation → angles.
- [x] 8. `scripts/emg_plot.py` (EMG_Plotting, independent). **Done:** 4 tests green — live channel mapping order (Env1 R-TFL, Env3 L-TFL, Env2 R-GMed, Env4 L-GMed), load columns, missing-raises, 4-axes figure. Plots by sample index (no time axis) per live block.

## FINAL SUMMARY — translation complete (all 8 items ✅)

**Status:** MATLAB → Python port complete. **51/51 tests pass.**

### What was built
- Package `imu_kinematics/`: `quaternion`, `calibration`, `orientation`,
  `joint_angles`, `io`, `plotting`, `sync`, `cycles`.
- Entry points `scripts/`: `calibrate`, `compute_angles`, `reorder_sync`,
  `visualize_sync`, `emg_plot` — each merges its MATLAB predecessors behind
  flags with no loss of behavior.
- `tests/` with golden-file validation (from `generate_reference.m`) + invariant/
  structural tests. `requirements.txt`, `.gitignore`, `.venv/`.

### Validation confidence
- **Numerically golden (matched MATLAB to tolerance):** meanQuaternion,
  RsegSens (S2/LT/RT), per-frame RsegGlobal (all to 1e-6); hip L/R, knee,
  pelvis-global angles (to 1e-3°); and the same reproduced end-to-end through
  `scripts/compute_angles.compute_manual_bilateral`.
- **Invariant/structural only (no golden ref — interactive/IO/plot code):**
  io, plotting, sync primitives, cycle math, calibrate/emg scripts.
- **Convention lock verified:** scalar-first Movella quats ↔ scalar-last SciPy;
  `quat_to_rotmat` == `quat2rotm` == `rotmat('point')` == active rotation.

### Key decisions (all following plan Section 6 defaults)
- Calibration output = JSON by default; `--mat` opt-in for MATLAB interop.
- Interactive dialogs/ginput kept as default front-ends, but every core
  function takes explicit paths/params for scriptability + testing.
- Orientation stored `(N,3,3)` frame-first; columns = ML/AP/Long.
- Knee offset Strategy A default; B/C/None exposed as parameter.
- S2 axis-swap exposed as opt-in (`--fix-s2-axis` / `apply_s2_axis_swap`).
- Removes the MATLAB Robotics/Nav Toolbox dependency (NumPy/SciPy only).

### Not translated (intentional)
- `main_Compute_Angles_MANUAL.asv` (stale autosave) — discarded per plan.
- All commented-out historical code blocks in the `.m` files.

### Caveats / follow-ups for a human
- Knee angles were only regression-tested with LT-as-thigh/RT-as-shank (no
  shank sensor in the sample data) — biomechanically meaningful validation
  needs a real shank trial.
- Plotting/interactive scripts are smoke-tested (figures build under Agg), not
  visually compared to MATLAB figures.
- To re-validate after any change: `.venv/bin/python -m pytest tests/`.

## Notes / assumptions log

- (iter 5) Decision: calibration results saved as JSON by default (Python-native, Section 6); `--mat` opt-in via scipy.io.savemat for MATLAB interop. Interactive tkinter dialog is the no-args front-end; all real work in `run_calibration(files_by_sensor, ...)` for testability.
- (iter 2) Decisions: `RsegGlobal` stored as `(N,3,3)` (frame-first) per plan Section 4; golden Nx9 rows are row-major and reshape with C-order. S2 axis-swap kept as opt-in function (Section 6 default = expose). Orientation array column meaning = ML/AP/Long, matching MATLAB `R(:,:,k)`.
- (iter 1) Env: Python 3.9.6 venv at `.venv/`, deps in `requirements.txt` (numpy, scipy, pandas, matplotlib, openpyxl, pytest). Run tests with `.venv/bin/python -m pytest`. Package layout: `imu_kinematics/`, tests in `tests/` with golden-file helpers in `tests/conftest.py`. `.gitignore` added for venv/pycache.
