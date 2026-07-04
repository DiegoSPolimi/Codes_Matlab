"""Tests for calibration.py and orientation.py against golden files."""
import numpy as np
import pytest

from imu_kinematics.calibration import compute_static_calibration, apply_s2_axis_swap
from imu_kinematics.orientation import compute_segment_orientation
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


# --------------------------------------------------------------------------
# Invariants (no golden files needed)
# --------------------------------------------------------------------------
@pytest.mark.parametrize("sensor", ["S2", "LT", "RT"])
@has_reference
def test_calibration_is_rotation(sensor):
    R = compute_static_calibration(read_quat_csv(STATIC[sensor]))
    np.testing.assert_allclose(R.T @ R, np.eye(3), atol=1e-9)
    assert abs(np.linalg.det(R) - 1.0) < 1e-9


def test_s2_axis_swap_preserves_det():
    R = np.linalg.qr(np.random.default_rng(0).standard_normal((3, 3)))[0]
    if np.linalg.det(R) < 0:
        R[:, 0] *= -1
    Rc = apply_s2_axis_swap(R)
    assert abs(np.linalg.det(Rc) - 1.0) < 1e-9


# --------------------------------------------------------------------------
# Golden-file matches
# --------------------------------------------------------------------------
@pytest.mark.parametrize("sensor", ["S2", "LT", "RT"])
@has_reference
def test_calibration_golden(sensor):
    R = compute_static_calibration(read_quat_csv(STATIC[sensor]))
    ref = load_ref(f"ref_RsegSens_{sensor}.csv")
    np.testing.assert_allclose(R, ref, atol=1e-6)


@pytest.mark.parametrize("sensor", ["S2", "LT", "RT"])
@has_reference
def test_segment_orientation_golden(sensor):
    # Reproduce the harness crop: all three cropped to common min length.
    quats = {s: read_quat_csv(MOVEMENT[s]) for s in MOVEMENT}
    N = min(q.shape[0] for q in quats.values())

    Rcal = compute_static_calibration(read_quat_csv(STATIC[sensor]))
    Rseg = compute_segment_orientation(quats[sensor][:N], Rcal)  # (N,3,3)

    ref = load_ref(f"ref_RsegGlobal_{sensor}.csv")  # (N,9) row-major per frame
    assert ref.shape[0] == N
    ref_mats = ref.reshape(N, 3, 3)  # C-order == row-major r11 r12 r13 ...
    np.testing.assert_allclose(Rseg, ref_mats, atol=1e-6)
