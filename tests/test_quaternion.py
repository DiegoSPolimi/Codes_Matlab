"""Tests for imu_kinematics.quaternion.

Highest-risk translation step: the scalar-first vs scalar-last and
active (point) rotation conventions. Convention tests (plan Section 7.4) run
first and do not depend on the golden files; the golden meanQuaternion check
(Section 7.2) runs when reference/ is present.
"""
import numpy as np
import pytest
from scipy.spatial.transform import Rotation

from imu_kinematics import quaternion as q
from tests.conftest import has_reference, load_ref, read_quat_csv


# --------------------------------------------------------------------------
# Section 7.4 — convention lock (hand-computed cases, no golden files needed)
# --------------------------------------------------------------------------
def test_normalize_vector():
    v = np.array([3.0, 0.0, 4.0])
    np.testing.assert_allclose(q.normalize_vector(v), [0.6, 0.0, 0.8])


def test_identity_quat_is_identity_matrix():
    R = q.quat_to_rotmat([1.0, 0.0, 0.0, 0.0])
    np.testing.assert_allclose(R, np.eye(3), atol=1e-12)


@pytest.mark.parametrize("axis,angle_deg,vec,expected", [
    # 90 deg about +Z (scalar-first w = cos45, z = sin45): +X -> +Y
    ("z", 90, [1, 0, 0], [0, 1, 0]),
    # 90 deg about +X: +Y -> +Z
    ("x", 90, [0, 1, 0], [0, 0, 1]),
    # 90 deg about +Y: +Z -> +X
    ("y", 90, [0, 0, 1], [1, 0, 0]),
])
def test_quat_to_rotmat_active_rotations(axis, angle_deg, vec, expected):
    half = np.deg2rad(angle_deg) / 2.0
    comp = {"x": 1, "y": 2, "z": 3}[axis]
    wxyz = [np.cos(half), 0.0, 0.0, 0.0]
    wxyz[comp] = np.sin(half)
    R = q.quat_to_rotmat(wxyz)
    np.testing.assert_allclose(R @ np.array(vec, float), expected, atol=1e-12)


def test_matches_scipy_scalar_last():
    # quat_to_rotmat([w,x,y,z]) == Rotation.from_quat([x,y,z,w]).as_matrix()
    rng = np.random.default_rng(0)
    for _ in range(20):
        wxyz = rng.standard_normal(4)
        wxyz /= np.linalg.norm(wxyz)
        R_ours = q.quat_to_rotmat(wxyz)
        R_scipy = Rotation.from_quat(q.scalar_first_to_last(wxyz)).as_matrix()
        np.testing.assert_allclose(R_ours, R_scipy, atol=1e-12)


def test_reorder_roundtrip():
    wxyz = np.array([0.1, 0.2, 0.3, 0.4])
    np.testing.assert_array_equal(
        q.scalar_last_to_first(q.scalar_first_to_last(wxyz)), wxyz
    )


def test_rotmat_is_orthonormal_det1():
    rng = np.random.default_rng(1)
    wxyz = rng.standard_normal(4)
    R = q.quat_to_rotmat(wxyz)
    np.testing.assert_allclose(R.T @ R, np.eye(3), atol=1e-12)
    assert abs(np.linalg.det(R) - 1.0) < 1e-12


def test_mean_quaternion_invariants():
    # A cluster of near-identical quaternions -> unit-norm average near them.
    rng = np.random.default_rng(2)
    base = np.array([1.0, 0.05, 0.02, 0.0])
    base /= np.linalg.norm(base)
    Q = base + 1e-3 * rng.standard_normal((50, 4))
    qm = q.mean_quaternion(Q)
    assert abs(np.linalg.norm(qm) - 1.0) < 1e-9


# --------------------------------------------------------------------------
# Section 7.2 — golden-file match
# --------------------------------------------------------------------------
@has_reference
def test_mean_quaternion_golden():
    Q = read_quat_csv("LT_20260703_172624_Static_N_Pose.csv")
    ref = load_ref("ref_meanQuaternion_LT.csv").ravel()
    got = q.mean_quaternion(Q)
    # Eigenvector sign is arbitrary; align sign before comparing.
    if np.dot(got, ref) < 0:
        got = -got
    np.testing.assert_allclose(got, ref, atol=1e-6)
