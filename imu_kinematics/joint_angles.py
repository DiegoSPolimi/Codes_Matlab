"""Joint angles via the Grood & Suntay Joint Coordinate System.

Ports of the LIVE code in:
  * ``computeHipJCS.m`` (whole file; offset removal is disabled there, so none
    is applied here).
  * ``computeKneeJCS.m`` (only the live block "MAYBE BETTER VERSION ..." near
    the bottom). Offset "Strategy A" (zero at max extension) is the default;
    B (mean of first 30 frames) and C (global mean) are exposed as options,
    matching the commented alternatives in the .m file (plan Section 6).
  * ``computePelvisGlobalAngles`` / ``ea2euler`` local functions in
    ``main_Compute_Angles_MANUAL.m``.

Inputs are ``(N, 3, 3)`` orientation arrays (columns = ML/AP/Long in global),
as produced by :func:`imu_kinematics.orientation.compute_segment_orientation`.
All angles are returned in DEGREES as dicts of ``(N,)`` arrays.
"""

from __future__ import annotations

import numpy as np

__all__ = [
    "compute_hip_jcs",
    "compute_knee_jcs",
    "compute_pelvis_global_angles",
]


def _atan2d(y, x):
    return np.degrees(np.arctan2(y, x))


def compute_hip_jcs(RPelvis, RThigh):
    """Hip Flex/Ext, Abd/Add, Int/Ext (degrees). No offset removal.

    Fields returned: ``FlexExt``, ``AbdAdd``, ``IntExt`` (note: the .m header
    comment says ``AddAbd`` but the live code writes ``AbdAdd`` — code wins).
    """
    RPelvis = np.asarray(RPelvis, dtype=float)
    RThigh = np.asarray(RThigh, dtype=float)
    N = min(RPelvis.shape[0], RThigh.shape[0])

    FlexExt = np.zeros(N)
    AbdAdd = np.zeros(N)
    IntExt = np.zeros(N)

    for k in range(N):
        Rp = RPelvis[k]
        Rt = RThigh[k]
        Ip, Jp, Kp = Rp[:, 0], Rp[:, 1], Rp[:, 2]
        It, _Jt, Kt = Rt[:, 0], Rt[:, 1], Rt[:, 2]

        H = np.cross(Kt, Ip)
        if np.linalg.norm(H) > 1e-6:
            H = H / np.linalg.norm(H)
        else:
            H = np.array([0.0, 1.0, 0.0])

        FlexExt[k] = _atan2d(np.dot(np.cross(Jp, H), Ip), np.dot(Jp, H))
        AbdAdd[k] = _atan2d(np.dot(np.cross(Kp, Kt), H), np.dot(Kp, Kt))
        IntExt[k] = _atan2d(np.dot(np.cross(H, It), Kt), np.dot(H, It))

    return {"FlexExt": FlexExt, "AbdAdd": AbdAdd, "IntExt": IntExt}


def compute_knee_jcs(RThigh, RShank, offset_strategy="A", static_frames=30):
    """Knee Flex/Ext, Varus/Valgus, Int/Ext (degrees).

    Parameters
    ----------
    offset_strategy : {"A", "B", "C", None}
        A (default) = zero FlexExt at its max, VV/IE at frame 0 (live behavior).
        B = subtract mean of first ``static_frames`` frames per channel.
        C = subtract global mean per channel.
        None = no offset removal.
    """
    RThigh = np.asarray(RThigh, dtype=float)
    RShank = np.asarray(RShank, dtype=float)
    N = RThigh.shape[0]

    FlexExt = np.zeros(N)
    VarusValgus = np.zeros(N)
    IntExt = np.zeros(N)

    for k in range(N):
        Rt = RThigh[k]
        Rs = RShank[k]
        It, Jt, _Kt = Rt[:, 0], Rt[:, 1], Rt[:, 2]
        _Is, Js, Ks = Rs[:, 0], Rs[:, 1], Rs[:, 2]

        e1 = It          # femur ML
        e3 = Ks          # tibia longitudinal
        e2 = np.cross(e3, e1)
        e2 = e2 / np.linalg.norm(e2)

        FlexExt[k] = _atan2d(np.dot(np.cross(Jt, e2), e1), np.dot(Jt, e2))
        VarusValgus[k] = np.degrees(np.arcsin(np.dot(e1, e3)))
        IntExt[k] = _atan2d(np.dot(np.cross(e2, Js), e3), np.dot(e2, Js))

    if offset_strategy == "A":
        FlexExt = FlexExt - np.max(FlexExt)
        VarusValgus = VarusValgus - VarusValgus[0]
        IntExt = IntExt - IntExt[0]
    elif offset_strategy == "B":
        n = min(static_frames, N)
        FlexExt = FlexExt - np.mean(FlexExt[:n])
        VarusValgus = VarusValgus - np.mean(VarusValgus[:n])
        IntExt = IntExt - np.mean(IntExt[:n])
    elif offset_strategy == "C":
        FlexExt = FlexExt - np.mean(FlexExt)
        VarusValgus = VarusValgus - np.mean(VarusValgus)
        IntExt = IntExt - np.mean(IntExt)
    elif offset_strategy is not None:
        raise ValueError(f"unknown offset_strategy: {offset_strategy!r}")

    return {"FlexExt": FlexExt, "VarusValgus": VarusValgus, "IntExt": IntExt}


def compute_pelvis_global_angles(RPelvis):
    """Pelvis tilt/obliquity/rotation vs. global (degrees).

    Ports ``computePelvisGlobalAngles`` + ``ea2euler`` from
    ``main_Compute_Angles_MANUAL.m``. MATLAB 1-based ``R(i,j)`` maps to
    0-based ``R[i-1, j-1]``.
    """
    RPelvis = np.asarray(RPelvis, dtype=float)
    N = RPelvis.shape[0]
    Tilt = np.zeros(N)
    Obliquity = np.zeros(N)
    Rotation = np.zeros(N)

    for i in range(N):
        R = RPelvis[i]
        pitch = -np.arcsin(R[2, 0])
        if np.cos(pitch) > 1e-4:
            yaw = np.arctan2(R[1, 0], R[0, 0])
            roll = np.arctan2(R[2, 1], R[2, 2])
        else:
            yaw = 0.0
            roll = np.arctan2(-R[0, 1], R[1, 1])
        Tilt[i] = np.degrees(pitch)
        Obliquity[i] = np.degrees(roll)
        Rotation[i] = np.degrees(yaw)

    return {"Tilt": Tilt, "Obliquity": Obliquity, "Rotation": Rotation}
