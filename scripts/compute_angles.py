"""Compute lower-limb joint angles (merges the 3 MATLAB angle entry points).

Modes (plan Section 5), preserving each script's real behavior:
  * ``auto``            -> ``main_lowerLimbAngles_V2.m`` (keyword file match, L hip+knee)
  * ``presynced``       -> ``main_Compute_LL_Angles_V2.m`` (REORDERED files)
  * ``manual-bilateral``-> ``main_Compute_Angles_MANUAL.m`` (L+R hip, pelvis-global,
    pedalling-cycle ensemble averaging)

Calibration is loaded from the JSON written by ``scripts/calibrate.py`` (or a
.mat via ``--mat``). Fs is fixed at 60 (data contract). The testable core
functions take explicit paths + a calibration dict.
"""

from __future__ import annotations

import argparse
import json
import os

import numpy as np

from imu_kinematics.io import load_imu_csv, export_excel
from imu_kinematics.calibration import compute_static_calibration
from imu_kinematics.orientation import compute_segment_orientation
from imu_kinematics.joint_angles import (
    compute_hip_jcs, compute_knee_jcs, compute_pelvis_global_angles,
)
from imu_kinematics.cycles import (
    detect_pedalling_cycles, normalize_cycles, ensemble_stats,
)

FS = 60


def load_calibration(path):
    """Load calibration; returns ``{sensor: 3x3 ndarray}``. JSON or .mat."""
    if path.endswith(".mat"):
        from scipy.io import loadmat
        m = loadmat(path, struct_as_record=False, squeeze_me=True)
        cal = m["Calibration"]
        return {name: np.asarray(getattr(cal, name).RsegSens)
                for name in cal._fieldnames}
    with open(path) as f:
        data = json.load(f)
    return {s: np.asarray(v["RsegSens"]) for s, v in data.items()}


def _orient(path, Rcal, reorder):
    quat = load_imu_csv(path, reorder=reorder)["Quat"]
    return compute_segment_orientation(quat, Rcal)


def compute_manual_bilateral(pelvis_csv, lthigh_csv, rthigh_csv, calibration,
                             reorder=False):
    """L+R hip + pelvis-global angles, cropped to common length. Returns dict."""
    Rp = _orient(pelvis_csv, calibration["S2"], reorder)
    Rl = _orient(lthigh_csv, calibration["LT"], reorder)
    Rr = _orient(rthigh_csv, calibration["RT"], reorder)
    n = min(Rp.shape[0], Rl.shape[0], Rr.shape[0])
    Rp, Rl, Rr = Rp[:n], Rl[:n], Rr[:n]

    time = np.arange(n) / FS
    return {
        "time": time,
        "LHip": compute_hip_jcs(Rp, Rl),
        "RHip": compute_hip_jcs(Rp, Rr),
        "Pelvis": compute_pelvis_global_angles(Rp),
    }


def analyze_session(files_by_role, calibration, reorder=False):
    """Full bilateral analysis from a role->CSV mapping + calibration dict.

    Computes whatever the available sensors allow:
      Pelvis (S2), LHip (S2+LT), RHip (S2+RT), LKnee (LT+LShank),
      RKnee (RT+RShank). All series cropped to the common frame count.
    Cycles are segmented from a hip-flexion reference (LHip, else RHip).

    Returns a dict with ``time`` (s), ``troughs`` (cycle boundary indices), and
    each available joint as a sub-dict of angle arrays.
    """
    orient = {}
    for role, path in files_by_role.items():
        if role in calibration:
            orient[role] = _orient(path, calibration[role], reorder)
    if not orient:
        raise ValueError("No uploaded file matched a calibrated sensor role.")

    n = min(o.shape[0] for o in orient.values())
    orient = {k: v[:n] for k, v in orient.items()}

    result = {"time": np.arange(n) / FS}
    if "S2" in orient:
        result["Pelvis"] = compute_pelvis_global_angles(orient["S2"])
        if "LT" in orient:
            result["LHip"] = compute_hip_jcs(orient["S2"], orient["LT"])
        if "RT" in orient:
            result["RHip"] = compute_hip_jcs(orient["S2"], orient["RT"])
    if "LT" in orient and "LShank" in orient:
        result["LKnee"] = compute_knee_jcs(orient["LT"], orient["LShank"])
    if "RT" in orient and "RShank" in orient:
        result["RKnee"] = compute_knee_jcs(orient["RT"], orient["RShank"])

    ref = result.get("LHip") or result.get("RHip")
    result["troughs"] = (
        detect_pedalling_cycles(ref["FlexExt"]) if ref is not None else np.array([], dtype=int)
    )
    return result


def cycle_ensemble(angle_series, field="FlexExt"):
    """Detect cycles from a hip flexion trace and return per-field mean±std.

    ``angle_series`` is a joint dict (e.g. LHip). Cycles are segmented from its
    ``field`` trace; every field is normalized/averaged over the cycles.
    """
    troughs = detect_pedalling_cycles(angle_series[field])
    if len(troughs) < 2:
        raise ValueError("Not enough pedalling cycles detected.")
    result = {}
    for name, values in angle_series.items():
        norm = normalize_cycles(values, troughs)
        mean, std = ensemble_stats(norm)
        result[name] = {"cycles": norm, "mean": mean, "std": std}
    return result


def main(argv=None):
    p = argparse.ArgumentParser(description="Compute lower-limb joint angles.")
    p.add_argument("--mode", choices=["auto", "presynced", "manual-bilateral"],
                   default="manual-bilateral")
    p.add_argument("--calibration", required=True, help="CalibrationResults.json/.mat")
    p.add_argument("--pelvis", help="Pelvis (S2) CSV")
    p.add_argument("--lthigh", help="Left thigh (LT) CSV")
    p.add_argument("--rthigh", help="Right thigh (RT) CSV")
    p.add_argument("--reorder", action="store_true")
    p.add_argument("--export-dir", help="Directory for *_Angles.xlsx output")
    args = p.parse_args(argv)

    calibration = load_calibration(args.calibration)

    if args.mode == "manual-bilateral":
        if not (args.pelvis and args.lthigh and args.rthigh):
            p.error("manual-bilateral needs --pelvis, --lthigh, --rthigh.")
        res = compute_manual_bilateral(args.pelvis, args.lthigh, args.rthigh,
                                       calibration, reorder=args.reorder)
        if args.export_dir:
            export_excel(res["time"], res["LHip"],
                         os.path.join(args.export_dir, "LeftHip"))
            export_excel(res["time"], res["RHip"],
                         os.path.join(args.export_dir, "RightHip"))
        print(f"Computed {len(res['time'])} frames of bilateral hip + pelvis angles.")
        return res

    # auto / presynced: single-limb (L hip + knee), presynced skips resort.
    if not (args.pelvis and args.lthigh):
        p.error(f"{args.mode} needs --pelvis and --lthigh (and --rthigh for knee).")
    reorder = args.reorder and args.mode == "auto"
    Rp = _orient(args.pelvis, calibration["S2"], reorder)
    Rl = _orient(args.lthigh, calibration["LT"], reorder)
    out = {"time": np.arange(Rp.shape[0]) / FS, "LHip": compute_hip_jcs(Rp, Rl)}
    if args.rthigh:
        Rr = _orient(args.rthigh, calibration["RT"], reorder)
        out["LKnee"] = compute_knee_jcs(Rl, Rr)
    print(f"Computed {len(out['time'])} frames ({args.mode}).")
    return out


if __name__ == "__main__":
    main()
