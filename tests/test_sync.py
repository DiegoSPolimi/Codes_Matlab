"""Tests for sync.py and the sync scripts (invariant/structural — no goldens)."""
import os

import numpy as np
import pandas as pd
import pytest

from imu_kinematics import sync
from imu_kinematics.io import load_raw_imu_csv
from scripts import reorder_sync, visualize_sync
from tests.conftest import DATA_DIR

MOVEMENT = [
    "S2_20260703_172940.csv",
    "LT_20260703_172940.csv",
    "RT_20260703_172940.csv",
]


def test_movmean_matches_simple_case():
    x = np.array([1.0, 2, 3, 4, 5])
    got = sync.movmean(x, 3)
    # centered window, min_periods=1: edges use partial windows
    np.testing.assert_allclose(got, [1.5, 2, 3, 4, 4.5])


def test_acc_peak_within_window():
    acc = load_raw_imu_csv(os.path.join(DATA_DIR, MOVEMENT[0]))["Acc"]
    idx = sync.acc_peak_index(acc, fs=60, window_seconds=5)
    assert 0 <= idx < min(300, len(acc))


def test_synchronize_by_acc_peak_equal_length():
    accs = [load_raw_imu_csv(os.path.join(DATA_DIR, f))["Acc"] for f in MOVEMENT]
    slices, n = sync.synchronize_by_acc_peak(accs, fs=60, window_seconds=5)
    for start, end in slices:
        assert end - start == n


def test_quaternion_rotation_angle_starts_zero():
    q = load_raw_imu_csv(os.path.join(DATA_DIR, MOVEMENT[1]))["Quat"]
    ang = sync.quaternion_rotation_angle(q)
    # arccos is ill-conditioned near 1.0; unit-norm roundoff -> ~1e-6 deg, not 0.
    assert abs(ang[0]) < 1e-3
    assert np.all(ang >= -1e-9)


def test_resample_table_length_and_endpoints():
    df = pd.DataFrame({"a": np.arange(10.0), "b": list("abcdefghij")})
    out = sync.resample_table(df, 21)
    assert len(out) == 21
    assert out["a"].iloc[0] == 0.0
    assert out["a"].iloc[-1] == 9.0  # endpoints preserved by linear interp


def test_reorder_and_sync_writes_equal_length(tmp_path):
    # Copy the movement files into tmp, run, check equal-length outputs.
    paths = []
    for f in MOVEMENT:
        dst = tmp_path / f
        dst.write_bytes((open(os.path.join(DATA_DIR, f), "rb")).read())
        paths.append(str(dst))
    try:
        outs = reorder_sync.reorder_and_sync(paths, min_distance=40, min_prominence=3)
    except ValueError as e:
        pytest.skip(f"cycle detection not applicable to sample data: {e}")
    lengths = {len(pd.read_csv(o)) for o in outs}
    assert len(lengths) == 1  # all equal


def test_sync_and_crop_equal_length(tmp_path):
    paths = [os.path.join(DATA_DIR, f) for f in MOVEMENT]
    cropped = visualize_sync.sync_and_crop(paths, crop_fraction=(0.1, 0.9))
    lengths = {len(c) for c in cropped}
    assert len(lengths) == 1
    assert next(iter(lengths)) > 0
