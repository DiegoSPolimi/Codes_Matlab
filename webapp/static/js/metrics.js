// Page 3 — knee metric cards + pelvic stability analysis with alerts.

function card(k, v, unit, cls = "") {
  return `<div class="card ${cls}">
    <div class="k">${k}</div>
    <div class="v">${v}</div>
    <div class="u">${unit}</div>
  </div>`;
}

const SIDE_NAME = { LKnee: "Left Knee", RKnee: "Right Knee" };
const AXIS_HELP = {
  Tilt: "Anterior/posterior pelvic tilt",
  Obliquity: "Lateral pelvic drop",
  Rotation: "Transverse pelvic rotation",
};

function kneeSection(side, m) {
  return `<h2>${SIDE_NAME[side]} — average peak angles (${m.n_cycles} cycles)</h2>
  <div class="cards">
    ${card("Avg. Knee Flexion", m.avg_peak_flexion.toFixed(1), "° (peak per cycle)")}
    ${card("Avg. Knee Extension", m.avg_peak_extension.toFixed(1), "° (peak per cycle)")}
    ${card("Avg. Knee Valgus (Abd.)", m.avg_peak_valgus.toFixed(1), "° (peak per cycle)")}
    ${card("Avg. Knee Varus (Add.)", m.avg_peak_varus.toFixed(1), "° (peak per cycle)")}
  </div>`;
}

function pelvicSection(pelvic, flags, thresholds) {
  const alerts = Object.entries(flags)
    .filter(([, lvl]) => lvl !== "ok")
    .map(([axis, lvl]) => {
      const verb = lvl === "high" ? "excessive" : "elevated";
      return `<div class="alert ${lvl}">⚠ ${verb} pelvic ${axis.toLowerCase()} variability
        (${pelvic[axis].std.toFixed(1)}° SD) — the athlete moves the pelvis a lot during pedaling.</div>`;
    }).join("");

  const cards = Object.entries(pelvic).map(([axis, s]) => {
    const lvl = flags[axis] || "ok";
    const badge = `<span class="badge ${lvl}">${lvl.toUpperCase()}</span>`;
    return `<div class="card ${lvl}">
      <div class="k">${axis} &nbsp; ${badge}</div>
      <div class="v">${s.std.toFixed(1)}<span class="u"> ° SD</span></div>
      <div class="u">${AXIS_HELP[axis]} · range ${s.range.toFixed(1)}° · warn ≥ ${thresholds[axis].warn}° / high ≥ ${thresholds[axis].high}°</div>
    </div>`;
  }).join("");

  return `<h2>Pelvic Stability Analysis</h2>${alerts}
    <div class="cards">${cards}</div>
    <p class="muted" style="margin-top:10px">Higher standard deviation = less pelvic stability. Thresholds are configurable in the backend (<code>DEFAULT_PELVIC_THRESHOLDS</code>).</p>`;
}

async function render() {
  const root = document.getElementById("metrics");
  let data;
  try { data = await apiGet("/api/metrics"); }
  catch (e) { emptyState(root, e.message + " — go to <b>Load &amp; Run</b> first."); return; }

  let html = "";
  if (data.has_knee) {
    for (const side of ["LKnee", "RKnee"]) if (data.knee[side]) html += kneeSection(side, data.knee[side]);
  } else {
    html += `<div class="alert warn">No knee data — assign left/right <b>shank</b> files on the Load page to compute knee metrics.</div>`;
  }
  if (Object.keys(data.pelvic).length) html += pelvicSection(data.pelvic, data.pelvic_flags, data.thresholds);

  root.innerHTML = html || `<div class="empty">No metrics available.</div>`;
}

render();
