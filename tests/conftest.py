"""Shared test fixtures/paths."""
import os
import sys

import numpy as np
import pandas as pd
import pytest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REFERENCE_DIR = os.path.join(REPO_ROOT, "reference")
DATA_DIR = os.path.join(REPO_ROOT, "Example_Acquisitions")

# Make the package importable without installation.
sys.path.insert(0, REPO_ROOT)

has_reference = pytest.mark.skipif(
    not os.path.isdir(REFERENCE_DIR),
    reason="reference/ golden files not present (run generate_reference.m)",
)


def load_ref(name):
    """Load a reference CSV (headerless matrix) as a float ndarray."""
    path = os.path.join(REFERENCE_DIR, name)
    return pd.read_csv(path, header=None).to_numpy(dtype=float)


def read_quat_csv(name):
    """Read Q0..Q3 (scalar-first) from an Example_Acquisitions CSV."""
    path = os.path.join(DATA_DIR, name)
    df = pd.read_csv(path)
    return df[["Q0", "Q1", "Q2", "Q3"]].to_numpy(dtype=float)
