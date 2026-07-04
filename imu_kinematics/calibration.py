"""Static sensor-to-segment calibration.

Port of ``computeStaticCalibration.m`` (live code, whole file) and the optional
S2 axis-swap correction that appears (commented out) in
``Calibration_STATIC_V2*.m``. Per plan Section 6, the axis correction is
exposed as an opt-in parameter rather than hard-coded/dropped.
"""

from __future__ import annotations

import numpy as np

from .quaternion import mean_quaternion, quat_to_rotmat

__all__ = ["compute_static_calibration", "apply_s2_axis_swap"]


def compute_static_calibration(quat):
    """Sensor-to-segment rotation ``RsegSens`` from static-pose quaternions.

    Mirrors ``computeStaticCalibration.m``:
    mean quaternion -> normalize -> quat2rotm -> transpose.

    Parameters
    ----------
    quat : array_like, shape (N, 4)
        Scalar-first quaternions ``[w, x, y, z]`` from the static trial.

    Returns
    -------
    numpy.ndarray, shape (3, 3)
        ``RsegSens`` (columns = segment ML/AP/Long axes in sensor frame).
    """
    q = mean_quaternion(quat)
    q = q / np.linalg.norm(q)
    RSL = quat_to_rotmat(q)
    return RSL.T


def apply_s2_axis_swap(R):
    """Optional S2 ML/Long axis-swap correction (from Calibration_STATIC_V2*).

    Swaps column 1 (ML) and column 3 (Long) with a sign flip on the new
    column 3 to keep a right-handed system (det = +1):
    ``R_corrected = [Col3_Long, Col2_AP, -Col1_ML]``.
    """
    R = np.asarray(R, dtype=float)
    col1_ml = R[:, 0]
    col2_ap = R[:, 1]
    col3_long = R[:, 2]
    return np.column_stack([col3_long, col2_ap, -col1_ml])
