"""Tests for joint_angles.py against golden files.

Builds the same orientation inputs the harness used, then checks hip (L/R),
knee (LT-as-thigh, RT-as-shank), and pelvis-global angles to 1e-3 deg.
"""
import numpy as np
import pytest

from imu_kinematics.calibration import compute_static_calibration
from imu_kinematics.orientation import compute_segment_orientation
from imu_kinematics.joint_angles import (
    compute_hip_jcs,
    compute_knee_jcs,
    compute_pelvis_global_angles,
)
from tests.conftest import has_reference, load_ref, read_quat_csv

STATIC = {
    "S2": "S2_20260703_172624_Static_N_Pose.csv",
    "LT": "LT_20260703_172624_Static_N_Pose.csv",
    "RT": "RT_20260703_172624_Static_N_Pose.csv",
}
MOVEMENT = {
    "S2": "S2_20260703_172940.csv",
    "LT": "LT_20260703_172940.csv",
    "RT": "RT_20260703_172940.csv",
}


def _orientations():
    quats = {s: read_quat_csv(MOVEMENT[s]) for s in MOVEMENT}
    N = min(q.shape[0] for q in quats.values())
    R = {}
    for s in MOVEMENT:
        Rcal = compute_static_calibration(read_quat_csv(STATIC[s]))
        R[s] = compute_segment_orientation(quats[s][:N], Rcal)
    return R


@has_reference
def test_hip_golden():
    R = _orientations()
    LHip = compute_hip_jcs(R["S2"], R["LT"])
    RHip = compute_hip_jcs(R["S2"], R["RT"])
    ref_L = load_ref("ref_LHip_angles.csv")
    ref_R = load_ref("ref_RHip_angles.csv")
    for got, ref in [(LHip, ref_L), (RHip, ref_R)]:
        cols = np.column_stack([got["FlexExt"], got["AbdAdd"], got["IntExt"]])
        np.testing.assert_allclose(cols, ref, atol=1e-3)


@has_reference
def test_knee_golden():
    R = _orientations()
    Knee = compute_knee_jcs(R["LT"], R["RT"])  # LT-as-thigh, RT-as-shank
    ref = load_ref("ref_Knee_angles.csv")
    cols = np.column_stack([Knee["FlexExt"], Knee["VarusValgus"], Knee["IntExt"]])
    np.testing.assert_allclose(cols, ref, atol=1e-3)


@has_reference
def test_pelvis_global_golden():
    R = _orientations()
    PG = compute_pelvis_global_angles(R["S2"])
    ref = load_ref("ref_PelvisGlobal_angles.csv")
    cols = np.column_stack([PG["Tilt"], PG["Obliquity"], PG["Rotation"]])
    np.testing.assert_allclose(cols, ref, atol=1e-3)


def test_knee_strategy_A_zeros_at_max():
    # Strategy A shifts FlexExt so its max becomes 0.
    R = _orientations() if False else None
    rng = np.random.default_rng(0)
    # Small synthetic orientation stream to exercise offset logic only.
    Rt = np.array([np.eye(3) for _ in range(10)])
    Rs = np.array([np.eye(3) for _ in range(10)])
    knee = compute_knee_jcs(Rt, Rs, offset_strategy="A")
    assert abs(np.max(knee["FlexExt"])) < 1e-9
