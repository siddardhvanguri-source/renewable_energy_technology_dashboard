const fs = require("fs");
const path = require("path");

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function parseCsv(text) {
  const lines = text.trim().split(/\r?\n/);
  if (lines.length < 2) return [];
  const headers = lines[0].split(",").map(s => s.trim());
  return lines.slice(1).map(line => {
    const cells = line.split(",");
    const row = {};
    headers.forEach((h, i) => row[h] = Number(cells[i]));
    return row;
  }).filter(r => Number.isFinite(r.time));
}

function toTelemetry(r) {
  return {
    timestamp: r.time * 1000,
    v_pv: r.v_pv ?? 0,
    i_pv: r.i_pv ?? 0,
    p_pv: r.p_pv ?? ((r.v_pv ?? 0) * (r.i_pv ?? 0)),
    v_mp: r.v_mp ?? 0,
    i_ph: r.i_ph ?? 0,
    duty: r.duty ?? 0,
    efficiency: r.efficiency,
    p_ekf: r.p_ekf,
    p_po: r.p_po,
    duty_ekf: r.duty_ekf,
    duty_po: r.duty_po,
    v_out: r.v_out
  };
}

async function replayCsv(file, broadcast, options = {}) {
  const hz = options.hz || 20;
  const interval = 1000 / hz;
  const rows = parseCsv(fs.readFileSync(file, "utf8"));
  if (!rows.length) throw new Error(`No telemetry rows in ${file}`);

  for (const row of rows) {
    broadcast(JSON.stringify(toTelemetry(row)));
    await sleep(interval);
  }
}

module.exports = { replayCsv, parseCsv, toTelemetry };
