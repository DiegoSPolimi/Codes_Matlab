"""Biomechanical summary metrics for the pedaling cycle.

Built on top of the angle series and cycle segmentation from
:mod:`imu_kinematics.joint_angles` and :mod:`imu_kinematics.cycles`.

Sign conventions (from the JCS code / plot titles):
  * Knee FlexExt : Flexion (+) / Extension (-)
  * Knee VarusValgus : Varus/Adduction (+) / Valgus/Abduction (-)
  * Pelvis Tilt/Obliquity/Rotation : signed degrees vs. global.
"""

from __future__ import annotations

import numpy as np

from .cycles import normalize_cycles

__all__ = [
    "knee_cycle_metrics",
    "pelvic_variability",
    "pelvic_stability_flags",
    "DEFAULT_PELVIC_THRESHOLDS",
]

# Std (deg) above which a pelvic axis is flagged. Two-level: warn / high.
DEFAULT_PELVIC_THRESHOLDS = {
    "Tilt": {"warn": 3.0, "high": 5.0},
    "Obliquity": {"warn": 3.0, "high": 5.0},
    "Rotation": {"warn": 3.0, "high": 5.0},
}


def _per_cycle(signal, troughs, reducer):
    """Apply ``reducer`` to each cycle slice, return array of per-cycle values."""
    signal = np.asarray(signal, dtype=float)
    troughs = np.asarray(troughs)
    vals = []
    for c in range(len(troughs) - 1):
        i0, i1 = int(troughs[c]), int(troughs[c + 1])
        seg = signal[i0:i1 + 1]
        if len(seg):
            vals.append(reducer(seg))
    return np.asarray(vals, dtype=float)


def knee_cycle_metrics(knee, troughs):
    """Average peak knee angles across pedaling cycles.

    Parameters
    ----------
    knee : dict
        Must contain ``FlexExt`` and ``VarusValgus`` arrays.
    troughs : array_like
        Cycle boundary indices (from ``detect_pedalling_cycles``); at least 2.

    Returns
    -------
    dict
        ``avg_peak_flexion`` (mean of per-cycle max FlexExt),
        ``avg_peak_extension`` (mean of per-cycle min FlexExt),
        ``avg_peak_valgus`` (mean of per-cycle min VarusValgus),
        ``avg_peak_varus`` (mean of per-cycle max VarusValgus),
        plus the raw per-cycle arrays and ``n_cycles``.
    """
    troughs = np.asarray(troughs)
    if len(troughs) < 2:
        raise ValueError("Need at least two troughs (one full cycle) for metrics.")

    flex_peaks = _per_cycle(knee["FlexExt"], troughs, np.max)
    ext_peaks = _per_cycle(knee["FlexExt"], troughs, np.min)
    valgus_peaks = _per_cycle(knee["VarusValgus"], troughs, np.min)
    varus_peaks = _per_cycle(knee["VarusValgus"], troughs, np.max)

    return {
        "n_cycles": len(troughs) - 1,
        "avg_peak_flexion": float(np.mean(flex_peaks)),
        "avg_peak_extension": float(np.mean(ext_peaks)),
        "avg_peak_valgus": float(np.mean(valgus_peaks)),
        "avg_peak_varus": float(np.mean(varus_peaks)),
        "per_cycle": {
            "flexion": flex_peaks.tolist(),
            "extension": ext_peaks.tolist(),
            "valgus": valgus_peaks.tolist(),
            "varus": varus_peaks.tolist(),
        },
    }


def pelvic_variability(pelvis):
    """Variability of each pelvic axis over the trial.

    Returns ``{axis: {"std": deg, "range": deg, "mean": deg}}`` for
    ``Tilt``, ``Obliquity``, ``Rotation``. Std is population std (ddof=0);
    range is peak-to-peak.
    """
    out = {}
    for axis in ("Tilt", "Obliquity", "Rotation"):
        x = np.asarray(pelvis[axis], dtype=float)
        out[axis] = {
            "std": float(np.std(x, ddof=0)),
            "range": float(np.ptp(x)),
            "mean": float(np.mean(x)),
        }
    return out


def pelvic_stability_flags(variability, thresholds=None):
    """Classify each pelvic axis as ``ok`` / ``warn`` / ``high`` by std.

    ``variability`` is the output of :func:`pelvic_variability`. Returns
    ``{axis: level}``. A high pelvic std means the athlete moves the pelvis a
    lot during pedaling (less stable).
    """
    thresholds = thresholds or DEFAULT_PELVIC_THRESHOLDS
    flags = {}
    for axis, stats in variability.items():
        th = thresholds.get(axis, {"warn": 3.0, "high": 5.0})
        std = stats["std"]
        if std >= th["high"]:
            flags[axis] = "high"
        elif std >= th["warn"]:
            flags[axis] = "warn"
        else:
            flags[axis] = "ok"
    return flags
