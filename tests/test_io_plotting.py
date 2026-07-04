"""Structural/round-trip tests for io.py and plotting.py (no golden refs)."""
import os

import matplotlib
matplotlib.use("Agg")  # non-interactive backend for tests

import numpy as np
import pandas as pd
import pytest

from imu_kinematics import io
from imu_kinematics import plotting
from tests.conftest import DATA_DIR, has_reference


def test_load_imu_csv_shape():
    path = os.path.join(DATA_DIR, "LT_20260703_172624_Static_N_Pose.csv")
    data = io.load_imu_csv(path)
    assert data["Quat"].shape[1] == 4
    assert data["Quat"].shape[0] > 0


def test_load_imu_csv_reorder_sorts():
    path = os.path.join(DATA_DIR, "LT_20260703_172940.csv")
    data = io.load_imu_csv(path, reorder=True)
    ts = data["table"]["Timestamp_Arduino"].to_numpy()
    assert np.all(np.diff(ts) >= 0)


def test_load_raw_imu_csv_channels():
    path = os.path.join(DATA_DIR, "S2_20260703_172940.csv")
    data = io.load_raw_imu_csv(path)
    assert data["Acc"].shape[1] == 3
    assert data["Gyr"].shape[1] == 3
    assert data["Quat"].shape[1] == 4


def test_find_file_case_insensitive_matches():
    name = io.find_file_case_insensitive(DATA_DIR, "LT", ["static", "n_pose"])
    assert name.lower().startswith("lt")
    assert "static" in name.lower()


def test_find_file_case_insensitive_missing_raises():
    with pytest.raises(FileNotFoundError):
        io.find_file_case_insensitive(DATA_DIR, "ZZ", ["nomatch"])


def test_export_excel_roundtrip(tmp_path):
    cwd = os.getcwd()
    os.chdir(tmp_path)
    try:
        joint = {
            "FlexExt": np.arange(5.0),
            "AbdAdd": np.ones(5),
            "IntExt": np.zeros(5),
        }
        fname = io.export_excel(np.arange(5.0), joint, "TestJoint")
        assert os.path.exists(fname)
        df = pd.read_excel(fname)
        assert list(df.columns) == ["Time", "FlexExt", "AbdAdd", "IntExt"]
        assert len(df) == 5
    finally:
        os.chdir(cwd)


def test_plot_angles_hip_runs():
    t = np.linspace(0, 1, 10)
    joint = {"FlexExt": np.zeros(10), "AbdAdd": np.zeros(10), "IntExt": np.zeros(10)}
    fig = plotting.plot_angles(t, joint, "Left Hip")
    assert len(fig.axes) == 3


def test_plot_calibration_frames_runs():
    R = np.eye(3)
    fig = plotting.plot_calibration_frames({"LT": {"RsegSens": R}, "S2": R})
    assert len(fig.axes) == 2
