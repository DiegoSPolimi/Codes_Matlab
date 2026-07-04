"""Static calibration entry point.

Merges three MATLAB scripts behind flags (plan Section 5), preserving their
real differences rather than collapsing them:
  * ``main_Calibration_STATIC.m``  -> auto folder + posture menu
  * ``Calibration_STATIC_V2.m``    -> + on-the-fly reorder (--reorder)
  * ``Calibration_STATIC_V2_MANUAL.m`` -> manual file picks (--manual) +
    optional S2 axis swap (--fix-s2-axis)

Design (Section 6 default): interactive dialogs are the default front-end, but
``run_calibration`` takes explicit paths so it is scriptable/testable. Results
are saved as JSON (Python-native default); pass ``--mat`` for MATLAB interop.

Examples
--------
  python -m scripts.calibrate --data-folder DIR --posture n_pose
  python -m scripts.calibrate --data-folder DIR --reorder --fix-s2-axis
  python -m scripts.calibrate --manual FILE1 FILE2 ... [--fix-s2-axis]
"""

from __future__ import annotations

import argparse
import json
import os

import numpy as np

from imu_kinematics.calibration import compute_static_calibration, apply_s2_axis_swap
from imu_kinematics.io import find_file_case_insensitive, load_imu_csv

DEFAULT_SENSORS = ["S2", "LT", "RT"]
POSTURE_KEYWORDS = {
    "n_pose": ["static", "n_pose"],
    "supine": ["static", "supine"],
    "seated": ["static", "seated"],
}


def _infer_sensor(filename, sensors):
    low = os.path.basename(filename).lower()
    for s in sensors + ["LShank"]:
        if s.lower() in low:
            return s
    return None


def run_calibration(files_by_sensor, reorder=False, fix_s2_axis=False):
    """Core: compute ``RsegSens`` per sensor from ``{sensor: csv_path}``.

    Returns ``{sensor: {"RsegSens": 3x3 list}}`` plus per-sensor diagnostics
    printed to stdout (det, orthogonality error) — matching the .m checks.
    """
    calibration = {}
    for sensor, path in files_by_sensor.items():
        data = load_imu_csv(path, reorder=reorder)
        R = compute_static_calibration(data["Quat"])
        if fix_s2_axis and sensor == "S2":
            R = apply_s2_axis_swap(R)
        det = float(np.linalg.det(R))
        ortho = float(np.linalg.norm(R.T @ R - np.eye(3)))
        print(f"{sensor}: det(R)={det:.4f}  orthogonality_error={ortho:.6f}")
        calibration[sensor] = {"RsegSens": R.tolist()}
    return calibration


def _match_auto(data_folder, sensors, keywords, reorder):
    files = {}
    for s in sensors:
        try:
            name = find_file_case_insensitive(
                data_folder, s, keywords, exclude_reordered=reorder
            )
        except FileNotFoundError as e:
            print(f"warning: {e} Skipping {s}.")
            continue
        files[s] = os.path.join(data_folder, name)
    return files


def save_results(calibration, out_path, as_mat=False):
    if as_mat:
        from scipy.io import savemat
        savemat(out_path, {"Calibration": {
            s: {"RsegSens": np.asarray(v["RsegSens"])}
            for s, v in calibration.items()
        }})
    else:
        with open(out_path, "w") as f:
            json.dump(calibration, f, indent=2)
    print(f"Calibration saved to {out_path}")


def main(argv=None):
    p = argparse.ArgumentParser(description="Static sensor-to-segment calibration.")
    p.add_argument("--data-folder", help="Folder with static CSVs (auto mode).")
    p.add_argument("--manual", nargs="+", metavar="CSV",
                   help="Explicit static CSV files; sensor inferred from name.")
    p.add_argument("--posture", choices=list(POSTURE_KEYWORDS), default="n_pose")
    p.add_argument("--sensors", nargs="+", default=DEFAULT_SENSORS)
    p.add_argument("--reorder", action="store_true",
                   help="Sort rows by Timestamp_Arduino before calibrating.")
    p.add_argument("--fix-s2-axis", action="store_true",
                   help="Apply the S2 ML/Long axis swap.")
    p.add_argument("--output", help="Output path (default: <folder>/CalibrationResults.json).")
    p.add_argument("--mat", action="store_true", help="Save as .mat instead of JSON.")
    args = p.parse_args(argv)

    if args.manual:
        files = {}
        for f in args.manual:
            s = _infer_sensor(f, args.sensors)
            if s is None:
                print(f"Skipping unrecognized file: {f}")
                continue
            files[s] = f
        base_dir = os.path.dirname(os.path.abspath(args.manual[0]))
    elif args.data_folder:
        files = _match_auto(args.data_folder, args.sensors,
                            POSTURE_KEYWORDS[args.posture], args.reorder)
        base_dir = args.data_folder
    else:
        # Interactive fallback (Section 6 default front-end).
        from tkinter import Tk, filedialog
        Tk().withdraw()
        folder = filedialog.askdirectory(title="Select the STATIC calibration folder")
        if not folder:
            p.error("No folder selected.")
        files = _match_auto(folder, args.sensors,
                            POSTURE_KEYWORDS[args.posture], args.reorder)
        base_dir = folder

    if not files:
        p.error("No calibration files matched.")

    calibration = run_calibration(files, reorder=args.reorder,
                                  fix_s2_axis=args.fix_s2_axis)
    ext = "mat" if args.mat else "json"
    out = args.output or os.path.join(base_dir, f"CalibrationResults.{ext}")
    save_results(calibration, out, as_mat=args.mat)
    return calibration


if __name__ == "__main__":
    main()
