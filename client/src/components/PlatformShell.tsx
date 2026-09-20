import { useAuth } from "@/_core/hooks/useAuth";
import { startLogin } from "@/const";
import { Link, useLocation } from "wouter";
import { Activity, BookOpen, Cable, ChevronRight, CircleUserRound, Database, Gauge, LogOut, Menu, Settings2, ShieldCheck, Sun, X } from "lucide-react";
import { useState, type ReactNode } from "react";

const navItems = [
  { href: "/", label: "Dashboard", icon: Activity },
  { href: "/history", label: "History", icon: Database },
  { href: "/scenarios", label: "Tests", icon: Gauge },
  { href: "/settings", label: "Settings", icon: Settings2 },
];

export function PlatformShell({ children }: { children: ReactNode }) {
  const [location] = useLocation();
  const [open, setOpen] = useState(false);
  const { user, isAuthenticated, logout } = useAuth();
  return (
    <div className="platform-shell">
      <aside className={`side-rail ${open ? "open" : ""}`}>
        <div className="rail-brand">
          <div className="brand-mark"><span /><span /><span /></div>
          <div><small>ESP32 / MPPT</small><strong>POWER MONITOR</strong></div>
          <button className="rail-close" aria-label="Close navigation" onClick={() => setOpen(false)}><X size={16} /></button>
        </div>
        <div className="rail-device"><span className="status-dot live-dot" /><div><small>ACTIVE NODE</small><strong>ARRAY A / MPPT NODE</strong></div><ChevronRight size={14} /></div>
        <nav className="rail-nav" aria-label="Main navigation">
          <small className="rail-label">MENU</small>
          {navItems.map(({ href, label, icon: Icon }) => <Link key={href} href={href} className={`rail-link ${location === href ? "active" : ""}`} onClick={() => setOpen(false)}><Icon size={16} /><span>{label}</span>{location === href ? <span className="nav-active-line" /> : null}</Link>)}
        </nav>
        <div className="rail-foot">
          <div className="rail-context"><ShieldCheck size={15} /><span>SAFETY ON</span></div>
          <div className="rail-context"><Cable size={15} /><span>LINK READY</span></div>
          <div className="rail-user">
            <CircleUserRound size={18} />
            <div><strong>{user?.name ?? "Guest reviewer"}</strong><small>{isAuthenticated ? "Authenticated operator" : "Demo access"}</small></div>
            {isAuthenticated ? <button aria-label="Sign out" onClick={() => logout()}><LogOut size={14} /></button> : <button aria-label="Sign in" onClick={() => startLogin()}><ChevronRight size={14} /></button>}
          </div>
        </div>
      </aside>
      {open ? <button className="rail-overlay" aria-label="Close navigation" onClick={() => setOpen(false)} /> : null}
      <div className="platform-main">
        <header className="platform-topbar">
          <button className="mobile-rail-trigger" aria-label="Open navigation" onClick={() => setOpen(true)}><Menu size={18} /></button>
          <div className="topbar-context"><span className="eyebrow">ESP32 / MPPT</span><strong>{location === "/" ? "DASHBOARD" : navItems.find((item) => item.href === location)?.label.toUpperCase() ?? "POWER MONITOR"}</strong></div>
          <div className="topbar-right"><span className="runtime-chip"><span className="status-dot live-dot" /> ONLINE</span><span className="runtime-chip hide-mobile"><Sun size={14} /> SUN OK</span><button className="topbar-icon" aria-label="Help"><BookOpen size={15} /></button></div>
        </header>
        <main className="page-wrap">{children}</main>
      </div>
    </div>
  );
}
