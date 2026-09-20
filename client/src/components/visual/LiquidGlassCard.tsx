import type { ReactNode } from "react";

export function LiquidGlassCard({ children, className = "", as: Component = "article" }: { children: ReactNode; className?: string; as?: "article" | "section" | "div" }) {
  return <Component className={`liquid-glass ${className}`}>{children}</Component>;
}
