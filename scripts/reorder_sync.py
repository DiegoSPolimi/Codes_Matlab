"""Reorder & synchronize movement CSVs (port of live ``main_Reordering.m``).

Timestamp-sort each file, detect pedalling cycles from the quaternion
rotation-angle signal, crop between the first and last trough, resample every
column to a common length (the longest cropped file), and write
``<name>_REORDERED.csv``.

The core is :func:`reorder_and_sync`; ``main`` adds the interactive file picker.
"""

from __future__ import annotations

import argparse
import os

import pandas as pd

from imu_kinematics.sync import (
    quaternion_rotation_angle,
    detect_cycle_troughs,
    resample_table,
)

QUAT_COLS = ["Q0", "Q1", "Q2", "Q3"]


def _load_sorted(path):
    df = pd.read_csv(path)
    required = ["Timestamp_Arduino"] + QUAT_COLS
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"{path} missing columns: {missing}")
    return df.sort_values("Timestamp_Arduino", kind="stable").reset_index(drop=True)


def reorder_and_sync(paths, min_distance=40, min_prominence=3, out_suffix="_REORDERED"):
    """Process all ``paths``; write reordered/resampled copies. Returns output paths."""
    cropped = []
    for path in paths:
        df = _load_sorted(path)
        rot = quaternion_rotation_angle(df[QUAT_COLS].to_numpy())
        troughs = detect_cycle_troughs(rot, min_distance, min_prominence)
        if len(troughs) < 2:
            raise ValueError(f"Could not track movement cycles in {path}.")
        i_start, i_end = int(troughs[0]), int(troughs[-1])
        cropped.append((path, df.iloc[i_start:i_end + 1].reset_index(drop=True)))

    target = max(len(c) for _, c in cropped)
    outputs = []
    for path, cdf in cropped:
        synced = resample_table(cdf, target)
        base, ext = os.path.splitext(path)
        out = f"{base}{out_suffix}{ext}"
        synced.to_csv(out, index=False)
        print(f"Saved aligned matrix -> {os.path.basename(out)} ({target} rows)")
        outputs.append(out)
    return outputs


def main(argv=None):
    p = argparse.ArgumentParser(description="Reorder & synchronize movement CSVs.")
    p.add_argument("files", nargs="*", help="CSV files to synchronize together.")
    p.add_argument("--min-distance", type=int, default=40)
    p.add_argument("--min-prominence", type=float, default=3)
    args = p.parse_args(argv)

    files = args.files
    if not files:
        from tkinter import Tk, filedialog
        Tk().withdraw()
        files = list(filedialog.askopenfilenames(
            title="Select CSV files to synchronize", filetypes=[("CSV", "*.csv")]))
        if not files:
            p.error("No files selected.")

    return reorder_and_sync(files, args.min_distance, args.min_prominence)


if __name__ == "__main__":
    main()
