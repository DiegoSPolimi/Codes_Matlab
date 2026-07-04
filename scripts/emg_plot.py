"""EMG envelope viewer (port of the live block in ``EMG_Plotting.m``).

Independent of the IMU pipeline. Reads the four EMG envelope channels and
plots them as 4 stacked subplots BY SAMPLE INDEX (the live script's time-axis
code is commented out, so no time conversion is applied — data contract).

Live channel mapping (bottom block of EMG_Plotting.m, which differs from the
dead top block): Env1->Right_TFL, Env2->Right_GMed, Env3->Left_TFL,
Env4->Left_GMed.
"""

from __future__ import annotations

import argparse

import pandas as pd

# Ordered (column, label) pairs matching the live subplot layout.
EMG_CHANNELS = [
    ("Env1", "Right Tensor Fasciae Latae (TFL)"),
    ("Env3", "Left Tensor Fasciae Latae (TFL)"),
    ("Env2", "Right Gluteus Medius"),
    ("Env4", "Left Gluteus Medius"),
]


def load_emg(file_path):
    """Return a DataFrame of the four EMG envelope channels (by column name)."""
    df = pd.read_csv(file_path)
    missing = [c for c, _ in EMG_CHANNELS if c not in df.columns]
    if missing:
        raise ValueError(f"{file_path} missing EMG columns: {missing}")
    return df[[c for c, _ in EMG_CHANNELS]].copy()


def plot_emg(file_path):
    """Build the 4-subplot EMG figure (by sample index). Returns the figure."""
    import matplotlib.pyplot as plt

    df = load_emg(file_path)
    colors = ["b", "r", "g", "m"]
    fig, axes = plt.subplots(4, 1)
    for ax, (col, title), color in zip(axes, EMG_CHANNELS, colors):
        ax.plot(df[col].to_numpy(), color, linewidth=1.5)  # x = sample index
        ax.grid(True)
        ax.set_ylabel("EMG")
        ax.set_title(title)
    axes[-1].set_xlabel("Sample")
    fig.tight_layout()
    return fig


def main(argv=None):
    p = argparse.ArgumentParser(description="Plot EMG envelope channels.")
    p.add_argument("file", nargs="?", help="EMG CSV file.")
    args = p.parse_args(argv)

    path = args.file
    if not path:
        from tkinter import Tk, filedialog
        Tk().withdraw()
        path = filedialog.askopenfilename(
            title="Select the EMG CSV file", filetypes=[("CSV", "*.csv")])
        if not path:
            p.error("No file selected.")

    import matplotlib.pyplot as plt
    plot_emg(path)
    plt.show()


if __name__ == "__main__":
    main()
