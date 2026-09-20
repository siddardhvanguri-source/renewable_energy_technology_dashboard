import { Toaster } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { Route, Switch } from "wouter";
import ErrorBoundary from "./components/ErrorBoundary";
import { PlatformShell } from "./components/PlatformShell";
import { ThemeProvider } from "./contexts/ThemeContext";
import Home from "./pages/Home";
import History from "./pages/History";
import Scenarios from "./pages/Scenarios";
import Settings from "./pages/Settings";
import NotFound from "./pages/NotFound";

function Router() { return <PlatformShell><Switch><Route path="/" component={Home} /><Route path="/history" component={History} /><Route path="/scenarios" component={Scenarios} /><Route path="/settings" component={Settings} /><Route path="/404" component={NotFound} /><Route component={NotFound} /></Switch></PlatformShell>; }
export default function App() { return <ErrorBoundary><ThemeProvider defaultTheme="dark"><TooltipProvider><Toaster /><Router /></TooltipProvider></ThemeProvider></ErrorBoundary>; }
