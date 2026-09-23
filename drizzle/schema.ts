import {
  bigint,
  boolean,
  double,
  index,
  int,
  mysqlEnum,
  mysqlTable,
  text,
  timestamp,
  varchar,
} from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export const devices = mysqlTable(
  "devices",
  {
    id: int("id").autoincrement().primaryKey(),
    deviceKey: varchar("deviceKey", { length: 64 }).notNull().unique(),
    name: varchar("name", { length: 128 }).notNull(),
    firmware: varchar("firmware", { length: 64 }).notNull().default("unknown"),
    status: mysqlEnum("status", ["LIVE", "DEMO", "OFFLINE"]).notNull().default("DEMO"),
    websocketUrl: varchar("websocketUrl", { length: 255 }),
    lastSeenMs: bigint("lastSeenMs", { mode: "number" }),
    createdAt: timestamp("createdAt").defaultNow().notNull(),
    updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  },
  (table) => [index("devices_status_idx").on(table.status)],
);

export const telemetrySamples = mysqlTable(
  "telemetrySamples",
  {
    id: bigint("id", { mode: "number" }).autoincrement().primaryKey(),
    deviceId: int("deviceId").notNull(),
    timestampMs: bigint("timestampMs", { mode: "number" }).notNull(),
    vPv: double("vPv").notNull(),
    iPv: double("iPv").notNull(),
    pPv: double("pPv").notNull(),
    vMp: double("vMp").notNull(),
    iPh: double("iPh").notNull(),
    duty: double("duty").notNull(),
    efficiency: double("efficiency").notNull().default(96.8),
    source: mysqlEnum("source", ["DEMO", "MATLAB", "ESP32"]).notNull().default("DEMO"),
    scenarioCode: varchar("scenarioCode", { length: 16 }).notNull().default("S5"),
  },
  (table) => [
    index("telemetry_device_time_idx").on(table.deviceId, table.timestampMs),
    index("telemetry_scenario_idx").on(table.scenarioCode),
  ],
);

export const controllerCommands = mysqlTable(
  "controllerCommands",
  {
    id: bigint("id", { mode: "number" }).autoincrement().primaryKey(),
    deviceId: int("deviceId").notNull(),
    userId: int("userId"),
    command: mysqlEnum("command", ["stop", "resume", "sync"]).notNull(),
    payload: text("payload").notNull(),
    status: mysqlEnum("status", ["QUEUED", "SENT", "ACKNOWLEDGED", "FAILED"]).notNull().default("QUEUED"),
    createdAtMs: bigint("createdAtMs", { mode: "number" }).notNull(),
    acknowledgedAtMs: bigint("acknowledgedAtMs", { mode: "number" }),
  },
  (table) => [index("commands_device_time_idx").on(table.deviceId, table.createdAtMs)],
);

export const scenarios = mysqlTable("scenarios", {
  id: int("id").autoincrement().primaryKey(),
  code: varchar("code", { length: 16 }).notNull().unique(),
  name: varchar("name", { length: 128 }).notNull(),
  description: text("description").notNull(),
  target: varchar("target", { length: 128 }).notNull(),
  metric: varchar("metric", { length: 64 }).notNull(),
  result: varchar("result", { length: 64 }).notNull(),
  status: mysqlEnum("status", ["READY", "RUNNING", "COMPLETE"]).notNull().default("READY"),
  updatedAtMs: bigint("updatedAtMs", { mode: "number" }).notNull(),
});

export const controllerSettings = mysqlTable("controllerSettings", {
  id: int("id").autoincrement().primaryKey(),
  deviceId: int("deviceId").notNull().unique(),
  sampleRateHz: int("sampleRateHz").notNull().default(20),
  isrPeriodUs: int("isrPeriodUs").notNull().default(10),
  websocketPort: int("websocketPort").notNull().default(81),
  activeScenario: varchar("activeScenario", { length: 16 }).notNull().default("S5"),
  autoStopEnabled: boolean("autoStopEnabled").notNull().default(true),
  updatedAtMs: bigint("updatedAtMs", { mode: "number" }).notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
export type Device = typeof devices.$inferSelect;
export type TelemetrySample = typeof telemetrySamples.$inferSelect;
export type Scenario = typeof scenarios.$inferSelect;
export type ControllerSetting = typeof controllerSettings.$inferSelect;
