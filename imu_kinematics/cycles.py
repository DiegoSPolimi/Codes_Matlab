"""Pedalling-cycle segmentation, time-normalization, and ensemble stats.

Ports the cycle-analysis math from ``main_Compute_Angles_MANUAL.m``:
  * detect cycles as troughs (maximum-flexion points) via
    ``findpeaks(-hipFlexion, 'MinPeakDistance', 40, 'MinPeakProminence', 2)``.
  * normalize each cycle to 0-100% at 101 points with a not-a-knot cubic
    spline (``interp1(..., 'spline')``).
  * mean and (population-normalized, ``std(...,0,2)``) std across cycles.
"""

from __future__ import annotations

import numpy as np
from scipy.interpolate import CubicSpline
from scipy.signal import find_peaks

__all__ = ["detect_pedalling_cycles", "normalize_cycles", "ensemble_stats", "N_POINTS"]

N_POINTS = 101


def detect_pedalling_cycles(hip_flexion, min_distance=40, min_prominence=2):
    """Trough indices (max-flexion) bounding pedalling cycles.

    Returns the trough indices; number of cycles = ``len(troughs) - 1``.
    """
    hip_flexion = np.asarray(hip_flexion, dtype=float)
    troughs, _ = find_peaks(-hip_flexion, distance=min_distance,
                            prominence=min_prominence)
    return troughs


def normalize_cycles(signal, troughs, n_points=N_POINTS):
    """Time-normalize each cycle of ``signal`` to ``n_points`` (0-100%).

    Returns an ``(n_points, n_cycles)`` array (columns = individual cycles),
    matching the MATLAB per-cycle interpolation with a cubic spline.
    """
    signal = np.asarray(signal, dtype=float)
    troughs = np.asarray(troughs)
    n_cycles = len(troughs) - 1
    if n_cycles < 1:
        raise ValueError("Need at least two troughs (one full cycle).")

    t_norm = np.linspace(0, 100, n_points)
    out = np.zeros((n_points, n_cycles))
    for c in range(n_cycles):
        i0, i1 = int(troughs[c]), int(troughs[c + 1])
        seg = signal[i0:i1 + 1]
        t_raw = np.linspace(0, 100, len(seg))
        out[:, c] = CubicSpline(t_raw, seg)(t_norm)  # not-a-knot == MATLAB 'spline'
    return out


def ensemble_stats(normalized):
    """Return (mean, std) across cycles (axis=1). Population std (ddof=0)."""
    normalized = np.asarray(normalized, dtype=float)
    return normalized.mean(axis=1), normalized.std(axis=1, ddof=0)
