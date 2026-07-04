"""Plotting helpers (ports of ``plotAngles.m`` and ``plotCalibrationFrames.m``).

Figures are returned (not shown) so callers/tests can decide whether to
``plt.show()`` or save. Uses whatever matplotlib backend is configured;
tests set a non-interactive backend.
"""

from __future__ import annotations

import numpy as np

__all__ = ["plot_angles", "plot_calibration_frames"]


def plot_angles(time, joint, joint_name):
    """3-subplot angle figure (mirrors the live ``plotAngles.m``).

    Adapts each row to whichever field is present so it serves Hip, Knee, and
    Pelvis-global structs: row1 FlexExt|Tilt, row2 AbdAdd|VarusValgus|Obliquity,
    row3 IntExt|Rotation.
    """
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(3, 1, num=joint_name)
    fig.patch.set_facecolor("w")

    if "FlexExt" in joint:
        axes[0].plot(time, joint["FlexExt"], linewidth=2)
        axes[0].set_title(f"{joint_name} Flexion (+) / Extension (-)")
    elif "Tilt" in joint:
        axes[0].plot(time, joint["Tilt"], linewidth=2)
        axes[0].set_title(f"{joint_name} Tilt (Anterior + / Posterior -)")
    axes[0].grid(True); axes[0].set_ylabel("Angle (deg)")

    if "AbdAdd" in joint:
        axes[1].plot(time, joint["AbdAdd"], linewidth=2)
        axes[1].set_title(f"{joint_name} Adduction (+) / Abduction (-)")
    elif "VarusValgus" in joint:
        axes[1].plot(time, joint["VarusValgus"], linewidth=2)
        axes[1].set_title(f"{joint_name} Varus (+) / Valgus (-)")
    elif "Obliquity" in joint:
        axes[1].plot(time, joint["Obliquity"], linewidth=2)
        axes[1].set_title(f"{joint_name} Obliquity (Lateral Drop)")
    axes[1].grid(True); axes[1].set_ylabel("Angle (deg)")

    if "IntExt" in joint:
        axes[2].plot(time, joint["IntExt"], linewidth=2)
        axes[2].set_title(f"{joint_name} Internal (+) / External (-) Rotation")
    elif "Rotation" in joint:
        axes[2].plot(time, joint["Rotation"], linewidth=2)
        axes[2].set_title(f"{joint_name} Rotation")
    axes[2].grid(True); axes[2].set_ylabel("Angle (deg)"); axes[2].set_xlabel("Time (s)")

    fig.tight_layout()
    return fig


def plot_calibration_frames(calibration, segments=("LT", "S2")):
    """3-D sensor-vs-anatomical frame comparison (mirrors ``plotCalibrationFrames.m``).

    ``calibration`` maps segment name -> dict with key ``RsegSens`` (3x3), or a
    3x3 array directly. Draws the fixed sensor axes (dashed) and the calibrated
    ML/AP/Long axes (r/g/b) for each requested segment.
    """
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d import Axes3D  # noqa: F401 (registers 3d proj)

    fig = plt.figure(num="Calibration Reference Frames")
    fig.patch.set_facecolor("w")

    for i, seg in enumerate(segments):
        ax = fig.add_subplot(2, 2, i + 1, projection="3d")
        entry = calibration[seg]
        R = np.asarray(entry["RsegSens"] if isinstance(entry, dict) else entry, dtype=float)

        # Sensor frame (dashed, unit axes).
        for vec in np.eye(3):
            ax.quiver(0, 0, 0, *vec, color="k", linestyle="--", linewidth=2)

        # Anatomical axes: columns of R (ML=r, AP=g, Long=b).
        for col, color, label in zip(range(3), ("r", "g", "b"), ("ML", "AP", "Long")):
            ax.quiver(0, 0, 0, R[0, col], R[1, col], R[2, col], color=color, linewidth=3)
            ax.text(R[0, col] * 1.1, R[1, col] * 1.1, R[2, col] * 1.1, label, color=color)

        ax.set_xlim(-1.2, 1.2); ax.set_ylim(-1.2, 1.2); ax.set_zlim(-1.2, 1.2)
        ax.set_xlabel("Up (+X)"); ax.set_ylabel("Forward (+Y)"); ax.set_zlabel("Lateral (+Z)")
        ax.set_title(seg)

    fig.suptitle("Comparison between Sensor and Anatomical Reference Frames")
    return fig
