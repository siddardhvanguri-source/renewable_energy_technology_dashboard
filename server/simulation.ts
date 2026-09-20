import fs from "node:fs";
import path from "node:path";

const simulationRoot = path.resolve(process.cwd(), "simulation");
const csvPath = process.env.SIMULATION_CSV_PATH || path.join(simulationRoot, "output", "simulation_results.csv");

function parseNumber(value: string | undefined) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export type SimulationFrame = {
  timestampMs: number;
  vPv: number;
  iPv: number;
  pPv: number;
  vMp: number;
  iPh: number;
  duty: number;
  efficiency: number;
  pEkf?: number;
  pPo?: number;
  dutyEkf?: number;
  dutyPo?: number;
  vOut?: number;
};

export function readSimulationRows(limit = 60): SimulationFrame[] {
  if (!fs.existsSync(csvPath)) return [];
  const lines = fs.readFileSync(csvPath, "utf8").trim().split(/\r?\n/).filter(Boolean);
  if (lines.length < 2) return [];
  const headers = lines[0].split(",").map((item) => item.trim());
  const rows = lines.slice(1).map((line) => {
    const cells = line.split(",");
    const row = Object.fromEntries(headers.map((header, index) => [header, parseNumber(cells[index])]));
    const vPv = row.v_pv ?? 0;
    const iPv = row.i_pv ?? 0;
    const pPv = row.p_pv ?? vPv * iPv;
    return {
      timestampMs: (row.time ?? 0) * 1000,
      vPv,
      iPv,
      pPv,
      vMp: row.v_mp ?? 0,
      iPh: row.i_ph ?? 0,
      duty: row.duty ?? 0,
      efficiency: row.efficiency ?? 96.8,
      pEkf: row.p_ekf,
      pPo: row.p_po,
      dutyEkf: row.duty_ekf,
      dutyPo: row.duty_po,
      vOut: row.v_out,
    } satisfies SimulationFrame;
  }).filter((row) => row.timestampMs > 0 && Number.isFinite(row.pPv));
  return rows.slice(-Math.max(1, Math.min(limit, 600)));
}

export function getSimulationStatus() {
  const rows = readSimulationRows(600);
  const modelFiles = [
    path.join(simulationRoot, "navin", "Navin_PV_model.slx.zip"),
    path.join(simulationRoot, "boost", "ekf.slx(1).zip"),
  ];
  return {
    available: rows.length > 0,
    csvPresent: fs.existsSync(csvPath),
    modelFilesPresent: modelFiles.every((file) => fs.existsSync(file)),
    rowCount: rows.length,
    lastTimestampMs: rows.at(-1)?.timestampMs ?? null,
    csvFile: "simulation/output/simulation_results.csv",
    requiredSignals: ["V_pv", "I_pv", "P_pv", "V_mp_ref", "I_ph_est", "D", "V_out"],
    scenarios: ["S1", "S2", "S3", "S4", "S5"],
    runtime: "MATLAB/Simulink required for .slx execution",
  };
}
