import { FlaskConical, Radio, SlidersHorizontal } from "lucide-react";

type DataSource = "DEMO" | "SIMULATION" | "HARDWARE";

export function DataSourceSelector({ source, onChange }: { source: DataSource; onChange: (source: DataSource) => void }) {
  const items = [
    { value: "DEMO" as const, label: "DEMO", icon: SlidersHorizontal },
    { value: "SIMULATION" as const, label: "MATLAB", icon: FlaskConical },
    { value: "HARDWARE" as const, label: "ESP32", icon: Radio },
  ];
  return <div className="data-source-selector" aria-label="Telemetry data source">
    {items.map(({ value, label, icon: Icon }) => <button key={value} type="button" className={source === value ? "active" : ""} onClick={() => onChange(value)}><Icon size={14} /><span>{label}</span></button>)}
  </div>;
}
