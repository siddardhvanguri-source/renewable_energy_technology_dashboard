/**
 * Shared telemetry types and normalization for the MPPT dashboard.
 *
 * All producers (MATLAB, ESP32, DEMO) converge through `normalize()`
 * so the rest of the frontend always sees a consistent `Frame` shape.
 */

export type TelemetrySource = "MATLAB" | "ESP32" | "DEMO";

export type Frame = {
  timestampMs: number;
  vPv: number;
  iPv: number;
  pPv: number;
  vMp: number;
  iPh: number;
  duty: number;
  efficiency: number;
  source: TelemetrySource;
  scenarioCode?: string;
};

/**
 * Normalize any incoming telemetry sample (snake_case or camelCase)
 * into the canonical `Frame` shape used by the UI.
 */
export function normalize(sample: any): Frame {
  const vPv = Number(sample.vPv ?? sample.v_pv ?? 0);
  const iPv = Number(sample.iPv ?? sample.i_pv ?? 0);
  const rawEff =
    sample.efficiency !== undefined && sample.efficiency !== null && !isNaN(Number(sample.efficiency)) && Number(sample.efficiency) > 0
      ? Number(sample.efficiency)
      : undefined;
  return {
    timestampMs: Number(sample.timestampMs ?? sample.timestamp_ms ?? sample.timestamp ?? Date.now()),
    vPv,
    iPv,
    pPv: Number(sample.pPv ?? sample.p_pv ?? vPv * iPv),
    vMp: Number(sample.vMp ?? sample.v_mp ?? vPv),
    iPh: Number(sample.iPh ?? sample.i_ph ?? iPv),
    duty: Number(sample.duty ?? 0),
    efficiency: rawEff as unknown as number,
    source: (sample.source ?? "MATLAB") as TelemetrySource,
    scenarioCode: sample.scenarioCode ?? sample.scenario_code ?? "S5",
  };
}

/**
 * Generate a single demo frame for fallback display (10W PV System).
 */
export function demoFrame(timestampMs = Date.now()): Frame {
  const phase = timestampMs / 1000;
  const vPv = 17.5 + Math.sin(phase * 0.72) * 0.08;
  const iPv = 0.57 + Math.cos(phase * 0.58) * 0.01;
  return {
    timestampMs,
    vPv: Number(vPv.toFixed(2)),
    iPv: Number(iPv.toFixed(3)),
    pPv: Number((vPv * iPv).toFixed(2)),
    vMp: 17.5,
    iPh: 0.65,
    duty: 0.386 + Math.sin(phase * 0.29) * 0.005,
    efficiency: 99.8 + Math.sin(phase * 0.31) * 0.1,
    source: "DEMO",
  };
}

/** Milliseconds before a live source is considered stale. */
export const STALE_TIMEOUT_MS = 10_000;
