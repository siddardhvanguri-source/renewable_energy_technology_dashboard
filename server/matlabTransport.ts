import type { Express, Request, Response } from "express";
import type { Server as HttpServer } from "node:http";
import { WebSocketServer, WebSocket } from "ws";
import { z } from "zod";
import { clearTelemetry, countTelemetry, ensureDevice, exportTelemetryCsv, getTelemetryStats, insertTelemetry } from "./db";

const matlabFrameSchema = z.object({
  timestamp: z.number().finite().optional(),
  timestampMs: z.number().finite().optional(),
  v_pv: z.number().finite(),
  i_pv: z.number().finite(),
  p_pv: z.number().finite(),
  v_mp: z.number().finite(),
  i_ph: z.number().finite(),
  duty: z.number().min(0).max(1),
  v_out: z.number().finite().optional(),
  t_c: z.number().finite().optional(),
  efficiency: z.number().min(0).max(100).optional(),
  scenarioCode: z.string().max(16).optional(),
});

export type MatlabFrame = z.infer<typeof matlabFrameSchema> & {
  timestampMs: number;
  source: "MATLAB";
};

import fs from "node:fs";
import path from "node:path";

const clients = new Set<WebSocket>();
let latest: MatlabFrame | null = null;
const matlabHistory: MatlabFrame[] = [];
const MAX_MATLAB_HISTORY = 300;

// Auto-seed static baseline from mppt_reference_trace.csv if available
function loadStaticReferenceTrace() {
  try {
    const csvPath = path.resolve(process.cwd(), "matlab", "mppt_reference_trace.csv");
    if (fs.existsSync(csvPath)) {
      const content = fs.readFileSync(csvPath, "utf-8");
      const lines = content.trim().split("\n").slice(1); // skip header
      const step = Math.max(1, Math.floor(lines.length / 60));
      const now = Date.now();
      lines.forEach((line, idx) => {
        if (idx % step === 0 && line.trim()) {
          const parts = line.split(",").map(Number);
          if (parts.length >= 5 && !isNaN(parts[3]) && !isNaN(parts[4])) {
            const timeOffset = parts[0] * 1000;
            const pEkf = parts[3];
            const vPv = parts[4];
            const iPv = vPv > 0 ? pEkf / vPv : 0;
            const frame: MatlabFrame = {
              source: "MATLAB",
              timestampMs: now - (2000 - timeOffset),
              v_pv: Math.round(vPv * 100) / 100,
              i_pv: Math.round(iPv * 1000) / 1000,
              p_pv: Math.round(pEkf * 100) / 100,
              v_mp: 17.5,
              i_ph: 0.58,
              duty: 0.20,
              v_out: 28.5,
              t_c: 25.0,
              efficiency: 99.8,
              scenarioCode: "STATIC_REF",
            };
            matlabHistory.push(frame);
            latest = frame;
          }
        }
      });
      console.log(`[MATLAB Transport] Loaded ${matlabHistory.length} static reference frames from mppt_reference_trace.csv`);
    }
  } catch (err) {
    console.warn("[MATLAB Transport] Could not load static reference trace:", err);
  }
}
loadStaticReferenceTrace();

export const matlabWss = new WebSocketServer({ noServer: true });

matlabWss.on("connection", (socket) => {
  clients.add(socket);

  if (socket.readyState === WebSocket.OPEN) {
    socket.send(
      JSON.stringify({
        type: "connection",
        source: "server",
        timestamp: Date.now(),
        message: "MATLAB telemetry WebSocket connected",
        historyCount: matlabHistory.length,
      })
    );
  }

  if (matlabHistory.length > 0 && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify({ type: "history", source: "MATLAB", history: matlabHistory }));
  }

  if (latest && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(latest));
  }

  socket.on("close", () => clients.delete(socket));
  socket.on("error", () => clients.delete(socket));
});

function broadcast(frame: MatlabFrame) {
  const message = JSON.stringify(frame);
  clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      try {
        client.send(message);
      } catch (err) {
        console.warn("[MATLAB WS] Broadcast error:", err);
      }
    }
  });
}

export function registerMatlabTransport(app: Express, _server?: HttpServer) {
  const expectedToken = process.env.MATLAB_INGEST_TOKEN;

  app.get("/api/health", async (_req, res) => {
    const totalCount = await countTelemetry();
    res.json({
      ok: true,
      matlab: {
        endpoint: "/api/telemetry/simulation",
        websocket: "/ws/matlab",
        clients: clients.size,
        hasTelemetry: Boolean(latest),
        samplesCount: matlabHistory.length,
        persistedTotal: totalCount,
      },
    });
  });

  app.get("/api/telemetry/matlab/latest", (_req, res) => {
    res.json({ ok: true, telemetry: latest });
  });

  app.get("/api/telemetry/matlab/history", (_req, res) => {
    res.json({ ok: true, count: matlabHistory.length, history: matlabHistory, latest });
  });

  app.get("/api/telemetry/stats", async (_req, res) => {
    const device = await ensureDevice("array-a");
    const stats = await getTelemetryStats(device.id);
    res.json({ ok: true, stats });
  });

  app.get("/api/telemetry/export.csv", async (_req, res) => {
    try {
      const device = await ensureDevice("array-a");
      const csv = await exportTelemetryCsv(device.id, 10000);
      res.setHeader("Content-Type", "text/csv");
      res.setHeader("Content-Disposition", `attachment; filename="mppt_telemetry_${Date.now()}.csv"`);
      res.send(csv);
    } catch (error) {
      res.status(500).send("Error exporting telemetry CSV");
    }
  });

  app.post("/api/telemetry/clear", async (_req, res) => {
    matlabHistory.length = 0;
    latest = null;
    const device = await ensureDevice("array-a");
    await clearTelemetry(device.id);
    broadcast({
      source: "MATLAB",
      timestampMs: Date.now(),
      v_pv: 0,
      i_pv: 0,
      p_pv: 0,
      v_mp: 0,
      i_ph: 0,
      duty: 0,
      efficiency: 0,
    });
    res.json({ ok: true, message: "Telemetry database and in-memory history cleared" });
  });

  app.post("/api/telemetry/simulation", async (req: Request, res: Response) => {
    if (expectedToken && req.header("x-matlab-token") !== expectedToken) {
      return res.status(401).json({ ok: false, error: "Invalid MATLAB ingest token" });
    }

    const parsed = matlabFrameSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ ok: false, error: "Invalid MATLAB telemetry", details: parsed.error.flatten() });
    }

    const body = parsed.data;
    const timestampMs = Math.round(body.timestampMs ?? body.timestamp ?? Date.now());
    const frame: MatlabFrame = { ...body, timestampMs, source: "MATLAB" };
    latest = frame;

    matlabHistory.push(frame);
    if (matlabHistory.length > MAX_MATLAB_HISTORY) {
      matlabHistory.shift();
    }

    let devicePersisted = false;
    let savedSample = null;
    try {
      const device = await ensureDevice("array-a");
      savedSample = await insertTelemetry({
        deviceId: device.id,
        timestampMs,
        vPv: body.v_pv,
        iPv: body.i_pv,
        pPv: body.p_pv,
        vMp: body.v_mp,
        iPh: body.i_ph,
        duty: body.duty,
        efficiency: body.efficiency ?? 96.8,
        source: "MATLAB",
        scenarioCode: body.scenarioCode ?? "S5",
      });
      devicePersisted = true;
    } catch (e) {
      console.warn("[Database] Telemetry persist error:", e);
    }

    broadcast(frame);
    return res.json({
      ok: 1,
      clients: clients.size,
      telemetry: frame,
      samplesCount: matlabHistory.length,
      persisted: devicePersisted ? 1 : 0,
      id: savedSample?.id,
    });
  });
}
