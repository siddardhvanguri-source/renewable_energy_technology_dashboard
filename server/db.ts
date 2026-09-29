import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

const DATA_DIR = path.resolve(process.cwd(), "data");
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

const DB_PATH = path.join(DATA_DIR, "telemetry.db");
const sqlite = new Database(DB_PATH);

// Configure SQLite for high performance telemetry logging
sqlite.pragma("journal_mode = WAL");
sqlite.pragma("synchronous = NORMAL");
sqlite.pragma("temp_store = MEMORY");

// Initialize tables
sqlite.exec(`
  CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    firmware TEXT NOT NULL DEFAULT 'v2.4.1',
    status TEXT NOT NULL DEFAULT 'LIVE',
    websocket_url TEXT,
    last_seen_ms INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS telemetry_samples (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    timestamp_ms INTEGER NOT NULL,
    v_pv REAL NOT NULL,
    i_pv REAL NOT NULL,
    p_pv REAL NOT NULL,
    v_mp REAL NOT NULL,
    i_ph REAL NOT NULL,
    duty REAL NOT NULL,
    efficiency REAL NOT NULL DEFAULT 96.8,
    source TEXT NOT NULL DEFAULT 'DEMO',
    scenario_code TEXT NOT NULL DEFAULT 'S5',
    FOREIGN KEY(device_id) REFERENCES devices(id)
  );

  CREATE INDEX IF NOT EXISTS idx_telemetry_device_time ON telemetry_samples(device_id, timestamp_ms);
  CREATE INDEX IF NOT EXISTS idx_telemetry_source ON telemetry_samples(source);
  CREATE INDEX IF NOT EXISTS idx_telemetry_scenario ON telemetry_samples(scenario_code);

  CREATE TABLE IF NOT EXISTS controller_commands (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL,
    user_id INTEGER,
    command TEXT NOT NULL,
    payload TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'QUEUED',
    created_at_ms INTEGER NOT NULL,
    acknowledged_at_ms INTEGER,
    FOREIGN KEY(device_id) REFERENCES devices(id)
  );

  CREATE TABLE IF NOT EXISTS scenarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    target TEXT NOT NULL,
    metric TEXT NOT NULL,
    result TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'READY',
    updated_at_ms INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS controller_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id INTEGER NOT NULL UNIQUE,
    sample_rate_hz INTEGER NOT NULL DEFAULT 20,
    isr_period_us INTEGER NOT NULL DEFAULT 10,
    websocket_port INTEGER NOT NULL DEFAULT 81,
    active_scenario TEXT NOT NULL DEFAULT 'S5',
    auto_stop_enabled INTEGER NOT NULL DEFAULT 1,
    updated_at_ms INTEGER NOT NULL,
    FOREIGN KEY(device_id) REFERENCES devices(id)
  );
`);

// Pre-seed default scenarios
const scenarioCount = sqlite.prepare("SELECT COUNT(*) as count FROM scenarios").get() as { count: number };
if (scenarioCount.count === 0) {
  const seedScenarios = sqlite.prepare(`
    INSERT INTO scenarios (code, name, description, target, metric, result, status, updated_at_ms)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const now = Date.now();
  const defaultScenarios = [
    ["S1", "STC baseline", "Nominal irradiance (1000 W/m²) and 25°C reference tracking.", "1000 W/m² · 25°C", "P_pv stable", "216 W", "COMPLETE", now],
    ["S2", "Fast cloud transient", "Step irradiance drop (1000 -> 300 W/m²) and recovery transient response.", "<100 ms settle", "response time", "75 ms", "COMPLETE", now],
    ["S3", "Thermal ramp", "Slow module heating from 25°C to 60°C under steady irradiance.", "25 -> 60°C", "tracking error", "1.8%", "READY", now],
    ["S4", "Low irradiance", "Validation under weak diffuse light conditions (100 W/m²).", "100 W/m²", "η_MPPT", "94.2%", "READY", now],
    ["S5", "EKF vs P&O comparison", "Benchmark comparison demonstrating EKF ripple reduction vs classic P&O.", "EKF <1% ripple", "ripple delta", "<1% vs >5%", "COMPLETE", now],
  ];
  for (const item of defaultScenarios) {
    seedScenarios.run(...item);
  }
}

export type DeviceRow = {
  id: number;
  deviceKey: string;
  name: string;
  firmware: string;
  status: string;
  websocketUrl: string | null;
  lastSeenMs: number | null;
  createdAt: number;
  updatedAt: number;
};

export type TelemetryRow = {
  id: number;
  deviceId: number;
  timestampMs: number;
  vPv: number;
  iPv: number;
  pPv: number;
  vMp: number;
  iPh: number;
  duty: number;
  efficiency: number;
  source: "DEMO" | "MATLAB" | "ESP32";
  scenarioCode: string;
};

export async function ensureDevice(deviceKey = "array-a"): Promise<DeviceRow> {
  const select = sqlite.prepare(`
    SELECT id, device_key as deviceKey, name, firmware, status, websocket_url as websocketUrl, 
           last_seen_ms as lastSeenMs, created_at as createdAt, updated_at as updatedAt
    FROM devices WHERE device_key = ?
  `);
  let device = select.get(deviceKey) as DeviceRow | undefined;

  if (!device) {
    const now = Date.now();
    const insert = sqlite.prepare(`
      INSERT INTO devices (device_key, name, firmware, status, websocket_url, last_seen_ms, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);
    const info = insert.run(deviceKey, "ARRAY A / MPPT NODE", "v2.4.1", "LIVE", "ws://192.168.4.1:81", now, now, now);
    
    // Create default settings
    sqlite.prepare(`
      INSERT OR IGNORE INTO controller_settings (device_id, sample_rate_hz, isr_period_us, websocket_port, active_scenario, auto_stop_enabled, updated_at_ms)
      VALUES (?, 20, 10, 81, 'S5', 1, ?)
    `).run(Number(info.lastInsertRowid), now);

    device = select.get(deviceKey) as DeviceRow;
  }
  return device;
}

export async function insertTelemetry(input: {
  deviceId: number;
  timestampMs: number;
  vPv: number;
  iPv: number;
  pPv: number;
  vMp: number;
  iPh: number;
  duty: number;
  efficiency?: number;
  source?: "DEMO" | "MATLAB" | "ESP32" | string;
  scenarioCode?: string;
}): Promise<TelemetryRow> {
  const insert = sqlite.prepare(`
    INSERT INTO telemetry_samples (device_id, timestamp_ms, v_pv, i_pv, p_pv, v_mp, i_ph, duty, efficiency, source, scenario_code)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);

  const info = insert.run(
    input.deviceId,
    input.timestampMs,
    input.vPv,
    input.iPv,
    input.pPv,
    input.vMp,
    input.iPh,
    input.duty,
    input.efficiency ?? 96.8,
    input.source ?? "MATLAB",
    input.scenarioCode ?? "S5"
  );

  sqlite.prepare("UPDATE devices SET status = 'LIVE', last_seen_ms = ?, updated_at = ? WHERE id = ?")
    .run(input.timestampMs, Date.now(), input.deviceId);

  return {
    id: Number(info.lastInsertRowid),
    deviceId: input.deviceId,
    timestampMs: input.timestampMs,
    vPv: input.vPv,
    iPv: input.iPv,
    pPv: input.pPv,
    vMp: input.vMp,
    iPh: input.iPh,
    duty: input.duty,
    efficiency: input.efficiency ?? 96.8,
    source: (input.source ?? "MATLAB") as any,
    scenarioCode: input.scenarioCode ?? "S5",
  };
}

export async function listTelemetry(deviceId: number, limit = 60, sourceFilter?: string): Promise<TelemetryRow[]> {
  let query = `
    SELECT id, device_id as deviceId, timestamp_ms as timestampMs, v_pv as vPv, i_pv as iPv, 
           p_pv as pPv, v_mp as vMp, i_ph as iPh, duty, efficiency, source, scenario_code as scenarioCode
    FROM telemetry_samples 
    WHERE device_id = ?
  `;
  const params: any[] = [deviceId];

  if (sourceFilter) {
    query += " AND source = ?";
    params.push(sourceFilter);
  }

  query += " ORDER BY timestamp_ms DESC LIMIT ?";
  params.push(limit);

  const rows = sqlite.prepare(query).all(...params) as TelemetryRow[];
  return rows.reverse();
}

export async function countTelemetry(deviceId?: number): Promise<number> {
  if (deviceId) {
    const row = sqlite.prepare("SELECT COUNT(*) as count FROM telemetry_samples WHERE device_id = ?").get(deviceId) as { count: number };
    return row?.count ?? 0;
  }
  const row = sqlite.prepare("SELECT COUNT(*) as count FROM telemetry_samples").get() as { count: number };
  return row?.count ?? 0;
}

export async function getTelemetryStats(deviceId: number) {
  const stats = sqlite.prepare(`
    SELECT 
      COUNT(*) as count,
      MIN(p_pv) as minPower,
      MAX(p_pv) as maxPower,
      AVG(p_pv) as avgPower,
      AVG(efficiency) as avgEfficiency,
      MIN(timestamp_ms) as firstSampleMs,
      MAX(timestamp_ms) as lastSampleMs
    FROM telemetry_samples
    WHERE device_id = ?
  `).get(deviceId) as any;

  return {
    totalLogged: stats?.count ?? 0,
    minPower: stats?.minPower ?? 0,
    maxPower: stats?.maxPower ?? 0,
    avgPower: stats?.avgPower ?? 0,
    avgEfficiency: stats?.avgEfficiency ?? 96.8,
    durationSeconds: stats?.firstSampleMs && stats?.lastSampleMs ? (stats.lastSampleMs - stats.firstSampleMs) / 1000 : 0,
    databaseFile: DB_PATH,
  };
}

export async function exportTelemetryCsv(deviceId: number, limit = 5000): Promise<string> {
  const rows = sqlite.prepare(`
    SELECT timestamp_ms, datetime(timestamp_ms/1000, 'unixepoch') as iso_time, source, scenario_code,
           v_pv, i_pv, p_pv, v_mp, i_ph, duty, efficiency
    FROM telemetry_samples
    WHERE device_id = ?
    ORDER BY timestamp_ms ASC
    LIMIT ?
  `).all(deviceId, limit) as any[];

  const header = "timestamp_ms,iso_time,source,scenario_code,v_pv,i_pv,p_pv,v_mp,i_ph,duty,efficiency\n";
  const lines = rows.map(r => 
    `${r.timestamp_ms},"${r.iso_time}","${r.source}","${r.scenario_code}",${r.v_pv},${r.i_pv},${r.p_pv},${r.v_mp},${r.i_ph},${r.duty},${r.efficiency}`
  );
  return header + lines.join("\n");
}

export async function clearTelemetry(deviceId?: number): Promise<void> {
  if (deviceId) {
    sqlite.prepare("DELETE FROM telemetry_samples WHERE device_id = ?").run(deviceId);
  } else {
    sqlite.prepare("DELETE FROM telemetry_samples").run();
  }
}

export async function listCommands(deviceId: number, limit = 12) {
  return sqlite.prepare(`
    SELECT id, device_id as deviceId, user_id as userId, command, payload, status,
           created_at_ms as createdAtMs, acknowledged_at_ms as acknowledgedAtMs
    FROM controller_commands
    WHERE device_id = ?
    ORDER BY created_at_ms DESC
    LIMIT ?
  `).all(deviceId, limit);
}

export async function createCommand(input: {
  deviceId: number;
  userId?: number;
  command: string;
  payload: string;
  status?: string;
  createdAtMs: number;
}) {
  const info = sqlite.prepare(`
    INSERT INTO controller_commands (device_id, user_id, command, payload, status, created_at_ms)
    VALUES (?, ?, ?, ?, ?, ?)
  `).run(input.deviceId, input.userId ?? null, input.command, input.payload, input.status ?? "QUEUED", input.createdAtMs);

  return sqlite.prepare("SELECT * FROM controller_commands WHERE id = ?").get(info.lastInsertRowid);
}

export async function listScenarios() {
  return sqlite.prepare("SELECT * FROM scenarios ORDER BY code ASC").all();
}

export async function getSettings(deviceId: number) {
  return sqlite.prepare(`
    SELECT id, device_id as deviceId, sample_rate_hz as sampleRateHz, isr_period_us as isrPeriodUs,
           websocket_port as websocketPort, active_scenario as activeScenario, 
           auto_stop_enabled as autoStopEnabled, updated_at_ms as updatedAtMs
    FROM controller_settings
    WHERE device_id = ?
  `).get(deviceId);
}

export async function saveSettings(deviceId: number, input: any) {
  const fields = [];
  const values = [];
  if (input.sampleRateHz !== undefined) { fields.push("sample_rate_hz = ?"); values.push(input.sampleRateHz); }
  if (input.isrPeriodUs !== undefined) { fields.push("isr_period_us = ?"); values.push(input.isrPeriodUs); }
  if (input.websocketPort !== undefined) { fields.push("websocket_port = ?"); values.push(input.websocketPort); }
  if (input.activeScenario !== undefined) { fields.push("active_scenario = ?"); values.push(input.activeScenario); }
  if (input.autoStopEnabled !== undefined) { fields.push("auto_stop_enabled = ?"); values.push(input.autoStopEnabled ? 1 : 0); }
  
  fields.push("updated_at_ms = ?");
  values.push(Date.now());
  values.push(deviceId);

  sqlite.prepare(`UPDATE controller_settings SET ${fields.join(", ")} WHERE device_id = ?`).run(...values);
  return getSettings(deviceId);
}

// User helpers
export async function getUserByOpenId(openId: string) {
  return { id: 1, openId, name: "Admin", role: "admin" };
}

export async function upsertUser(user: any) {
  // No-op for single user local dashboard
}

export async function getDb() {
  return sqlite;
}
