"""Segment orientation over time.

Port of ``computeSegmentOrientation.m`` (live function, the ``'point'`` path).
For each frame: ``RsegGlobal = RsensGlobal @ RsegSens`` where ``RsensGlobal`` is
the active rotation matrix of the sensor quaternion (``quat2rotm`` / ``'point'``).

Convention: the returned array is shaped ``(N, 3, 3)`` (frame index first),
with each 3x3 having columns = segment ML/AP/Long axes in global coordinates
(same column meaning as MATLAB's ``R(:,:,k)``).
"""

from __future__ import annotations

import numpy as np

from .quaternion import quat_to_rotmat

__all__ = ["compute_segment_orientation"]


def compute_segment_orientation(quat, RsegSens):
    """Anatomical segment orientation for every frame.

    Parameters
    ----------
    quat : array_like, shape (N, 4)
        Scalar-first sensor quaternions ``[w, x, y, z]``.
    RsegSens : array_like, shape (3, 3)
        Sensor-to-segment calibration matrix.

    Returns
    -------
    numpy.ndarray, shape (N, 3, 3)
        Per-frame segment orientation matrices in global coordinates.
    """
    quat = np.asarray(quat, dtype=float)
    RsegSens = np.asarray(RsegSens, dtype=float)
    N = quat.shape[0]
    out = np.empty((N, 3, 3))
    for k in range(N):
        RsensGlobal = quat_to_rotmat(quat[k, :])
        out[k] = RsensGlobal @ RsegSens
    return out
