import type { Express, Request, Response } from "express";
import type { Server as HttpServer } from "node:http";
import { WebSocketServer, WebSocket } from "ws";
import { z } from "zod";
import { ensureDevice, insertTelemetry } from "./db";

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

const clients = new Set<WebSocket>();
let latest: MatlabFrame | null = null;

function broadcast(frame: MatlabFrame) {
  const message = JSON.stringify(frame);
  clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) client.send(message);
  });
}

export function registerMatlabTransport(app: Express, server: HttpServer) {
  const wss = new WebSocketServer({ server, path: "/ws/matlab" });
  const expectedToken = process.env.MATLAB_INGEST_TOKEN;

  app.get("/api/health", (_req, res) => {
    res.json({ ok: true, matlab: { endpoint: "/api/telemetry/simulation", websocket: "/ws/matlab", clients: clients.size, hasTelemetry: Boolean(latest) } });
  });

  app.get("/api/telemetry/matlab/latest", (_req, res) => {
    res.json({ ok: true, telemetry: latest });
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

    const device = await ensureDevice("array-a");
    if (device) {
      await insertTelemetry({
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
    }

    broadcast(frame);
    return res.json({ ok: true, clients: clients.size, telemetry: frame, persisted: Boolean(device) });
  });

  wss.on("connection", (socket) => {
    clients.add(socket);
    socket.send(JSON.stringify({ type: "connection", source: "server", timestamp: Date.now(), message: "MATLAB telemetry WebSocket connected" }));
    if (latest) socket.send(JSON.stringify(latest));
    socket.on("close", () => clients.delete(socket));
    socket.on("error", () => clients.delete(socket));
  });
}
