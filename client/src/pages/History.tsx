import { useMemo, useState } from "react";
import { CalendarDays, Database, Download, Filter, History as HistoryIcon, RefreshCw, Search, SlidersHorizontal, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { trpc } from "@/lib/trpc";
import { LiquidGlassCard } from "@/components/visual/LiquidGlassCard";
import { LiveTelemetryChart } from "@/components/EngineeringCharts";

export default function History() {
  const snapshot = trpc.dashboard.snapshot.useQuery({ deviceKey: "array-a" });
  const [range, setRange] = useState("60 samples");
  const [searchQuery, setSearchQuery] = useState("");
  const [sourceFilter, setSourceFilter] = useState<"ALL" | "MATLAB" | "ESP32" | "DEMO">("ALL");

  const rawHistory = (snapshot.data?.history ?? []) as Array<{
    timestampMs: number;
    vPv: number;
    iPv: number;
    pPv: number;
    vMp: number;
    iPh: number;
    duty: number;
    efficiency: number;
    source?: string;
    scenarioCode?: string;
  }>;

  const filteredHistory = useMemo(() => {
    return rawHistory.filter((item) => {
      const matchSource = sourceFilter === "ALL" || (item.source ?? "MATLAB") === sourceFilter;
      const matchQuery =
        !searchQuery ||
        (item.scenarioCode && item.scenarioCode.toLowerCase().includes(searchQuery.toLowerCase())) ||
        (item.source && item.source.toLowerCase().includes(searchQuery.toLowerCase())) ||
        new Date(item.timestampMs).toLocaleTimeString().includes(searchQuery);
      return matchSource && matchQuery;
    });
  }, [rawHistory, sourceFilter, searchQuery]);

  const latest = rawHistory[rawHistory.length - 1];
  const averagePower = useMemo(
    () => (rawHistory.length ? rawHistory.reduce((sum, item) => sum + item.pPv, 0) / rawHistory.length : 0),
    [rawHistory]
  );

  const handleExportCsv = () => {
    window.open("/api/telemetry/export.csv", "_blank");
    toast.success("Downloading telemetry CSV from SQLite database...");
  };

  const handleClear = async () => {
    if (!confirm("Are you sure you want to clear all logged telemetry in SQLite?")) return;
    try {
      const res = await fetch("/api/telemetry/clear", { method: "POST" });
      if (res.ok) {
        toast.success("Telemetry log cleared");
        snapshot.refetch();
      }
    } catch {
      toast.error("Failed to clear database");
    }
  };

  return (
    <div className="subpage">
      <div className="subpage-heading">
        <div>
          <div className="eyebrow">PERSISTENT STORAGE · SQLITE ENGINE</div>
          <h1>Telemetry History & Logging</h1>
          <p>Continuous value logging from MATLAB Simulink simulations and ESP32 hardware runs.</p>
        </div>
        <div className="subpage-actions">
          <button className="button subtle" onClick={handleExportCsv}>
            <Download size={14} /> Export CSV
          </button>
          <button className="button subtle" onClick={handleClear} title="Clear logged database">
            <Trash2 size={14} /> Clear Log
          </button>
          <button className="button icon" onClick={() => snapshot.refetch()} title="Refresh data">
            <RefreshCw size={15} />
          </button>
        </div>
      </div>

      <div className="metric-strip">
        <LiquidGlassCard>
          <small>PERSISTED SAMPLES</small>
          <strong>
            {rawHistory.length}
            <em> samples</em>
          </strong>
          <span>
            <Database size={13} /> SQLite Engine active
          </span>
        </LiquidGlassCard>
        <LiquidGlassCard>
          <small>MEAN P_pv</small>
          <strong>
            {averagePower.toFixed(2)}
            <em> W</em>
          </strong>
          <span>recorded average</span>
        </LiquidGlassCard>
        <LiquidGlassCard>
          <small>LATEST EFFICIENCY</small>
          <strong>
            {(latest?.efficiency ?? 96.8).toFixed(1)}
            <em> %</em>
          </strong>
          <span>η_MPPT</span>
        </LiquidGlassCard>
        <LiquidGlassCard>
          <small>ACTIVE SCENARIO</small>
          <strong>{latest?.scenarioCode ?? "S5"}</strong>
          <span>{latest?.source ?? "MATLAB"} stream</span>
        </LiquidGlassCard>
      </div>

      <LiquidGlassCard className="history-chart">
        <div className="panel-heading">
          <div>
            <span className="eyebrow">PERSISTED TIME-SERIES</span>
            <h2>Stored Telemetry Stream</h2>
          </div>
          <div className="segmented">
            {(["ALL", "MATLAB", "ESP32", "DEMO"] as const).map((src) => (
              <button
                key={src}
                className={sourceFilter === src ? "selected" : ""}
                onClick={() => setSourceFilter(src)}
              >
                {src}
              </button>
            ))}
          </div>
        </div>
        <LiveTelemetryChart
          telemetry={
            filteredHistory.length
              ? filteredHistory.map((item) => ({
                  timestampMs: item.timestampMs,
                  vPv: item.vPv,
                  iPv: item.iPv,
                  pPv: item.pPv,
                  vMp: item.vMp,
                  iPh: item.iPh,
                  duty: item.duty,
                  efficiency: item.efficiency,
                }))
              : []
          }
        />
      </LiquidGlassCard>

      <LiquidGlassCard className="data-panel">
        <div className="panel-heading">
          <div>
            <span className="eyebrow">DATABASE LOG TABLE</span>
            <h2>Recent Logged Frames ({filteredHistory.length})</h2>
          </div>
          <div className="search-box">
            <Search size={14} />
            <input
              placeholder="Search by scenario, source, or time..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              aria-label="Filter telemetry samples"
            />
          </div>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Timestamp</th>
                <th>Source</th>
                <th>Scenario</th>
                <th>V_pv</th>
                <th>I_pv</th>
                <th>P_pv</th>
                <th>V_mp</th>
                <th>I_ph</th>
                <th>Duty</th>
                <th>η_MPPT</th>
              </tr>
            </thead>
            <tbody>
              {filteredHistory
                .slice()
                .reverse()
                .slice(0, 20)
                .map((item, idx) => (
                  <tr key={`${item.timestampMs}-${idx}`}>
                    <td>
                      <CalendarDays size={13} />
                      {new Date(item.timestampMs).toLocaleTimeString()}
                    </td>
                    <td>
                      <span className={`table-tag ${item.source === "MATLAB" ? "blue" : item.source === "ESP32" ? "cyan" : ""}`}>
                        {item.source ?? "MATLAB"}
                      </span>
                    </td>
                    <td>
                      <span className="table-tag">{item.scenarioCode ?? "S5"}</span>
                    </td>
                    <td>{item.vPv.toFixed(2)} V</td>
                    <td>{item.iPv.toFixed(3)} A</td>
                    <td className="highlight">{item.pPv.toFixed(2)} W</td>
                    <td>{item.vMp.toFixed(2)} V</td>
                    <td>{item.iPh.toFixed(3)} A</td>
                    <td>{(item.duty * 100).toFixed(1)}%</td>
                    <td>{item.efficiency.toFixed(1)}%</td>
                  </tr>
                ))}
              {!filteredHistory.length ? (
                <tr>
                  <td colSpan={10} className="table-empty">
                    No telemetry records found. Run send_simulation_to_web in MATLAB or connect an ESP32.
                  </td>
                </tr>
              ) : null}
            </tbody>
          </table>
        </div>
        <div className="panel-foot">
          <span>
            <SlidersHorizontal size={13} /> Stored in data/telemetry.db (SQLite)
          </span>
          <span>{filteredHistory.length} samples shown · Auto-indexed</span>
        </div>
      </LiquidGlassCard>
    </div>
  );
}
