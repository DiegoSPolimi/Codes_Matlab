"""Tests for metrics.py and compute_angles.analyze_session."""
import json
import os

import numpy as np
import pytest

from imu_kinematics import metrics
from imu_kinematics.cycles import detect_pedalling_cycles
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


def _synth_knee(n=600, freq=1.0, fs=60):
    t = np.linspace(0, n / fs, n)
    return {
        "FlexExt": 30 + 25 * np.sin(2 * np.pi * freq * t),     # 5..55 deg
        "VarusValgus": 4 * np.sin(2 * np.pi * freq * t + 0.5),  # +/-4
        "IntExt": np.zeros_like(t),
    }


def test_knee_cycle_metrics_signs_and_order():
    knee = _synth_knee()
    troughs = detect_pedalling_cycles(knee["FlexExt"])
    m = metrics.knee_cycle_metrics(knee, troughs)
    assert m["n_cycles"] >= 8
    # flexion peak > extension peak; varus (max) > valgus (min)
    assert m["avg_peak_flexion"] > m["avg_peak_extension"]
    assert m["avg_peak_varus"] > m["avg_peak_valgus"]
    # amplitudes near the synthetic +/-25 and +/-4
    assert m["avg_peak_flexion"] == pytest.approx(55, abs=2)
    assert m["avg_peak_extension"] == pytest.approx(5, abs=2)


def test_knee_metrics_needs_cycle():
    with pytest.raises(ValueError):
        metrics.knee_cycle_metrics(_synth_knee(), troughs=[3])


def test_pelvic_variability_and_flags():
    pelvis = {
        "Tilt": np.zeros(100),               # perfectly stable -> ok
        "Obliquity": np.random.default_rng(0).normal(0, 10, 100),  # high
        "Rotation": np.linspace(-8, 8, 100),  # std ~4.6 deg -> warn band
    }
    var = metrics.pelvic_variability(pelvis)
    assert var["Tilt"]["std"] == pytest.approx(0.0)
    flags = metrics.pelvic_stability_flags(var)
    assert flags["Tilt"] == "ok"
    assert flags["Obliquity"] == "high"
    assert flags["Rotation"] in {"warn", "high"}


def test_custom_thresholds():
    var = {"Tilt": {"std": 2.0, "range": 4, "mean": 0}}
    flags = metrics.pelvic_stability_flags(var, {"Tilt": {"warn": 1.0, "high": 1.5}})
    assert flags["Tilt"] == "high"


# --------------------------------------------------------------------------
# analyze_session end-to-end (hip+pelvis from sample data; no shank -> no knee)
# --------------------------------------------------------------------------
def _calibration():
    from imu_kinematics.io import load_imu_csv
    from imu_kinematics.calibration import compute_static_calibration
    return {
        s: compute_static_calibration(
            load_imu_csv(os.path.join(DATA_DIR, STATIC[s]))["Quat"])
        for s in STATIC
    }


@has_reference
def test_analyze_session_hip_pelvis_matches_golden():
    cal = _calibration()
    files = {s: os.path.join(DATA_DIR, MOVEMENT[s]) for s in MOVEMENT}
    res = compute_angles.analyze_session(files, cal)

    assert "LHip" in res and "RHip" in res and "Pelvis" in res
    assert "LKnee" not in res  # no shank in sample data
    assert len(res["troughs"]) >= 2  # cycles detected

    L = np.column_stack([res["LHip"]["FlexExt"], res["LHip"]["AbdAdd"], res["LHip"]["IntExt"]])
    np.testing.assert_allclose(L, load_ref("ref_LHip_angles.csv"), atol=1e-3)
