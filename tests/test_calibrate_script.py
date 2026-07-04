"""Tests for scripts/calibrate.py — auto-match + golden RsegSens via CLI core."""
import json
import os

import numpy as np
import pytest

from scripts import calibrate
from tests.conftest import DATA_DIR, has_reference, load_ref


@has_reference
def test_run_calibration_matches_golden(tmp_path):
    # Auto-match the static files, run the core, compare to golden RsegSens.
    files = calibrate._match_auto(
        DATA_DIR, ["S2", "LT", "RT"], ["static", "n_pose"], reorder=False
    )
    assert set(files) == {"S2", "LT", "RT"}

    cal = calibrate.run_calibration(files)
    for sensor in ("S2", "LT", "RT"):
        R = np.asarray(cal[sensor]["RsegSens"])
        ref = load_ref(f"ref_RsegSens_{sensor}.csv")
        np.testing.assert_allclose(R, ref, atol=1e-6)


def test_infer_sensor():
    assert calibrate._infer_sensor("RT_foo.csv", ["S2", "LT", "RT"]) == "RT"
    assert calibrate._infer_sensor("weird.csv", ["S2", "LT", "RT"]) is None


def test_main_writes_json(tmp_path):
    out = tmp_path / "cal.json"
    calibrate.main([
        "--data-folder", DATA_DIR,
        "--posture", "n_pose",
        "--output", str(out),
    ])
    assert out.exists()
    data = json.loads(out.read_text())
    assert "S2" in data and len(data["S2"]["RsegSens"]) == 3


def test_fix_s2_axis_changes_only_s2():
    files = calibrate._match_auto(
        DATA_DIR, ["S2", "LT"], ["static", "n_pose"], reorder=False
    )
    plain = calibrate.run_calibration(files)
    fixed = calibrate.run_calibration(files, fix_s2_axis=True)
    assert not np.allclose(plain["S2"]["RsegSens"], fixed["S2"]["RsegSens"])
    np.testing.assert_allclose(plain["LT"]["RsegSens"], fixed["LT"]["RsegSens"])
