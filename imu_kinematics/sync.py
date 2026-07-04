"""Synchronization and resampling primitives.

Reusable core extracted from the two live MATLAB sync workflows:
  * ``Main_VISUALIZATION.m`` — accelerometer-magnitude peak alignment then
    truncation to a common trailing length.
  * ``main_Reordering.m`` (live "Kinematic Cycle Alignment" block) — timestamp
    sort, quaternion rotation-angle trough detection, crop between first/last
    trough, then per-column resample to a common length.

The interactive pieces (folder/file pickers, ``ginput`` crop) live in the
``scripts/`` wrappers; everything here is deterministic and testable.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from scipy.signal import find_peaks

__all__ = [
    "acc_peak_index",
    "synchronize_by_acc_peak",
    "quaternion_rotation_angle",
    "detect_cycle_troughs",
    "resample_table",
    "movmean",
]


def movmean(x, window):
    """Centered moving average (MATLAB ``movmean``)."""
    return pd.Series(np.asarray(x, dtype=float)).rolling(
        window, center=True, min_periods=1
    ).mean().to_numpy()


def acc_peak_index(acc, fs=60, window_seconds=5):
    """Index of the max accelerometer-magnitude peak within the first window.

    Mirrors the sync-peak detection in ``Main_VISUALIZATION.m``.
    """
    acc = np.asarray(acc, dtype=float)
    mag = np.sqrt(np.sum(acc ** 2, axis=1))
    limit = min(int(window_seconds * fs), len(mag))
    return int(np.argmax(mag[:limit]))


def synchronize_by_acc_peak(acc_list, fs=60, window_seconds=5):
    """Return per-file (start, end) slice indices aligning acc peaks.

    Each file is aligned so its peak is the common start; all are truncated to
    the minimum available trailing length (matches the .m safe-bounds logic).
    """
    peaks = [acc_peak_index(a, fs, window_seconds) for a in acc_list]
    trailing = [len(a) - p for a, p in zip(acc_list, peaks)]
    min_remaining = min(trailing)
    return [(p, p + min_remaining) for p in peaks], min_remaining


def quaternion_rotation_angle(quat):
    """Per-frame angular displacement (deg) from the first frame's orientation.

    ``theta = 2*acos(|q_k . q_ref|)`` on unit quaternions (from main_Reordering).
    """
    q = np.asarray(quat, dtype=float)
    q = q / np.linalg.norm(q, axis=1, keepdims=True)
    ref = q[0]
    dot = np.clip(np.sum(q * ref, axis=1), -1.0, 1.0)
    return 2.0 * np.degrees(np.arccos(np.abs(dot)))


def detect_cycle_troughs(rot_angle, min_distance=40, min_prominence=3, smooth=5):
    """Trough indices of the (smoothed) rotation-angle signal.

    Mirrors ``findpeaks(-rotAngleSmooth, 'MinPeakDistance', 'MinPeakProminence')``.
    """
    sig = movmean(rot_angle, smooth)
    troughs, _ = find_peaks(-sig, distance=min_distance, prominence=min_prominence)
    return troughs


def resample_table(df, target_length):
    """Resample every column of ``df`` to ``target_length`` rows.

    Numeric columns: linear interpolation (``interp1 linear``). Non-numeric:
    nearest-neighbor index mapping. Mirrors the STAGE-2 resample loop.
    """
    n = len(df)
    x_old = np.arange(1, n + 1)
    x_new = np.linspace(1, n, target_length)
    out = {}
    for col in df.columns:
        data = df[col].to_numpy()
        if np.issubdtype(data.dtype, np.number):
            out[col] = np.interp(x_new, x_old, data.astype(float))
        else:
            idx = np.round(np.interp(x_new, x_old, np.arange(n))).astype(int)
            idx = np.clip(idx, 0, n - 1)
            out[col] = data[idx]
    return pd.DataFrame(out)
