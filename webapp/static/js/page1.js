// Page 1 — upload static/dynamic files, assign roles, run analysis.

const uploaded = { static: [], dynamic: [] };

function wireDrop(kind) {
  const drop = document.getElementById(`drop-${kind}`);
  const input = document.getElementById(`file-${kind}`);
  const table = document.getElementById(`tbl-${kind}`);
  const tbody = table.querySelector("tbody");

  ["dragover", "dragenter"].forEach(ev =>
    drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.add("hover"); }));
  ["dragleave", "drop"].forEach(ev =>
    drop.addEventListener(ev, e => { e.preventDefault(); drop.classList.remove("hover"); }));
  drop.addEventListener("drop", e => handleFiles(e.dataTransfer.files));
  input.addEventListener("change", () => handleFiles(input.files));

  async function handleFiles(fileList) {
    if (!fileList.length) return;
    setStatus(`Uploading ${fileList.length} ${kind} file(s)…`);
    try {
      const saved = await apiUpload(fileList, kind);
      uploaded[kind] = uploaded[kind].concat(saved);
      renderTable();
      setStatus("");
    } catch (e) { setStatus(e.message, "err"); }
  }

  function renderTable() {
    tbody.innerHTML = "";
    const tpl = document.getElementById("row-tpl");
    uploaded[kind].forEach((f, i) => {
      const node = tpl.content.cloneNode(true);
      node.querySelector(".fname").textContent = f.name;
      const sel = node.querySelector(".role");
      sel.value = f.role || "";
      sel.addEventListener("change", () => { uploaded[kind][i].role = sel.value; updateRunState(); });
      tbody.appendChild(node);
    });
    table.hidden = uploaded[kind].length === 0;
    updateRunState();
  }
}

function roleMap(kind) {
  const map = {};
  for (const f of uploaded[kind]) if (f.role) map[f.role] = f.path;
  return map;
}

function updateRunState() {
  const s = roleMap("static"), d = roleMap("dynamic");
  document.getElementById("run").disabled = !(Object.keys(s).length && Object.keys(d).length);
}

function setStatus(msg, cls = "") {
  const el = document.getElementById("status");
  el.textContent = msg;
  el.className = "status" + (cls ? " " + cls : "");
}

document.getElementById("run").addEventListener("click", async () => {
  setStatus("Running calibration + analysis…");
  document.getElementById("run").disabled = true;
  try {
    const res = await apiPostJSON("/api/run", {
      static: roleMap("static"),
      dynamic: roleMap("dynamic"),
      fix_s2_axis: document.getElementById("fix-s2").checked,
    });
    const joints = res.joints.join(", ") || "none";
    setStatus(
      `✓ Done — ${res.frames} frames, ${res.n_cycles} cycles. Joints: ${joints}. ` +
      `Open the Time-Series, Metrics, or EMG pages.`, "ok");
  } catch (e) {
    setStatus(e.message, "err");
  } finally {
    updateRunState();
  }
});

wireDrop("static");
wireDrop("dynamic");
