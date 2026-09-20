import { CheckCircle2, Cloud, Gauge, Play, ThermometerSun, Zap } from "lucide-react";
import { trpc } from "@/lib/trpc";
import { LiquidGlassCard } from "@/components/visual/LiquidGlassCard";

const fallbackScenarios = [
  { code: "S1", name: "STC baseline", description: "Nominal irradiance and ambient condition reference run.", target: "1000 W/m² · 25°C", metric: "P_pv stable", result: "216 W", status: "COMPLETE" },
  { code: "S2", name: "Fast cloud transient", description: "Step irradiance drop and recovery for transient-response validation.", target: "<100 ms settle", metric: "response time", result: "75 ms", status: "COMPLETE" },
  { code: "S3", name: "Thermal ramp", description: "Slow temperature increase while irradiance remains nominal.", target: "25 → 60°C", metric: "tracking error", result: "1.8%", status: "READY" },
  { code: "S4", name: "Low irradiance", description: "Reduced generation condition used to validate controller stability.", target: "100 W/m²", metric: "η_MPPT", result: "94.2%", status: "READY" },
  { code: "S5", name: "EKF vs P&O comparison", description: "Headline comparison run for steady-state ripple and efficiency.", target: "EKF <1% ripple", metric: "ripple delta", result: "<1% vs >5%", status: "COMPLETE" },
];

export default function Scenarios() {
  const query = trpc.dashboard.scenarios.useQuery();
  const scenarios = query.data?.length ? query.data : fallbackScenarios;
  return <div className="subpage"><div className="subpage-heading"><div><span className="eyebrow">TESTS</span><h1>Scenarios</h1><p>Choose a condition and check the result.</p></div><button className="button primary"><Play size={14} /> run test</button></div><div className="scenario-grid">{scenarios.map((scenario: any, index: number) => <LiquidGlassCard key={scenario.code} className={`scenario-card ${scenario.code === "S5" ? "featured" : ""}`}><div className="scenario-top"><span className="scenario-code">{scenario.code}</span><span className={`scenario-status ${String(scenario.status).toLowerCase()}`}><CheckCircle2 size={13} /> {scenario.status}</span></div><h2>{scenario.name}</h2><p>{scenario.description}</p><div className="scenario-meta"><span><Gauge size={14} /> target<strong>{scenario.target}</strong></span><span><Zap size={14} /> measure<strong>{scenario.metric}</strong></span></div><div className="scenario-result"><small>RESULT</small><strong>{scenario.result}</strong><button className="button small">{index === 4 ? "compare" : "view"}</button></div>{scenario.code === "S2" ? <div className="scenario-icon"><Cloud size={17} /></div> : scenario.code === "S3" ? <div className="scenario-icon"><ThermometerSun size={17} /></div> : null}</LiquidGlassCard>)}</div><LiquidGlassCard className="scenario-note"><div className="note-icon"><CheckCircle2 size={18} /></div><div><strong>Ready</strong><p>Live panel readings can replace the demo values when the ESP32 is connected.</p></div></LiquidGlassCard></div>;
}
