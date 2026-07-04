"""Tests for scripts/emg_plot.py (structural — the sample CSVs carry Env1-4)."""
import os

import matplotlib
matplotlib.use("Agg")

import pandas as pd
import pytest

from scripts import emg_plot
from tests.conftest import DATA_DIR

SAMPLE = "S2_20260703_172940.csv"


def test_channel_mapping_order():
    # Live mapping: Env1 R-TFL, Env3 L-TFL, Env2 R-GMed, Env4 L-GMed.
    cols = [c for c, _ in emg_plot.EMG_CHANNELS]
    assert cols == ["Env1", "Env3", "Env2", "Env4"]


def test_load_emg_columns():
    df = emg_plot.load_emg(os.path.join(DATA_DIR, SAMPLE))
    assert list(df.columns) == ["Env1", "Env3", "Env2", "Env4"]
    assert len(df) > 0


def test_load_emg_missing_raises(tmp_path):
    bad = tmp_path / "bad.csv"
    pd.DataFrame({"Q0": [1, 2]}).to_csv(bad, index=False)
    with pytest.raises(ValueError):
        emg_plot.load_emg(str(bad))


def test_plot_emg_builds_four_axes():
    fig = emg_plot.plot_emg(os.path.join(DATA_DIR, SAMPLE))
    assert len(fig.axes) == 4
