// Page 2 — Plotly line charts of joint angles over time.

const PLANE_LABELS = {
  FlexExt: "Flexion (+) / Extension (−)",
  AbdAdd: "Adduction (+) / Abduction (−)",
  VarusValgus: "Varus (+) / Valgus (−)",
  IntExt: "Internal (+) / External (−) Rotation",
  Tilt: "Tilt (Ant. + / Post. −)",
  Obliquity: "Obliquity (Lateral drop)",
  Rotation: "Rotation",
};

// Section title, then which joint keys belong to it.
const SECTIONS = [
  ["Knee", ["LKnee", "RKnee"]],
  ["Hip", ["LHip", "RHip"]],
  ["Pelvis", ["Pelvis"]],
];
const SIDE_COLOR = { L: "#4aa8ff", R: "#f0b429", "": "#4aa8ff" };

function sideOf(joint) { return joint.startsWith("L") ? "L" : joint.startsWith("R") ? "R" : ""; }

function plotPlane(container, time, series, plane) {
  const div = document.createElement("div");
  div.className = "plot";
  container.appendChild(div);
  const traces = series.map(({ joint, data }) => ({
    x: time, y: data[plane], mode: "lines", name: joint,
    line: { color: SIDE_COLOR[sideOf(joint)], width: 2 },
  }));
  const layout = Object.assign({}, PLOT_LAYOUT, {
    title: { text: PLANE_LABELS[plane], font: { size: 13 }, x: 0.01 },
    yaxis: Object.assign({}, PLOT_LAYOUT.yaxis, { title: "deg" }),
    xaxis: Object.assign({}, PLOT_LAYOUT.xaxis, { title: "Time (s)" }),
    margin: { l: 50, r: 16, t: 34, b: 40 },
  });
  Plotly.newPlot(div, traces, layout, PLOT_CONFIG);
}

async function render() {
  const root = document.getElementById("report");
  let ts;
  try { ts = await apiGet("/api/timeseries"); }
  catch (e) { emptyState(root, e.message + " — go to <b>Load &amp; Run</b> first."); return; }

  root.innerHTML = "";
  const joints = ts.joints;
  let any = false;

  for (const [title, keys] of SECTIONS) {
    const present = keys.filter(k => joints[k]);
    if (!present.length) continue;
    any = true;

    const h = document.createElement("h2");
    h.textContent = title;
    root.appendChild(h);
    const panel = document.createElement("div");
    panel.className = "panel";
    root.appendChild(panel);

    const series = present.map(joint => ({ joint, data: joints[joint] }));
    const planes = Object.keys(joints[present[0]]);
    for (const plane of planes) plotPlane(panel, ts.time, series, plane);
  }

  if (!any) emptyState(root, "No joint angles available. Check your sensor assignments on the Load page.");
}

render();
