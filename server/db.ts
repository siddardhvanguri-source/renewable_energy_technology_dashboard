import { and, desc, eq } from "drizzle-orm";
import { drizzle } from "drizzle-orm/mysql2";
import {
  controllerCommands,
  controllerSettings,
  devices,
  InsertUser,
  scenarios,
  telemetrySamples,
  users,
} from "../drizzle/schema";
import { ENV } from "./_core/env";

let _db: ReturnType<typeof drizzle> | null = null;

export async function getDb() {
  if (!_db && process.env.DATABASE_URL) {
    try {
      _db = drizzle(process.env.DATABASE_URL);
    } catch (error) {
      console.warn("[Database] Failed to connect:", error);
      _db = null;
    }
  }
  return _db;
}

export async function upsertUser(user: InsertUser): Promise<void> {
  if (!user.openId) throw new Error("User openId is required for upsert");
  const db = await getDb();
  if (!db) return;
  const values: InsertUser = { openId: user.openId };
  const updateSet: Record<string, unknown> = {};
  for (const field of ["name", "email", "loginMethod"] as const) {
    if (user[field] !== undefined) {
      values[field] = user[field] ?? null;
      updateSet[field] = user[field] ?? null;
    }
  }
  values.lastSignedIn = user.lastSignedIn ?? new Date();
  updateSet.lastSignedIn = values.lastSignedIn;
  if (user.role !== undefined || user.openId === ENV.ownerOpenId) {
    values.role = user.role ?? "admin";
    updateSet.role = values.role;
  }
  await db.insert(users).values(values).onDuplicateKeyUpdate({ set: updateSet });
}

export async function getUserByOpenId(openId: string) {
  const db = await getDb();
  if (!db) return undefined;
  const result = await db.select().from(users).where(eq(users.openId, openId)).limit(1);
  return result[0];
}

export async function ensureDevice(deviceKey = "array-a") {
  const db = await getDb();
  if (!db) return undefined;
  const existing = await db.select().from(devices).where(eq(devices.deviceKey, deviceKey)).limit(1);
  if (existing[0]) return existing[0];
  await db.insert(devices).values({
    deviceKey,
    name: "ARRAY A / MPPT NODE",
    firmware: "v2.4.1",
    status: "DEMO",
    websocketUrl: "ws://192.168.4.1:81",
    lastSeenMs: Date.now(),
  });
  const created = await db.select().from(devices).where(eq(devices.deviceKey, deviceKey)).limit(1);
  if (created[0]) {
    await db.insert(controllerSettings).values({ deviceId: created[0].id, updatedAtMs: Date.now() }).onDuplicateKeyUpdate({ set: { updatedAtMs: Date.now() } });
  }
  return created[0];
}

export async function listTelemetry(deviceId: number, limit = 60) {
  const db = await getDb();
  if (!db) return [];
  const rows = await db.select().from(telemetrySamples).where(eq(telemetrySamples.deviceId, deviceId)).orderBy(desc(telemetrySamples.timestampMs)).limit(limit);
  return rows.reverse();
}

export async function insertTelemetry(input: Omit<typeof telemetrySamples.$inferInsert, "id">) {
  const db = await getDb();
  if (!db) return undefined;
  await db.insert(telemetrySamples).values(input);
  await db.update(devices).set({ status: "LIVE", lastSeenMs: input.timestampMs }).where(eq(devices.id, input.deviceId));
  const latest = await db.select().from(telemetrySamples).where(and(eq(telemetrySamples.deviceId, input.deviceId), eq(telemetrySamples.timestampMs, input.timestampMs))).orderBy(desc(telemetrySamples.id)).limit(1);
  return latest[0];
}

export async function listCommands(deviceId: number, limit = 12) {
  const db = await getDb();
  if (!db) return [];
  return db.select().from(controllerCommands).where(eq(controllerCommands.deviceId, deviceId)).orderBy(desc(controllerCommands.createdAtMs)).limit(limit);
}

export async function createCommand(input: typeof controllerCommands.$inferInsert) {
  const db = await getDb();
  if (!db) return undefined;
  await db.insert(controllerCommands).values(input);
  const rows = await db.select().from(controllerCommands).where(eq(controllerCommands.deviceId, input.deviceId)).orderBy(desc(controllerCommands.id)).limit(1);
  return rows[0];
}

export async function listScenarios() {
  const db = await getDb();
  if (!db) return [];
  const existing = await db.select().from(scenarios).orderBy(scenarios.code);
  if (existing.length > 0) return existing;
  const now = Date.now();
  await db.insert(scenarios).values([
    { code: "S1", name: "STC baseline", description: "Nominal irradiance and ambient condition reference run.", target: "1000 W/m² · 25°C", metric: "P_pv stable", result: "216 W", status: "COMPLETE", updatedAtMs: now },
    { code: "S2", name: "Fast cloud transient", description: "Step irradiance drop and recovery for transient-response validation.", target: "<100 ms settle", metric: "response time", result: "75 ms", status: "COMPLETE", updatedAtMs: now },
    { code: "S3", name: "Thermal ramp", description: "Slow temperature increase while irradiance remains nominal.", target: "25 → 60°C", metric: "tracking error", result: "1.8%", status: "READY", updatedAtMs: now },
    { code: "S4", name: "Low irradiance", description: "Reduced generation condition used to validate controller stability.", target: "100 W/m²", metric: "η_MPPT", result: "94.2%", status: "READY", updatedAtMs: now },
    { code: "S5", name: "EKF vs P&O comparison", description: "Headline comparison run for steady-state ripple and efficiency.", target: "EKF <1% ripple", metric: "ripple delta", result: "<1% vs >5%", status: "COMPLETE", updatedAtMs: now },
  ]);
  return db.select().from(scenarios).orderBy(scenarios.code);
}

export async function getSettings(deviceId: number) {
  const db = await getDb();
  if (!db) return undefined;
  const rows = await db.select().from(controllerSettings).where(eq(controllerSettings.deviceId, deviceId)).limit(1);
  return rows[0];
}

export async function saveSettings(deviceId: number, input: Partial<typeof controllerSettings.$inferInsert>) {
  const db = await getDb();
  if (!db) return undefined;
  await db.update(controllerSettings).set({ ...input, updatedAtMs: Date.now() }).where(eq(controllerSettings.deviceId, deviceId));
  return getSettings(deviceId);
}
