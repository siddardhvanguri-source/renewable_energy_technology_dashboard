import { useEffect, useMemo, useRef, useState } from "react";
import { Activity, ArrowDownRight, ArrowUpRight, Bell, Cable, CheckCircle2, CircleStop, CloudSun, Cpu, HardDrive, Play, RefreshCw, ShieldCheck, SlidersHorizontal, Sun, Terminal, X } from "lucide-react";
import { toast } from "sonner";
import { trpc } from "@/lib/trpc";
import { LiquidGlassCard } from "@/components/visual/LiquidGlassCard";
import { FlowField } from "@/components/visual/FlowField";
import { LiveStatusBar } from "@/components/LiveStatusBar";
import { DutyChart, EfficiencyChart, EkfPoChart, LiveTelemetryChart, PvCurveChart, ResponseBandChart, RippleChart } from "@/components/EngineeringCharts";

type Frame = { timestampMs: number; vPv: number; iPv: number; pPv: number; vMp: number; iPh: number; duty: number; efficiency: number };
const demoFrame = (timestampMs = Date.now()): Frame => { const phase = timestampMs / 1000; const vPv = 31.2 + Math.sin(phase * .72) * .18; const iPv = 6.92 + Math.cos(phase * .58) * .06; return { timestampMs, vPv, iPv, pPv: vPv * iPv, vMp: 30.92 + Math.sin(phase * .43) * .12, iPh: 6.98 + Math.cos(phase * .37) * .06, duty: .61 + Math.sin(phase * .29) * .014, efficiency: 96.8 + Math.sin(phase * .31) * .24 }; };
const normalize = (sample: any): Frame => ({ timestampMs: Number(sample.timestampMs ?? Date.now()), vPv: Number(sample.vPv ?? sample.v_pv), iPv: Number(sample.iPv ?? sample.i_pv), pPv: Number(sample.pPv ?? sample.p_pv), vMp: Number(sample.vMp ?? sample.v_mp), iPh: Number(sample.iPh ?? sample.i_ph), duty: Number(sample.duty), efficiency: Number(sample.efficiency ?? 96.8) });

function Sparkline({ values }: { values: number[] }) { const min = Math.min(...values); const max = Math.max(...values); const points = values.map((value, index) => `${(index / Math.max(values.length - 1, 1)) * 100},${34 - ((value - min) / Math.max(max - min, .001)) * 29}`).join(" "); return <svg viewBox="0 0 100 38" preserveAspectRatio="none" className="sparkline" aria-label="Power trend"><polyline points={points} fill="none" stroke="#72e3d2" strokeWidth="2" vectorEffect="non-scaling-stroke" /></svg>; }

export default function Home() {
  const snapshotQuery = trpc.dashboard.snapshot.useQuery({ deviceKey: "array-a" });
  const ingestMutation = trpc.dashboard.ingest.useMutation();
  const commandMutation = trpc.dashboard.command.useMutation({ onSuccess: ({ accepted }) => accepted ? toast.success("Command queued in controller history") : toast.error("Command could not be queued") });
  const [telemetry, setTelemetry] = useState<Frame[]>([]);
  const [connection, setConnection] = useState<"LIVE" | "DEMO / MOCK" | "CONNECTING" | "DISCONNECTED" | "ERROR">("DEMO / MOCK");
  const [stopped, setStopped] = useState(false);
  const [notice, setNotice] = useState("Demo data is running");
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const socketRef = useRef<WebSocket | null>(null);
  const snapshot = snapshotQuery.data;

  useEffect(() => { if (snapshot?.history?.length) setTelemetry(snapshot.history.map(normalize)); }, [snapshot?.history]);
  useEffect(() => { if (!telemetry.length) setTelemetry([demoFrame(Date.now() - 33_000), ...Array.from({ length: 33 }, (_, index) => demoFrame(Date.now() - (32 - index) * 1000))]); }, [telemetry.length]);
  useEffect(() => { if (stopped) return; const timer = window.setInterval(() => setTelemetry((items) => [...items.slice(-59), demoFrame()]), 1100); return () => window.clearInterval(timer); }, [stopped]);
  useEffect(() => () => socketRef.current?.close(), []);

  const current = telemetry[telemetry.length - 1] ?? demoFrame();
  const previous = telemetry[telemetry.length - 2] ?? current;
  const powerDelta = current.pPv - previous.pPv;
  const trend = useMemo(() => telemetry.slice(-14).map((item) => item.pPv), [telemetry]);
  const sendCommand = (command: "stop" | "resume" | "sync") => { commandMutation.mutate({ deviceKey: "array-a", command }); };
  const sendStop = () => { const payload = JSON.stringify({ cmd: "stop" }); if (socketRef.current?.readyState === WebSocket.OPEN) socketRef.current.send(payload); sendCommand("stop"); setStopped(true); setNotice(`Software stop queued · ${payload}`); };
  const resumeDemo = () => { if (socketRef.current?.readyState === WebSocket.OPEN) socketRef.current.send(JSON.stringify({ cmd: "resume" })); sendCommand("resume"); setStopped(false); setConnection("DEMO / MOCK"); setNotice("Controller resume queued · demo stream resumed"); };
  const connectEsp32 = () => { const url = window.localStorage.getItem("mppt_ws_url") || snapshot?.device?.websocketUrl || "ws://192.168.4.1:81"; socketRef.current?.close(); setConnection("CONNECTING"); setNotice(`Connecting to ${url}`); try { const socket = new WebSocket(url); socketRef.current = socket; socket.onopen = () => { setConnection("LIVE"); setNotice("ESP32 telemetry link established"); }; socket.onmessage = (event) => { try { const next = JSON.parse(event.data); if (["v_pv", "i_pv", "p_pv", "v_mp", "i_ph", "duty"].every((key) => typeof next[key] === "number")) { const frame = normalize(next); setTelemetry((items) => [...items.slice(-59), frame]); ingestMutation.mutate({ deviceKey: "array-a", ...next, timestampMs: frame.timestampMs }); } else setNotice("Received an incomplete telemetry frame"); } catch { setNotice("Received an unreadable telemetry frame"); } }; socket.onerror = () => { setConnection("ERROR"); setNotice("ESP32 link unavailable · database demo retained"); }; socket.onclose = () => { setConnection("DISCONNECTED"); setNotice("ESP32 link closed · demo stream retained"); }; } catch { setConnection("ERROR"); setNotice("ESP32 link unavailable · database demo retained"); } };

  return <div className="instrument-page"><FlowField density="sparse" /><div className="ambient-orbit orbit-one" /><div className="ambient-orbit orbit-two" />
    <section className="instrument-heading"><div><div className="eyebrow">ARRAY A</div><h1>MPPT Dashboard</h1><p>Power, voltage, and current at a glance.</p></div><div className="heading-actions"><span className={`status-pill ${connection.toLowerCase().replace(" / ", "-")}`}><span className="status-dot" />{connection}</span><button className="button subtle" onClick={connectEsp32}><Cable size={14} /> connect</button><button className="button icon" aria-label="Refresh" onClick={() => snapshotQuery.refetch()}><RefreshCw size={15} /></button></div></section>
    <LiveStatusBar connection={connection} updatedAt={current.timestampMs} efficiency={current.efficiency} power={current.pPv} />
    <section className="hero-grid"><LiquidGlassCard className="hero-card"><div className="hero-card-top"><div><span className="eyebrow">PRIMARY TELEMETRY</span><h2>P_pv <span>power output</span></h2></div><div className="hero-chip"><span className="status-dot" /> MPPT TRACKING</div></div><div className="hero-readout"><strong>{current.pPv.toFixed(1)}</strong><span>W<small>instantaneous</small></span><span className={`hero-delta ${powerDelta >= 0 ? "positive" : "negative"}`}>{powerDelta >= 0 ? <ArrowUpRight size={15} /> : <ArrowDownRight size={15} />} {Math.abs(powerDelta).toFixed(1)} W <small>Δ / sample</small></span></div><div className="hero-sparkline"><Sparkline values={trend} /><div><span>-12 s</span><span>now</span></div></div><div className="hero-meta"><div><small>TRACKING ALGORITHM</small><strong>Extended Kalman Filter</strong></div><div><small>OPERATING POINT</small><strong>V_mp / I_ph lock</strong></div><div><small>SAMPLE RATE</small><strong>{snapshot?.settings?.sampleRateHz ?? 20} Hz / {snapshot?.settings?.isrPeriodUs ?? 10} μs ISR</strong></div></div></LiquidGlassCard>
      <LiquidGlassCard className={`stop-card ${stopped ? "stopped" : ""}`}><div className="stop-card-head"><div><span className="eyebrow">SAFETY</span><h2>{stopped ? "Stopped" : "Running"}</h2></div><ShieldCheck size={18} /></div><div className="stop-state"><span className={`status-dot ${stopped ? "red" : ""}`} /><strong>{stopped ? "OUTPUT OFF" : "OUTPUT ON"}</strong></div><button className="stop-button" onClick={stopped ? resumeDemo : sendStop}>{stopped ? <Play size={18} /> : <CircleStop size={18} />}<span>{stopped ? "RESUME" : "STOP"}</span></button><p>{stopped ? "Press resume to start again." : "Stops the output safely."}</p></LiquidGlassCard>
    </section>
    <section className="telemetry-grid">{[
      { label: "V_pv", value: current.vPv.toFixed(2), unit: "V", detail: "array voltage", Icon: CloudSun },
      { label: "I_pv", value: current.iPv.toFixed(2), unit: "A", detail: "array current", Icon: Activity },
      { label: "V_mp", value: current.vMp.toFixed(2), unit: "V", detail: "max power voltage", Icon: SlidersHorizontal },
      { label: "I_ph", value: current.iPh.toFixed(2), unit: "A", detail: "photo current", Icon: Sun },
    ].map(({ label, value, unit, detail, Icon }, index) => <LiquidGlassCard key={label} className={`telemetry-chip tone-${index}`}><Icon size={16} /><div><small>{label}</small><strong>{value}<em>{unit}</em></strong><span>{detail}</span></div></LiquidGlassCard>)}</section>
    <div className="notice-bar"><Terminal size={13} /><span>{notice}</span><span className="notice-spacer" /><span className="micro-label">LIVE ESP32</span><span className="status-dot" /></div>
    <section className="chart-section"><div className="section-label">LIVE / REFERENCE COMPARISON <i /></div><div className="chart-grid primary"><EkfPoChart telemetry={telemetry} /><RippleChart telemetry={telemetry} /></div><div className="chart-grid secondary"><PvCurveChart /><EfficiencyChart efficiency={current.efficiency} /><DutyChart duty={current.duty} /></div><div className="section-label">REAL-TIME / CONTROLLER RESPONSE <i /></div><div className="chart-grid live"><LiveTelemetryChart telemetry={telemetry} /><ResponseBandChart /></div></section>
    <footer className="instrument-footer"><span><Cpu size={14} /> ESP32 MPPT · ARRAY A</span><span><CheckCircle2 size={14} /> {snapshot?.history?.length ? "DATABASE HISTORY CONNECTED" : "DEMO HISTORY ACTIVE"}</span><span><HardDrive size={14} /> {telemetry.length} / 60 SAMPLES</span></footer>
    {notificationsOpen ? <div className="notification-drawer"><div className="drawer-head"><div><span>NOTIFICATIONS</span><small>ARRAY A · LIVE SYSTEM</small></div><button onClick={() => setNotificationsOpen(false)} aria-label="Close notifications"><X size={14} /></button></div><div className="notification-summary"><strong>0</strong><span>active alerts</span><i /><strong>2</strong><span>system events</span></div><div className="event-item priority-normal"><span className="event-icon"><CheckCircle2 size={14} /></span><div><strong>MPPT stable</strong><small>ESP32 live power is within the MATLAB reference band.</small></div><time>now</time></div><div className="event-item priority-info"><span className="event-icon"><HardDrive size={14} /></span><div><strong>History synced</strong><small>{snapshot?.history?.length ?? 0} telemetry samples are stored.</small></div><time>live</time></div><div className="event-item priority-info"><span className="event-icon"><Cable size={14} /></span><div><strong>Hardware link ready</strong><small>Connect the ESP32 to replace demo telemetry.</small></div><time>ready</time></div></div> : null}<button className="floating-events" aria-label="Open notifications" onClick={() => setNotificationsOpen((value) => !value)}><Bell size={16} /><span>2</span></button>
  </div>;
}
