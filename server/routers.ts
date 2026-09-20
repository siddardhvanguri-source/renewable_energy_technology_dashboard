import { z } from "zod";
import { COOKIE_NAME } from "@shared/const";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { protectedProcedure, publicProcedure, router } from "./_core/trpc";
import { createCommand, ensureDevice, getSettings, insertTelemetry, listCommands, listScenarios, listTelemetry, saveSettings } from "./db";

const deviceKeySchema = z.string().min(1).max(64).default("array-a");

function demoFrame(timestampMs = Date.now()) {
  const phase = timestampMs / 1000;
  const vPv = 31.2 + Math.sin(phase * 0.72) * 0.18;
  const iPv = 6.92 + Math.cos(phase * 0.58) * 0.06;
  return {
    timestampMs,
    vPv,
    iPv,
    pPv: vPv * iPv,
    vMp: 30.92 + Math.sin(phase * 0.43) * 0.12,
    iPh: 6.98 + Math.cos(phase * 0.37) * 0.06,
    duty: 0.61 + Math.sin(phase * 0.29) * 0.014,
    efficiency: 96.8 + Math.sin(phase * 0.31) * 0.24,
  };
}

export const appRouter = router({
  system: systemRouter,
  auth: router({
    me: publicProcedure.query((opts) => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return { success: true } as const;
    }),
  }),
  dashboard: router({
    snapshot: publicProcedure.input(z.object({ deviceKey: deviceKeySchema })).query(async ({ input }) => {
      const device = await ensureDevice(input.deviceKey);
      if (!device) {
        const frame = demoFrame();
        return { device: null, settings: null, latest: frame, history: [frame], commands: [], scenarios: [] };
      }
      let history = await listTelemetry(device.id);
      if (history.length === 0) {
        const seedFrames = Array.from({ length: 34 }, (_, index) => demoFrame(Date.now() - (33 - index) * 1000));
        await Promise.all(seedFrames.map((frame) => insertTelemetry({
          deviceId: device.id,
          timestampMs: frame.timestampMs,
          vPv: frame.vPv,
          iPv: frame.iPv,
          pPv: frame.pPv,
          vMp: frame.vMp,
          iPh: frame.iPh,
          duty: frame.duty,
          efficiency: frame.efficiency,
          scenarioCode: "S5",
        })));
        history = await listTelemetry(device.id);
      }
      const [commands, scenarios, settings] = await Promise.all([
        listCommands(device.id),
        listScenarios(),
        getSettings(device.id),
      ]);
      const latest = history[history.length - 1] ?? demoFrame();
      return { device, settings, latest, history, commands, scenarios };
    }),
    ingest: publicProcedure.input(z.object({
      deviceKey: deviceKeySchema,
      timestampMs: z.number().int().positive().optional(),
      v_pv: z.number().finite(),
      i_pv: z.number().finite(),
      p_pv: z.number().finite(),
      v_mp: z.number().finite(),
      i_ph: z.number().finite(),
      duty: z.number().min(0).max(1),
      efficiency: z.number().min(0).max(100).optional(),
      scenarioCode: z.string().max(16).default("S5"),
    })).mutation(async ({ input }) => {
      const device = await ensureDevice(input.deviceKey);
      if (!device) return { accepted: false, reason: "database-unavailable" };
      const saved = await insertTelemetry({
        deviceId: device.id,
        timestampMs: input.timestampMs ?? Date.now(),
        vPv: input.v_pv,
        iPv: input.i_pv,
        pPv: input.p_pv,
        vMp: input.v_mp,
        iPh: input.i_ph,
        duty: input.duty,
        efficiency: input.efficiency ?? 96.8,
        scenarioCode: input.scenarioCode,
      });
      return { accepted: Boolean(saved), sample: saved };
    }),
    command: publicProcedure.input(z.object({ deviceKey: deviceKeySchema, command: z.enum(["stop", "resume", "sync"]) })).mutation(async ({ input, ctx }) => {
      const device = await ensureDevice(input.deviceKey);
      if (!device) return { accepted: false, reason: "database-unavailable" };
      const saved = await createCommand({
        deviceId: device.id,
        userId: ctx.user?.id,
        command: input.command,
        payload: JSON.stringify({ cmd: input.command === "resume" ? "resume" : input.command }),
        status: "QUEUED",
        createdAtMs: Date.now(),
      });
      return { accepted: Boolean(saved), command: saved };
    }),
    scenarios: publicProcedure.query(() => listScenarios()),
    settings: publicProcedure.input(z.object({ deviceKey: deviceKeySchema })).query(async ({ input }) => {
      const device = await ensureDevice(input.deviceKey);
      return device ? getSettings(device.id) : null;
    }),
    updateSettings: protectedProcedure.input(z.object({
      deviceKey: deviceKeySchema,
      sampleRateHz: z.number().int().min(1).max(100),
      isrPeriodUs: z.number().int().min(1).max(1000),
      websocketPort: z.number().int().min(1).max(65535),
      activeScenario: z.string().max(16),
      autoStopEnabled: z.boolean(),
    })).mutation(async ({ input }) => {
      const device = await ensureDevice(input.deviceKey);
      if (!device) return null;
      const { deviceKey: _deviceKey, ...settings } = input;
      return saveSettings(device.id, settings);
    }),
  }),
});

export type AppRouter = typeof appRouter;
