// Page 4 — EMG envelopes per muscle, both legs, with summary stats.

const MUSCLES = [
  ["Tensor Fasciae Latae (TFL)", "TFL"],
  ["Gluteus Medius", "GMed"],
];
const SIDE_COLOR = { Right: "#f0b429", Left: "#4aa8ff" };

function sideOf(label) { return label.startsWith("Right") ? "Right" : "Left"; }
function mean(a) { return a.reduce((s, x) => s + x, 0) / a.length; }
function peak(a) { return Math.max(...a); }

function statCards(chans) {
  return `<div class="cards" style="margin-bottom:12px">` + chans.map(c => {
    const side = sideOf(c.label);
    return card(`${side} — mean / peak`, `${mean(c.values).toFixed(0)} / ${peak(c.values).toFixed(0)}`, "envelope units");
  }).join("") + `</div>`;
}
function card(k, v, u) {
  return `<div class="card"><div class="k">${k}</div><div class="v">${v}</div><div class="u">${u}</div></div>`;
}

function muscleSection(root, fullName, chans) {
  const h = document.createElement("h2");
  h.textContent = fullName;
  root.appendChild(h);
  const panel = document.createElement("div");
  panel.className = "panel";
  panel.innerHTML = statCards(chans);
  root.appendChild(panel);

  const div = document.createElement("div");
  div.className = "plot";
  panel.appendChild(div);
  const traces = chans.map(c => ({
    y: c.values, mode: "lines", name: sideOf(c.label),
    line: { color: SIDE_COLOR[sideOf(c.label)], width: 1.4 },
  }));
  const layout = Object.assign({}, PLOT_LAYOUT, {
    yaxis: Object.assign({}, PLOT_LAYOUT.yaxis, { title: "EMG envelope" }),
    xaxis: Object.assign({}, PLOT_LAYOUT.xaxis, { title: "Sample" }),
  });
  Plotly.newPlot(div, traces, layout, PLOT_CONFIG);
}

async function render() {
  const root = document.getElementById("emg");
  let data;
  try { data = await apiGet("/api/emg"); }
  catch (e) { emptyState(root, e.message + " — go to <b>Load &amp; Run</b> first."); return; }

  if (!data.channels.length) { emptyState(root, "No EMG channels (Env1–4) found in the recording."); return; }

  root.innerHTML = `<p class="muted">Source recording: <code>${data.source}</code></p>`;
  for (const [fullName, key] of MUSCLES) {
    const chans = data.channels.filter(c => c.label.includes(key === "TFL" ? "TFL" : "Gluteus"));
    if (chans.length) muscleSection(root, fullName, chans);
  }
}

render();
