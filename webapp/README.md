# Cycling Kinematics Web App

Flask + HTML/CSS/JS (Plotly) frontend over the `imu_kinematics` backend.

## Run

```bash
# from the repo root, with the project venv
PORT=5055 .venv/bin/python -m webapp.app
# open http://127.0.0.1:5055
```

macOS note: port 5000 is taken by AirPlay/ControlCenter — use another port via `PORT`.

## Pages

1. **Load & Run** — upload static-calibration CSVs and dynamic cycling CSVs,
   assign each file to a sensor role (auto-detected from the filename, editable),
   optionally apply the S2 axis-swap, then run calibration + analysis.
2. **Time-Series** — interactive Plotly line charts of joint angles over time,
   split into Knee / Hip / Pelvis sections (both legs where data allows).
3. **Metrics** — average peak knee angles per cycle (flexion, extension, valgus,
   varus) and a pelvic-stability panel (std/range of tilt, obliquity, rotation)
   with ok/warn/high conditional formatting and alerts.
4. **EMG** — envelope traces per muscle (TFL, Gluteus Medius) for both legs,
   read from the `Env1–4` columns of a dynamic recording.

## Sensor roles

`S2` (pelvis), `LT`/`RT` (left/right thigh), `LShank`/`RShank` (left/right shank).
Knee angles require the matching thigh **and** shank (left knee = LT+LShank,
right = RT+RShank). With only S2/LT/RT (like the bundled example data) the app
shows Hip + Pelvis and reports that shank files are needed for the knee.

## API (session-scoped, results cached server-side)

| Method | Route | Purpose |
|---|---|---|
| POST | `/api/upload` | save CSVs, return files + guessed roles |
| POST | `/api/run` | calibrate (static) + analyze (dynamic) |
| GET | `/api/timeseries` | angle series for Plotly |
| GET | `/api/metrics` | knee metrics + pelvic variability/flags |
| GET | `/api/emg` | EMG envelope channels |

## Caveats

- **Pelvic variability** is computed on the absolute pelvis-vs-global Euler
  angles. On a real N-pose-calibrated seated pedaling trial these stay in a
  small range, so the default thresholds (warn ≥ 3°, high ≥ 5° std) are
  meaningful. The bundled example movement is not a clean pedaling capture, so
  its pelvic std is large and every axis flags "high" — that is data, not a bug.
  Thresholds live in `imu_kinematics/metrics.py::DEFAULT_PELVIC_THRESHOLDS`.
- Uploaded files go to a per-session temp workspace; results are held in memory
  and are lost on server restart. This is a single-user dev setup, not hardened
  for production (use a real WSGI server + persistent storage for that).
