import { Activity, AlertTriangle, CheckCircle2, Clock3, Gauge, Wifi, WifiOff } from "lucide-react";

type LiveStatusBarProps = {
  connection: string;
  updatedAt: number;
  efficiency?: number;
  power: number;
};

export function LiveStatusBar({ connection, updatedAt, efficiency, power }: LiveStatusBarProps) {
  const isLive = connection === "LIVE" || connection === "MATLAB LIVE";
  const isOffline = connection === "DISCONNECTED" || connection === "ERROR";
  const age = Math.max(0, Math.round((Date.now() - updatedAt) / 1000));
  const hasEff = typeof efficiency === "number" && !isNaN(efficiency) && efficiency > 0;
  const alert = isOffline ? "Connection lost" : hasEff && efficiency < 95 ? "Low efficiency" : null;
  const mode =
    connection === "MATLAB LIVE"
      ? "MATLAB LIVE"
      : isLive
      ? "LIVE"
      : isOffline
      ? "OFFLINE"
      : connection === "CONNECTING"
      ? "WAITING"
      : connection === "MATLAB SIMULATION"
      ? "MATLAB"
      : "DEMO";
  return (
    <section className={`live-status-bar ${isOffline ? "offline" : ""}`} aria-label="Live system status">
      <div className="live-status-item status-mode">
        <span className="status-icon">{isOffline ? <WifiOff size={16} /> : <Wifi size={16} />}</span>
        <div>
          <small>MODE</small>
          <strong>{mode}</strong>
        </div>
      </div>
      <div className="live-status-item">
        <Clock3 size={16} />
        <div>
          <small>LAST UPDATE</small>
          <strong>{age < 2 ? "Just now" : `${age}s ago`}</strong>
        </div>
      </div>
      <div className="live-status-item">
        <Gauge size={16} />
        <div>
          <small>EFFICIENCY</small>
          <strong>{hasEff ? `${efficiency!.toFixed(1)}%` : "N/A"}</strong>
        </div>
      </div>
      <div className="live-status-item">
        <Activity size={16} />
        <div>
          <small>POWER</small>
          <strong>{power.toFixed(1)} W</strong>
        </div>
      </div>
      <div className={`live-alert ${alert ? "warning" : "ok"}`}>
        {alert ? <AlertTriangle size={15} /> : <CheckCircle2 size={15} />}
        <span>{alert ?? "All systems normal"}</span>
      </div>
    </section>
  );
}
