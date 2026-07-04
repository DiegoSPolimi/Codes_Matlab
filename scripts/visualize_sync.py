"""Synchronize raw IMU files by accelerometer peak, crop, and plot.

Port of ``Main_VISUALIZATION.m`` (single live version). Aligns files on the
dominant accelerometer-magnitude peak in the first few seconds, truncates to a
common length, lets the user click a crop window on the quaternion plot
(``ginput``), writes ``<name>_CROPPED.csv`` preserving original columns, then
plots Acc/Gyr/Quat per sensor.

Non-interactive core is :func:`sync_and_crop`; ``main`` adds pickers + ginput.
"""

from __future__ import annotations

import argparse
import os

import numpy as np
import pandas as pd

from imu_kinematics.io import load_raw_imu_csv
from imu_kinematics.sync import synchronize_by_acc_peak

FS = 60
SYNC_WINDOW_SECONDS = 5


def sync_and_crop(paths, fs=FS, window_seconds=SYNC_WINDOW_SECONDS,
                  crop_fraction=(0.0, 1.0)):
    """Acc-peak-align ``paths``, then crop by fractional [start,end] window.

    ``crop_fraction`` replaces the interactive ginput selection with an explicit
    fraction of the synchronized timeline so the pipeline is testable.
    Returns a list of cropped original-column DataFrames (aligned, equal length).
    """
    raws = [load_raw_imu_csv(p) for p in paths]
    slices, min_remaining = synchronize_by_acc_peak(
        [r["Acc"] for r in raws], fs, window_seconds)

    f0, f1 = crop_fraction
    c_start = max(0, int(round(f0 * (min_remaining - 1))))
    c_end = min(min_remaining, int(round(f1 * (min_remaining - 1))) + 1)

    cropped = []
    for (start, _end), raw in zip(slices, raws):
        table = raw["table"]
        abs_start = start + c_start
        abs_end = start + c_end
        cropped.append(table.iloc[abs_start:abs_end].reset_index(drop=True))
    return cropped


def write_cropped(paths, cropped, out_suffix="_CROPPED"):
    outputs = []
    for path, cdf in zip(paths, cropped):
        base, ext = os.path.splitext(path)
        out = f"{base}{out_suffix}{ext}"
        cdf.to_csv(out, index=False)
        print(f"Saved {os.path.basename(out)} ({len(cdf)} rows)")
        outputs.append(out)
    return outputs


def main(argv=None):
    p = argparse.ArgumentParser(description="Sync raw IMU files by acc peak and crop.")
    p.add_argument("files", nargs="*", help="CSV files to synchronize.")
    args = p.parse_args(argv)

    files = args.files
    if not files:
        from tkinter import Tk, filedialog
        Tk().withdraw()
        files = list(filedialog.askopenfilenames(
            title="Select CSV files to synchronize", filetypes=[("CSV", "*.csv")]))
        if not files:
            p.error("No files selected.")

    raws = [load_raw_imu_csv(f) for f in files]
    slices, min_remaining = synchronize_by_acc_peak([r["Acc"] for r in raws])
    time = np.arange(min_remaining) / FS

    # Interactive crop via ginput on the first file's quaternions.
    import matplotlib.pyplot as plt
    q0 = raws[0]["Quat"][slices[0][0]:slices[0][1]]
    fig, ax = plt.subplots()
    ax.plot(time, q0)
    ax.set_title("Click START then END to crop")
    clicks = plt.ginput(2)
    plt.close(fig)
    xs = sorted(c[0] for c in clicks)
    frac = (xs[0] / time[-1], xs[1] / time[-1])

    cropped = sync_and_crop(files, crop_fraction=frac)
    write_cropped(files, cropped)


if __name__ == "__main__":
    main()
