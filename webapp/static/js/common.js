// Shared helpers: API calls + Plotly theming.

async function apiGet(url) {
  const r = await fetch(url);
  const data = await r.json();
  if (!r.ok) throw new Error(data.error || `Request failed (${r.status})`);
  return data;
}

async function apiPostJSON(url, body) {
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok) throw new Error(data.error || `Request failed (${r.status})`);
  return data;
}

async function apiUpload(files, kind) {
  const fd = new FormData();
  fd.append("kind", kind);
  for (const f of files) fd.append("files", f);
  const r = await fetch("/api/upload", { method: "POST", body: fd });
  const data = await r.json();
  if (!r.ok) throw new Error(data.error || `Upload failed (${r.status})`);
  return data.files;
}

// Dark Plotly layout shared by all charts.
const PLOT_LAYOUT = {
  paper_bgcolor: "rgba(0,0,0,0)",
  plot_bgcolor: "rgba(0,0,0,0)",
  font: { color: "#e6edf3", size: 12 },
  margin: { l: 50, r: 16, t: 10, b: 40 },
  legend: { orientation: "h", y: 1.15 },
  xaxis: { gridcolor: "#2c3d4f", zerolinecolor: "#3a4d61" },
  yaxis: { gridcolor: "#2c3d4f", zerolinecolor: "#3a4d61" },
};
const PLOT_CONFIG = { responsive: true, displaylogo: false };

function emptyState(container, msg) {
  container.innerHTML = `<div class="empty">${msg}</div>`;
}
