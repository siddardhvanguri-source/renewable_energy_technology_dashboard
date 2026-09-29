/**
 * React hook for the MATLAB telemetry WebSocket connection.
 *
 * Connects to /ws/matlab, normalizes incoming frames, manages
 * reconnection, and exposes connection + stale state.
 */

import { useEffect, useRef, useState, useCallback } from "react";
import { normalize, STALE_TIMEOUT_MS, type Frame } from "./telemetry";

export type MatlabWsState = "CONNECTED" | "CONNECTING" | "DISCONNECTED";

export interface UseMatlabSocketReturn {
  /** Accumulated MATLAB telemetry frames (max 60). */
  frames: Frame[];
  /** Total MATLAB frames received this session. */
  sampleCount: number;
  /** WebSocket connection state. */
  wsState: MatlabWsState;
  /** Whether the last MATLAB frame is older than STALE_TIMEOUT_MS. */
  isStale: boolean;
  /** Timestamp of the last received MATLAB frame. */
  lastFrameMs: number;
}

/**
 * Hook that manages the `/ws/matlab` WebSocket lifecycle.
 *
 * - Auto-connects on mount.
 * - Processes `{ type: "history" }` and individual MATLAB frames.
 * - Reconnects on disconnect (4 s backoff).
 * - Detects stale data (no frame for 10 s).
 */
export function useMatlabSocket(): UseMatlabSocketReturn {
  const [frames, setFrames] = useState<Frame[]>([]);
  const [sampleCount, setSampleCount] = useState(0);
  const [wsState, setWsState] = useState<MatlabWsState>("DISCONNECTED");
  const [isStale, setIsStale] = useState(false);
  const lastFrameMsRef = useRef(0);
  const [lastFrameMs, setLastFrameMs] = useState(0);

  // Stale detection: check every 2 s if last frame is older than threshold
  useEffect(() => {
    const timer = window.setInterval(() => {
      if (lastFrameMsRef.current > 0 && Date.now() - lastFrameMsRef.current > STALE_TIMEOUT_MS) {
        setIsStale(true);
      }
    }, 2000);
    return () => window.clearInterval(timer);
  }, []);

  // WebSocket lifecycle
  useEffect(() => {
    let closed = false;
    let reconnectTimer: ReturnType<typeof setTimeout> | undefined;
    let socket: WebSocket | null = null;

    const connect = () => {
      if (closed) return;
      const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
      const url = `${protocol}//${window.location.host}/ws/matlab`;
      console.log("[MATLAB WS] Connecting to", url);
      setWsState("CONNECTING");

      try {
        socket = new WebSocket(url);

        socket.onopen = () => {
          console.log("[MATLAB WS] Connected");
          setWsState("CONNECTED");
        };

        socket.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);

            // Connection envelope — ignore
            if (msg.type === "connection") {
              console.log("[MATLAB WS] Server handshake:", msg.message, "history:", msg.historyCount);
              return;
            }

            // History batch replay
            if (msg.type === "history" && Array.isArray(msg.history)) {
              const batch = msg.history.map(normalize);
              console.log(`[MATLAB WS] History replay: ${batch.length} frames`);
              setFrames(batch.slice(-60));
              setSampleCount((prev) => prev + batch.length);
              if (batch.length > 0) {
                const ts = Date.now();
                lastFrameMsRef.current = ts;
                setLastFrameMs(ts);
                setIsStale(false);
              }
              return;
            }

            // Individual MATLAB frame
            if (msg.source === "MATLAB" && typeof msg.p_pv === "number") {
              const frame = normalize(msg);
              console.log(`[MATLAB WS] Frame: P=${frame.pPv.toFixed(2)}W V=${frame.vPv.toFixed(2)}V D=${(frame.duty * 100).toFixed(1)}%`);
              setFrames((prev) => [...prev.slice(-59), frame]);
              setSampleCount((prev) => prev + 1);
              const ts = Date.now();
              lastFrameMsRef.current = ts;
              setLastFrameMs(ts);
              setIsStale(false);
              return;
            }

            // Unknown message — log for debugging
            console.log("[MATLAB WS] Unhandled message type:", msg.type ?? "none", Object.keys(msg));
          } catch (err) {
            console.warn("[MATLAB WS] Parse error:", err);
          }
        };

        socket.onclose = () => {
          console.log("[MATLAB WS] Disconnected, reconnecting in 4s...");
          setWsState("DISCONNECTED");
          if (!closed) reconnectTimer = setTimeout(connect, 4000);
        };

        socket.onerror = (err) => {
          console.warn("[MATLAB WS] Error:", err);
        };
      } catch (err) {
        console.warn("[MATLAB WS] Connection failed:", err);
        if (!closed) reconnectTimer = setTimeout(connect, 4000);
      }
    };

    connect();

    return () => {
      closed = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      socket?.close();
    };
  }, []);

  return { frames, sampleCount, wsState, isStale, lastFrameMs };
}
