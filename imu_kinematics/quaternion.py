"""Quaternion utilities.

Ports of ``normalizeVector.m`` and ``meanQuaternion.m`` plus the
quaternion->rotation-matrix conversion that the MATLAB code obtains from
``quat2rotm`` / ``rotmat(quaternion(q),'point')`` (Robotics/Nav Toolbox).

CONVENTION (see PYTHON_TRANSLATION_PLAN.md Section 2 — locked):
  * Movella DOT quaternions are SCALAR-FIRST ``[w, x, y, z]``.
  * ``quat_to_rotmat`` returns the standard ACTIVE rotation matrix, identical
    to MATLAB ``quat2rotm(q)`` and ``rotmat(quaternion(q),'point')``.
  * SciPy's ``Rotation`` uses SCALAR-LAST ``[x, y, z, w]``; every handoff to
    SciPy must reorder first. ``quat_to_rotmat`` matches
    ``Rotation.from_quat([x, y, z, w]).as_matrix()``.
"""

from __future__ import annotations

import numpy as np

__all__ = [
    "normalize_vector",
    "mean_quaternion",
    "quat_to_rotmat",
    "scalar_first_to_last",
    "scalar_last_to_first",
]


def normalize_vector(v):
    """Port of ``normalizeVector.m``: ``v / norm(v)``."""
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def scalar_first_to_last(q):
    """``[w, x, y, z]`` -> ``[x, y, z, w]`` (Movella -> SciPy ordering)."""
    q = np.asarray(q, dtype=float)
    return q[..., [1, 2, 3, 0]]


def scalar_last_to_first(q):
    """``[x, y, z, w]`` -> ``[w, x, y, z]`` (SciPy -> Movella ordering)."""
    q = np.asarray(q, dtype=float)
    return q[..., [3, 0, 1, 2]]


def mean_quaternion(Q):
    """Port of ``meanQuaternion.m`` (Markley eigenvector average).

    Parameters
    ----------
    Q : array_like, shape (N, 4)
        Scalar-first quaternions ``[w, x, y, z]``.

    Returns
    -------
    numpy.ndarray, shape (4,)
        The average quaternion (scalar-first, unit norm).
    """
    Q = np.asarray(Q, dtype=float)
    # Row-wise normalization (MATLAB: Q ./ vecnorm(Q,2,2)).
    Q = Q / np.linalg.norm(Q, axis=1, keepdims=True)

    A = np.zeros((4, 4))
    for i in range(Q.shape[0]):
        q = Q[i, :].reshape(4, 1)
        A = A + q @ q.T

    eigvals, eigvecs = np.linalg.eig(A)
    idx = int(np.argmax(eigvals.real))
    q_mean = eigvecs[:, idx].real
    return q_mean


def quat_to_rotmat(q):
    """Scalar-first unit quaternion ``[w, x, y, z]`` -> active rotation matrix.

    Identical to MATLAB ``quat2rotm(q)`` and ``rotmat(quaternion(q),'point')``.
    """
    q = np.asarray(q, dtype=float)
    q = q / np.linalg.norm(q)
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z),     2 * (x * z + w * y)],
        [2 * (x * y + w * z),     1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y),     2 * (y * z + w * x),     1 - 2 * (x * x + y * y)],
    ])
