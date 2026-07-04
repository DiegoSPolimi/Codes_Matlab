"""CSV loading, sensor-file matching, and Excel export.

Consolidates the copy-pasted loaders and ``findFileCaseInsensitive`` /
``exportExcel`` helpers that recur across the MATLAB entry-point scripts:
  * ``loadIMUcsv`` / ``loadCleanIMUcsv`` / ``loadAndReorderIMUcsv``
  * ``findFileCaseInsensitive``
  * ``exportExcel.m``
"""

from __future__ import annotations

import glob
import os

import numpy as np
import pandas as pd

__all__ = [
    "load_imu_csv",
    "load_raw_imu_csv",
    "find_file_case_insensitive",
    "export_excel",
    "QUAT_COLS",
]

QUAT_COLS = ["Q0", "Q1", "Q2", "Q3"]


def load_imu_csv(file_path, reorder=False):
    """Load an IMU CSV and return quaternions (+ full table).

    Mirrors ``loadIMUcsv``/``loadCleanIMUcsv``/``loadAndReorderIMUcsv``.

    Parameters
    ----------
    file_path : str
        Path to the CSV.
    reorder : bool
        If True, sort rows by ``Timestamp_Arduino`` (the "reorder"/"clean"
        loaders assume already-sorted data; the raw pipeline sorts on load).

    Returns
    -------
    dict
        ``{"Quat": (N,4) scalar-first array, "table": DataFrame}``.
    """
    df = pd.read_csv(file_path)
    if reorder:
        if "Timestamp_Arduino" not in df.columns:
            raise ValueError(
                f'Column "Timestamp_Arduino" not found in {file_path}.'
            )
        df = df.sort_values("Timestamp_Arduino", kind="stable").reset_index(drop=True)

    missing = [c for c in QUAT_COLS if c not in df.columns]
    if missing:
        raise ValueError(
            f"The file {file_path} does not contain columns Q0, Q1, Q2, and Q3."
        )
    return {"Quat": df[QUAT_COLS].to_numpy(dtype=float), "table": df}


def load_raw_imu_csv(file_path):
    """Load Acc/Gyr/Quat for sync scripts (mirrors ``loadRawIMUcsv``).

    Handles the accelerometer/gyro column-name variants seen in the scripts
    (``Ax/Ay/Az`` | ``AccX..`` | ``Acc_X..`` and the gyro equivalents).
    Sorts by ``Timestamp_Arduino`` when present.
    """
    df = pd.read_csv(file_path)
    if "Timestamp_Arduino" in df.columns:
        df = df.sort_values("Timestamp_Arduino", kind="stable").reset_index(drop=True)

    def pick(groups):
        for cols in groups:
            if all(c in df.columns for c in cols):
                return cols
        return groups[-1]

    acc_cols = pick([["Ax", "Ay", "Az"], ["AccX", "AccY", "AccZ"],
                     ["Acc_X", "Acc_Y", "Acc_Z"]])
    gyr_cols = pick([["Gx", "Gy", "Gz"], ["GyrX", "GyrY", "GyrZ"],
                     ["Gyr_X", "Gyr_Y", "Gyr_Z"]])

    return {
        "Acc": df[acc_cols].to_numpy(dtype=float),
        "Gyr": df[gyr_cols].to_numpy(dtype=float),
        "Quat": df[QUAT_COLS].to_numpy(dtype=float),
        "table": df,
    }


def find_file_case_insensitive(folder, sensor_name, keywords, exclude_reordered=False):
    """Return the first CSV in ``folder`` matching sensor + all keywords.

    Mirrors ``findFileCaseInsensitive``: case-insensitive substring match on
    the sensor name and every keyword, with the underscore-flex behavior
    (a keyword ``foo_bar`` also matches ``foobar`` / ``foo-bar``).
    """
    files = sorted(os.path.basename(p) for p in glob.glob(os.path.join(folder, "*.csv")))
    if not files:
        raise FileNotFoundError("The selected folder does not contain any CSV files.")

    for name in files:
        low = name.lower()
        if exclude_reordered and "reordered" in low:
            continue
        if sensor_name.lower() not in low:
            continue
        ok = True
        for kw in keywords:
            kw = kw.lower()
            if (kw not in low
                    and kw.replace("_", "") not in low
                    and kw.replace("_", "-") not in low):
                ok = False
                break
        if ok:
            return name

    raise FileNotFoundError(
        f'No file found for sensor "{sensor_name}" with keywords {keywords}.'
    )


def export_excel(time, joint, joint_name):
    """Write ``<joint_name>_Angles.xlsx`` (mirrors ``exportExcel.m``).

    ``joint`` is a dict; always writes ``Time`` + ``FlexExt``, plus any of
    ``AbdAdd`` / ``VarusValgus`` / ``IntExt`` that are present.
    """
    time = np.asarray(time).ravel()
    data = {"Time": time, "FlexExt": np.asarray(joint["FlexExt"]).ravel()}
    for opt in ("AbdAdd", "VarusValgus", "IntExt"):
        if opt in joint:
            data[opt] = np.asarray(joint[opt]).ravel()

    df = pd.DataFrame(data)
    filename = f"{joint_name}_Angles.xlsx"
    df.to_excel(filename, index=False)
    print(f"{filename} exported.")
    return filename
