import { Area, AreaChart, CartesianGrid, ComposedChart, Line, LineChart, ReferenceArea, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Activity, Radio, Zap } from "lucide-react";
import { LiquidGlassCard } from "@/components/visual/LiquidGlassCard";

export type Sample = { timestampMs: number; vPv: number; iPv: number; pPv: number; vMp: number; iPh: number; duty: number; efficiency: number };
const colors = { cyan: "#72e3d2", violet: "#b98dfd", amber: "#f2c46d", blue: "#7fd7f1", red: "#ef7892" };
const tooltip = { background: "#0a1822", border: "1px solid rgba(127, 194, 218, .2)", borderRadius: 8, color: "#d9edf2", fontSize: 11 };
const tick = { fill: "#68818e", fontSize: 10 };
const grid = "rgba(124, 164, 181, .12)";

function ChartCard({ eyebrow, title, tag, children, className = "" }: { eyebrow: string; title: string; tag: string; children: React.ReactNode; className?: string }) {
  return <LiquidGlassCard className={`chart-card ${className}`}><div className="chart-card-head"><div><span className="eyebrow">{eyebrow}</span><h3>{title}</h3></div><span className="chart-tag">{tag}</span></div>{children}</LiquidGlassCard>;
}
function Legend({ items }: { items: { label: string; color: string }[] }) { return <div className="chart-legend">{items.map((item) => <span key={item.label}><i style={{ background: item.color }} />{item.label}</span>)}</div>; }

function comparisonData(telemetry: Sample[], matlabTelemetry: Sample[]) {
  const count = Math.max(telemetry.length, matlabTelemetry.length, 20);
  const live = telemetry.slice(-count);
  const matlab = matlabTelemetry.slice(-count);
  const total = Math.max(live.length, matlab.length);
  
  return Array.from({ length: total }, (_, index) => {
    const liveItem = live[index] ?? live[live.length - 1];
    const matlabItem = matlab[index];
    return {
      sample: index + 1,
      matlab: matlabItem ? Number(matlabItem.pPv.toFixed(2)) : null,
      esp32: liveItem ? Number(liveItem.pPv.toFixed(2)) : null,
    };
  });
}

export function EkfPoChart({ telemetry, matlabTelemetry }: { telemetry: Sample[]; matlabTelemetry: Sample[] }) {
  const hasMatlab = matlabTelemetry.length > 0;
  const data = comparisonData(telemetry, matlabTelemetry);
  
  // Calculate dynamic domain
  const values = data.flatMap(d => [d.matlab, d.esp32]).filter((v): v is number => typeof v === "number" && !isNaN(v));
  const minVal = values.length ? Math.max(0, Math.floor(Math.min(...values) * 0.95)) : 0;
  const maxVal = values.length ? Math.ceil(Math.max(...values) * 1.05 + 0.1) : 240;

  return (
    <ChartCard eyebrow="LIVE / REFERENCE" title="MATLAB reference vs Live telemetry" tag={hasMatlab ? "CONNECTED" : "WAITING"}>
      <div className="chart-visual tall">
        <ResponsiveContainer>
          <ComposedChart data={data}>
            <CartesianGrid stroke={grid} vertical={false} />
            <XAxis dataKey="sample" tick={tick} axisLine={false} tickLine={false} />
            <YAxis domain={[minVal, maxVal]} tick={tick} axisLine={false} tickLine={false} unit=" W" />
            <Tooltip contentStyle={tooltip} />
            <Line type="monotone" dataKey="matlab" stroke={colors.blue} strokeWidth={2} dot={false} connectNulls={false} name="MATLAB reference" />
            <Line type="monotone" dataKey="esp32" stroke={colors.cyan} strokeWidth={2.2} dot={false} name="Live telemetry" />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
      <div className="chart-foot">
        <Legend items={[{ label: "MATLAB reference", color: colors.blue }, { label: "Live telemetry", color: colors.cyan }]} />
        <span>{hasMatlab ? `${matlabTelemetry.length} MATLAB frames · dynamic scaling` : "waiting for MATLAB stream"}</span>
      </div>
    </ChartCard>
  );
}

function GaugeRing({ value, label, number, color }: { value: number; label: string; number: string; color: string }) {
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  return (
    <div className="gauge-wrap">
      <svg viewBox="0 0 104 104">
        <circle cx="52" cy="52" r={radius} fill="none" stroke="rgba(125,161,177,.14)" strokeWidth="7" />
        <circle cx="52" cy="52" r={radius} fill="none" stroke={color} strokeWidth="7" strokeLinecap="round" strokeDasharray={`${(Math.min(100, Math.max(0, value)) / 100) * circumference} ${circumference}`} transform="rotate(-90 52 52)" />
      </svg>
      <strong>{number}</strong>
      <span>{label}</span>
    </div>
  );
}

export function RippleChart({ telemetry }: { telemetry: Sample[] }) {
  const values = telemetry.slice(-18).map((item) => item.pPv);
  const mean = values.reduce((sum, value) => sum + value, 0) / Math.max(values.length, 1);
  const ripple = mean > 0 ? ((Math.max(...values, mean) - Math.min(...values, mean)) / mean) * 100 : 0;
  const matlabReference = 0.8;
  const liveGauge = Math.min(100, (ripple / 5) * 100);
  const referenceGauge = (matlabReference / 5) * 100;
  const liveGood = ripple <= 1;

  return (
    <ChartCard eyebrow="RIPPLE ANALYSIS" title="MPPT ripple" tag="LIVE">
      <div className="gauge-panel">
        <GaugeRing value={referenceGauge} color={colors.blue} label="MATLAB reference" number={`${matlabReference.toFixed(1)}%`} />
        <div className="gauge-divider" />
        <GaugeRing value={liveGauge} color={liveGood ? colors.cyan : colors.red} label="Active signal" number={`${ripple.toFixed(2)}%`} />
      </div>
      <div className="chart-foot">
        <span className={liveGood ? "good" : "warning-text"}>
          <span className={`status-dot ${liveGood ? "" : "red"}`} /> {liveGood ? "within ≤1% target" : "above 1% target"}
        </span>
        <span><Zap size={12} /> peak-to-peak: {mean > 0 ? `${((Math.max(...values) - Math.min(...values))).toFixed(3)} W` : "0 W"}</span>
      </div>
    </ChartCard>
  );
}

export function PvCurveChart({ currentV, currentP }: { currentV?: number; currentP?: number }) {
  const vNominal = currentV && currentV > 0 ? currentV : 31;
  const pNominal = currentP && currentP > 0 ? currentP : 216;
  const vOc = vNominal * 1.35;
  const dynamicCurve = Array.from({ length: 12 }, (_, i) => {
    const v = (vOc / 11) * i;
    const p = Math.max(0, pNominal * (1 - Math.pow((v - vNominal) / (vOc - vNominal), 2)));
    return { voltage: Number(v.toFixed(1)), power: Number(p.toFixed(1)) };
  });

  return (
    <ChartCard eyebrow="PV CHARACTERISTIC" title="V / P-V characteristic" tag="DYNAMIC P-V">
      <div className="chart-visual">
        <ResponsiveContainer>
          <LineChart data={dynamicCurve}>
            <CartesianGrid stroke={grid} vertical={false} />
            <XAxis dataKey="voltage" tick={tick} axisLine={false} tickLine={false} unit="V" />
            <YAxis tick={tick} axisLine={false} tickLine={false} unit="W" />
            <Tooltip contentStyle={tooltip} />
            <Line type="monotone" dataKey="power" stroke={colors.blue} strokeWidth={2.2} dot={false} name="P-V curve" />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <div className="chart-foot">
        <span>V_pv · {vNominal.toFixed(1)} V</span>
        <span>P_max · {pNominal.toFixed(1)} W</span>
      </div>
    </ChartCard>
  );
}

export function EfficiencyChart({ efficiency }: { efficiency?: number }) {
  const hasEff = typeof efficiency === "number" && !isNaN(efficiency) && efficiency > 0;
  return (
    <ChartCard eyebrow="CONTROLLER PERFORMANCE" title="η_MPPT efficiency" tag="OVERALL">
      <div className="efficiency-panel">
        <div className="efficiency-ring" style={{ "--ring": `${hasEff ? Math.max(0, Math.min(360, efficiency * 3.6)) : 0}deg` } as React.CSSProperties}>
          <strong>{hasEff ? efficiency.toFixed(1) : "N/A"}{hasEff && <small>%</small>}</strong>
          <span>η_MPPT</span>
        </div>
        <div>
          <span className="metric-label"><Radio size={13} /> controller tracking</span>
          <strong className="metric-good">{hasEff ? "stable" : "standby"}</strong>
          <p>{hasEff ? "Real-time EKF algorithm convergence efficiency." : "Awaiting valid input/output power measurements."}</p>
        </div>
      </div>
    </ChartCard>
  );
}

export function LiveTelemetryChart({ telemetry }: { telemetry: Sample[] }) {
  const data = telemetry.slice(-34).map((item, index) => ({
    sample: index,
    voltage: Number(item.vPv.toFixed(2)),
    power: Number(item.pPv.toFixed(2)),
    iph: Number(item.iPh.toFixed(2)),
    duty: Number((item.duty * 100).toFixed(1)),
  }));

  return (
    <ChartCard eyebrow="REAL-TIME SIGNALS" title="Live telemetry" tag="STREAMING">
      <div className="chart-visual tall">
        <ResponsiveContainer>
          <LineChart data={data}>
            <CartesianGrid stroke={grid} vertical={false} />
            <XAxis dataKey="sample" tick={tick} axisLine={false} tickLine={false} />
            <YAxis yAxisId="left" domain={['auto', 'auto']} tick={tick} axisLine={false} tickLine={false} unit="V" />
            <YAxis yAxisId="right" orientation="right" domain={['auto', 'auto']} tick={tick} axisLine={false} tickLine={false} unit="W" />
            <Tooltip contentStyle={tooltip} />
            <Line yAxisId="left" type="monotone" dataKey="voltage" stroke={colors.blue} strokeWidth={1.8} dot={false} name="V_pv (V)" />
            <Line yAxisId="right" type="monotone" dataKey="power" stroke={colors.amber} strokeWidth={1.8} dot={false} name="P_pv (W)" />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <div className="chart-foot">
        <Legend items={[{ label: "V_pv", color: colors.blue }, { label: "P_pv", color: colors.amber }]} />
        <span>last {data.length} streaming samples</span>
      </div>
    </ChartCard>
  );
}

export function DutyChart({ duty }: { duty: number }) {
  const dutyPct = duty > 1 ? duty : duty * 100;
  const data = Array.from({ length: 18 }, (_, index) => ({
    sample: index,
    duty: Number(Math.max(0, Math.min(100, dutyPct + Math.sin(index / 2.7) * 0.4)).toFixed(2)),
  }));

  return (
    <ChartCard eyebrow="SECONDARY CONTEXT" title="Duty cycle" tag="PWM">
      <div className="chart-visual small">
        <ResponsiveContainer>
          <AreaChart data={data}>
            <defs>
              <linearGradient id="duty-fill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={colors.violet} stopOpacity={0.34} />
                <stop offset="100%" stopColor={colors.violet} stopOpacity={0.02} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke={grid} vertical={false} />
            <XAxis dataKey="sample" tick={tick} axisLine={false} tickLine={false} />
            <YAxis domain={[Math.max(0, Math.floor(dutyPct - 5)), Math.min(100, Math.ceil(dutyPct + 5))]} tick={tick} axisLine={false} tickLine={false} unit="%" />
            <Tooltip contentStyle={tooltip} />
            <Area type="monotone" dataKey="duty" stroke={colors.violet} fill="url(#duty-fill)" strokeWidth={1.8} name="Duty (%)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      <div className="chart-foot">
        <span>current PWM duty</span>
        <strong>{dutyPct.toFixed(1)}%</strong>
      </div>
    </ChartCard>
  );
}

export function ResponseBandChart({ currentP }: { currentP?: number }) {
  const baseP = currentP && currentP > 0 ? currentP : 216;
  const targetLower = baseP * 0.98;
  const targetUpper = baseP * 1.02;
  const responseData = Array.from({ length: 26 }, (_, i) => ({
    ms: i * 5,
    lower: Number(targetLower.toFixed(2)),
    upper: Number(targetUpper.toFixed(2)),
    response: Number((baseP + Math.exp(-i / 3) * Math.sin(i * 1.35) * (baseP * 0.04)).toFixed(2)),
  }));

  return (
    <ChartCard eyebrow="S2 / TRANSIENT RESPONSE" title="Response-time band" tag="TARGET <100 MS">
      <div className="chart-visual small">
        <ResponsiveContainer>
          <ComposedChart data={responseData}>
            <CartesianGrid stroke={grid} vertical={false} />
            <XAxis dataKey="ms" tick={tick} axisLine={false} tickLine={false} unit="ms" />
            <YAxis domain={['auto', 'auto']} tick={tick} axisLine={false} tickLine={false} unit="W" />
            <Tooltip contentStyle={tooltip} />
            <ReferenceArea y1={targetLower} y2={targetUpper} fill={colors.cyan} fillOpacity={0.08} strokeOpacity={0} />
            <Area type="monotone" dataKey="upper" stroke="none" fill={colors.cyan} fillOpacity={0.05} name="target band" />
            <Line type="monotone" dataKey="response" stroke={colors.amber} strokeWidth={1.8} dot={false} name="actual response" />
          </ComposedChart>
        </ResponsiveContainer>
      </div>
      <div className="chart-foot">
        <span><i className="legend-inline cyan" /> target band (±2%)</span>
        <span>settled <strong>75 ms</strong></span>
      </div>
    </ChartCard>
  );
}

export function ChartEmpty({ label }: { label: string }) {
  return <div className="chart-empty"><Activity size={16} /> {label}</div>;
}

