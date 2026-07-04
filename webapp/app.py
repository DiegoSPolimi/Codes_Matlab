"""Flask web app for the IMU cycling-kinematics pipeline.

Thin REST layer over the ``imu_kinematics`` backend + a 4-page HTML/CSS/JS
frontend. Uploaded files live in a per-session workspace; calibration and
analysis results are cached server-side so Pages 2-4 just fetch them.

Run:  python -m webapp.app   (or  flask --app webapp.app run)
"""

from __future__ import annotations

import os
import sys
import tempfile
import uuid

import numpy as np
from flask import (
    Flask, jsonify, render_template, request, session,
)

# Make the project importable when run as a module or a script.
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from imu_kinematics.calibration import compute_static_calibration, apply_s2_axis_swap
from imu_kinematics.io import load_imu_csv
from imu_kinematics import metrics as metrics_mod
from imu_kinematics.metrics import (
    knee_cycle_metrics, pelvic_variability, pelvic_stability_flags,
    DEFAULT_PELVIC_THRESHOLDS,
)
from scripts.compute_angles import analyze_session
from scripts.emg_plot import EMG_CHANNELS

ROLES = ["S2", "LT", "RT", "LShank", "RShank"]

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-key-change-me")

# Server-side per-session state: {sid: {"workspace", "calibration", "results", "emg_source"}}
_SESSIONS: dict[str, dict] = {}


# --------------------------------------------------------------------------
# Session helpers
# --------------------------------------------------------------------------
def _state():
    sid = session.get("sid")
    if not sid or sid not in _SESSIONS:
        sid = uuid.uuid4().hex
        session["sid"] = sid
        _SESSIONS[sid] = {
            "workspace": tempfile.mkdtemp(prefix=f"imu_{sid}_"),
            "calibration": None,
            "results": None,
            "emg_source": None,
        }
    return _SESSIONS[sid]


def guess_role(filename):
    """Best-effort sensor role from a filename (user can override in the UI)."""
    low = os.path.basename(filename).lower()
    if "lshank" in low or "l_shank" in low:
        return "LShank"
    if "rshank" in low or "r_shank" in low:
        return "RShank"
    if "s2" in low:
        return "S2"
    if low.startswith("lt") or "_lt" in low or "lthigh" in low:
        return "LT"
    if low.startswith("rt") or "_rt" in low or "rthigh" in low:
        return "RT"
    return ""


def _to_list(x):
    return np.asarray(x, dtype=float).tolist()


# --------------------------------------------------------------------------
# Pages
# --------------------------------------------------------------------------
@app.route("/")
def page_load():
    return render_template("index.html", active="load", roles=ROLES)


@app.route("/report")
def page_report():
    return render_template("report.html", active="report")


@app.route("/metrics")
def page_metrics():
    return render_template("metrics.html", active="metrics")


@app.route("/emg")
def page_emg():
    return render_template("emg.html", active="emg")


# --------------------------------------------------------------------------
# API
# --------------------------------------------------------------------------
@app.post("/api/upload")
def api_upload():
    st = _state()
    kind = request.form.get("kind", "dynamic")  # 'static' | 'dynamic'
    saved = []
    for f in request.files.getlist("files"):
        if not f.filename:
            continue
        dest = os.path.join(st["workspace"], f"{kind}__{os.path.basename(f.filename)}")
        f.save(dest)
        saved.append({"name": os.path.basename(f.filename),
                      "path": dest,
                      "role": guess_role(f.filename)})
    return jsonify({"files": saved})


@app.post("/api/run")
def api_run():
    """Calibrate from static files, then analyze dynamic files.

    JSON body:
      static  : {role: path}
      dynamic : {role: path}
      fix_s2_axis : bool
      thresholds  : optional {axis: {warn, high}}
    """
    st = _state()
    body = request.get_json(force=True)
    static_map = body.get("static", {})
    dynamic_map = body.get("dynamic", {})
    fix_s2 = bool(body.get("fix_s2_axis", False))

    if not static_map:
        return jsonify({"error": "No static calibration files assigned."}), 400
    if not dynamic_map:
        return jsonify({"error": "No dynamic recording files assigned."}), 400

    # Calibration
    calibration = {}
    for role, path in static_map.items():
        R = compute_static_calibration(load_imu_csv(path)["Quat"])
        if fix_s2 and role == "S2":
            R = apply_s2_axis_swap(R)
        calibration[role] = R
    st["calibration"] = calibration

    # Analysis
    try:
        results = analyze_session(dynamic_map, calibration)
    except Exception as e:  # surface backend errors to the UI
        return jsonify({"error": str(e)}), 400
    st["results"] = results
    st["thresholds"] = body.get("thresholds") or DEFAULT_PELVIC_THRESHOLDS

    # EMG source: prefer S2 dynamic, else first dynamic file.
    st["emg_source"] = dynamic_map.get("S2") or next(iter(dynamic_map.values()))

    joints = [k for k in ("Pelvis", "LHip", "RHip", "LKnee", "RKnee") if k in results]
    return jsonify({
        "frames": int(len(results["time"])),
        "n_cycles": int(max(len(results["troughs"]) - 1, 0)),
        "joints": joints,
        "calibrated_roles": list(calibration.keys()),
    })


@app.get("/api/timeseries")
def api_timeseries():
    st = _state()
    res = st.get("results")
    if not res:
        return jsonify({"error": "Run an analysis first."}), 400

    out = {"time": _to_list(res["time"]), "joints": {}}
    fields = {
        "Pelvis": ["Tilt", "Obliquity", "Rotation"],
        "LHip": ["FlexExt", "AbdAdd", "IntExt"],
        "RHip": ["FlexExt", "AbdAdd", "IntExt"],
        "LKnee": ["FlexExt", "VarusValgus", "IntExt"],
        "RKnee": ["FlexExt", "VarusValgus", "IntExt"],
    }
    for joint, cols in fields.items():
        if joint in res:
            out["joints"][joint] = {c: _to_list(res[joint][c]) for c in cols}
    return jsonify(out)


@app.get("/api/metrics")
def api_metrics():
    st = _state()
    res = st.get("results")
    if not res:
        return jsonify({"error": "Run an analysis first."}), 400
    troughs = res.get("troughs", np.array([]))

    knee = {}
    for side in ("LKnee", "RKnee"):
        if side in res and len(troughs) >= 2:
            knee[side] = knee_cycle_metrics(res[side], troughs)

    pelvic = {}
    flags = {}
    if "Pelvis" in res:
        pelvic = pelvic_variability(res["Pelvis"])
        flags = pelvic_stability_flags(pelvic, st.get("thresholds"))

    return jsonify({
        "n_cycles": int(max(len(troughs) - 1, 0)),
        "knee": knee,
        "pelvic": pelvic,
        "pelvic_flags": flags,
        "thresholds": st.get("thresholds", DEFAULT_PELVIC_THRESHOLDS),
        "has_knee": bool(knee),
    })


@app.get("/api/emg")
def api_emg():
    st = _state()
    src = st.get("emg_source")
    if not src:
        return jsonify({"error": "Run an analysis first."}), 400
    import pandas as pd
    df = pd.read_csv(src)
    channels = []
    for col, label in EMG_CHANNELS:
        if col in df.columns:
            channels.append({"column": col, "label": label,
                             "values": _to_list(df[col].to_numpy())})
    return jsonify({"source": os.path.basename(src), "channels": channels})


if __name__ == "__main__":
    app.run(debug=True, port=int(os.environ.get("PORT", 5001)))
