"""Tests for cycles.py and scripts/compute_angles.py."""
import json
import os

import numpy as np
import pytest

from imu_kinematics import cycles
from scripts import compute_angles
from tests.conftest import DATA_DIR, has_reference, load_ref

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
# cycles.py invariants
# --------------------------------------------------------------------------
def test_detect_cycles_on_synthetic():
    t = np.linspace(0, 10, 600)  # 60 Hz, 10 s
    sig = -np.cos(2 * np.pi * 1.0 * t) * 20  # 1 Hz -> troughs at max flexion
    troughs = cycles.detect_pedalling_cycles(sig, min_distance=40, min_prominence=2)
    assert len(troughs) >= 8  # ~10 cycles


def test_normalize_cycles_shape_and_stats():
    t = np.linspace(0, 10, 600)
    sig = -np.cos(2 * np.pi * 1.0 * t) * 20
    troughs = cycles.detect_pedalling_cycles(sig)
    norm = cycles.normalize_cycles(sig, troughs)
    assert norm.shape[0] == cycles.N_POINTS
    mean, std = cycles.ensemble_stats(norm)
    assert mean.shape == (cycles.N_POINTS,)
    assert np.all(std >= 0)


def test_cycle_ensemble_from_dict():
    t = np.linspace(0, 10, 600)
    joint = {
        "FlexExt": -np.cos(2 * np.pi * t) * 20,
        "AbdAdd": np.sin(2 * np.pi * t) * 5,
        "IntExt": np.zeros_like(t),
    }
    res = compute_angles.cycle_ensemble(joint, field="FlexExt")
    assert set(res) == {"FlexExt", "AbdAdd", "IntExt"}
    assert res["FlexExt"]["mean"].shape == (cycles.N_POINTS,)


# --------------------------------------------------------------------------
# compute_angles pipeline against golden hip/pelvis angles
# --------------------------------------------------------------------------
def _write_calibration(tmp_path):
    cal = {}
    for s in ("S2", "LT", "RT"):
        from imu_kinematics.io import load_imu_csv
        from imu_kinematics.calibration import compute_static_calibration
        R = compute_static_calibration(
            load_imu_csv(os.path.join(DATA_DIR, STATIC[s]))["Quat"])
        cal[s] = {"RsegSens": R.tolist()}
    path = tmp_path / "cal.json"
    path.write_text(json.dumps(cal))
    return str(path)


@has_reference
def test_manual_bilateral_matches_golden(tmp_path):
    cal_path = _write_calibration(tmp_path)
    calibration = compute_angles.load_calibration(cal_path)
    res = compute_angles.compute_manual_bilateral(
        os.path.join(DATA_DIR, MOVEMENT["S2"]),
        os.path.join(DATA_DIR, MOVEMENT["LT"]),
        os.path.join(DATA_DIR, MOVEMENT["RT"]),
        calibration,
    )
    ref_L = load_ref("ref_LHip_angles.csv")
    ref_R = load_ref("ref_RHip_angles.csv")
    ref_P = load_ref("ref_PelvisGlobal_angles.csv")

    L = np.column_stack([res["LHip"]["FlexExt"], res["LHip"]["AbdAdd"], res["LHip"]["IntExt"]])
    R = np.column_stack([res["RHip"]["FlexExt"], res["RHip"]["AbdAdd"], res["RHip"]["IntExt"]])
    P = np.column_stack([res["Pelvis"]["Tilt"], res["Pelvis"]["Obliquity"], res["Pelvis"]["Rotation"]])
    np.testing.assert_allclose(L, ref_L, atol=1e-3)
    np.testing.assert_allclose(R, ref_R, atol=1e-3)
    np.testing.assert_allclose(P, ref_P, atol=1e-3)
