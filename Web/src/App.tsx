import { useMemo, useState } from "react";
import {
  Activity,
  Braces,
  ChevronDown,
  CircleDot,
  Clock3,
  Crosshair,
  DatabaseZap,
  FileText,
  Gauge,
  Grid3X3,
  Home,
  Info,
  Keyboard,
  Maximize2,
  MoreHorizontal,
  MousePointer2,
  Network,
  PanelLeft,
  Plus,
  RotateCw,
  ScanLine,
  Search,
  Settings2,
  SlidersHorizontal,
  TerminalSquare,
  ZoomIn,
  ZoomOut,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { logs, networkEvents, targets } from "./data/mockData";
import type { DeviceTarget, LogEntry, NetworkEvent } from "./types";

const platformLabel = {
  ios: "iOS",
  android: "Android",
  harmony: "Harmony",
};

const platformDetail = {
  ios: "Simulator",
  android: "Emulator",
  harmony: "DevEco Emulator",
};

const modeLabel = {
  record: "Record",
  mock: "Mock",
  blocked: "Blocked",
  off: "Off",
};

const extraDevices = [
  { name: "Apple TV 4K", kind: "Simulator", version: "18.5" },
  { name: "Apple Watch Ultra", kind: "Simulator", version: "11.5" },
  { name: "iPad Pro 13-inch", kind: "Simulator", version: "18.5" },
];

export function App() {
  const [selectedId, setSelectedId] = useState(targets[0].id);
  const selected = useMemo(
    () => targets.find((target) => target.id === selectedId) ?? targets[0],
    [selectedId]
  );
  const selectedEvents = networkEvents[selected.id] ?? [];
  const selectedLogs = logs[selected.id] ?? [];

  return (
    <main className="device-hub-shell">
      <section className="device-hub-window" aria-label="TritonKit Device Hub mock">
        <DeviceHubToolbar target={selected} />
        <section className="hub-body">
          <TargetNavigator selected={selected} onSelect={setSelectedId} />
          <DeviceCanvas target={selected} />
          <Inspector target={selected} events={selectedEvents} />
        </section>
        <section className="hub-bottom" aria-label="Device controls and evidence">
          <DeviceControls target={selected} />
          <NetworkStrip events={selectedEvents} />
          <LogStrip entries={selectedLogs} />
        </section>
      </section>
    </main>
  );
}

function DeviceHubToolbar({ target }: { target: DeviceTarget }) {
  return (
    <header className="hub-toolbar">
      <div className="traffic-lights" aria-hidden="true">
        <span className="traffic-red" />
        <span className="traffic-yellow" />
        <span className="traffic-green" />
      </div>

      <div className="toolbar-cluster" aria-label="Add simulators and devices">
        <IconTool label="Add target" icon={Plus} />
        <IconTool label="Filter and sort devices" icon={SlidersHorizontal} />
      </div>

      <IconTool label="Toggle sidebar" icon={PanelLeft} variant="solo" />

      <div className="toolbar-title">
        <strong>{target.name}</strong>
        <span>{target.os}</span>
      </div>

      <div className="toolbar-center">
        <div className="toolbar-cluster" aria-label="Device interactions">
          <IconTool label="Keyboard" icon={Keyboard} />
          <IconTool label="Screen layout" icon={ScanLine} />
        </div>
        <div className="toolbar-cluster" aria-label="Canvas controls">
          <IconTool label="Zoom out" icon={ZoomOut} />
          <IconTool label="Actual size" icon={Search} />
          <IconTool label="Zoom in" icon={ZoomIn} />
        </div>
        <div className="toolbar-cluster" aria-label="Compress or expand window">
          <IconTool label="Expand" icon={Maximize2} />
          <IconTool label="More" icon={MoreHorizontal} />
        </div>
      </div>

      <div className="toolbar-cluster inspector-tools" aria-label="Inspector tools">
        <IconTool label="Adjust" icon={Settings2} />
        <IconTool label="Document" icon={FileText} />
        <IconTool label="Info" icon={Info} />
      </div>
    </header>
  );
}

function IconTool({
  label,
  icon: Icon,
  variant,
}: {
  label: string;
  icon: LucideIcon;
  variant?: "solo";
}) {
  return (
    <button className={`icon-tool ${variant === "solo" ? "is-solo" : ""}`} type="button" aria-label={label} title={label}>
      <Icon size={17} strokeWidth={2.2} />
    </button>
  );
}

function TargetNavigator({
  selected,
  onSelect,
}: {
  selected: DeviceTarget;
  onSelect: (id: string) => void;
}) {
  return (
    <aside className="hub-sidebar" aria-label="Devices">
      <label className="sidebar-search">
        <Search size={16} />
        <input placeholder="Search" />
      </label>

      <div className="sidebar-section-title">Available</div>
      <div className="device-list">
        {targets.map((target) => (
          <button
            className={`device-row ${target.id === selected.id ? "is-selected" : ""}`}
            key={target.id}
            onClick={() => onSelect(target.id)}
            type="button"
          >
            <span className="device-row-icon" style={{ color: target.accent }}>
              <target.Icon size={21} />
            </span>
            <span className="device-row-copy">
              <strong>{target.name}</strong>
              <span>{platformDetail[target.platform]}</span>
            </span>
            <span className="device-version">{target.os.replace(/^[A-Za-z ]+/, "")}</span>
          </button>
        ))}

        {extraDevices.map((device) => (
          <div className="device-row is-muted" key={device.name}>
            <span className="device-row-icon">
              <CircleDot size={18} />
            </span>
            <span className="device-row-copy">
              <strong>{device.name}</strong>
              <span>{device.kind}</span>
            </span>
            <span className="device-version">{device.version}</span>
          </div>
        ))}
      </div>
    </aside>
  );
}

function DeviceCanvas({ target }: { target: DeviceTarget }) {
  return (
    <section className="hub-canvas" aria-label="Device canvas">
      <div className="canvas-label">
        <span>{target.appName}</span>
        <strong>{target.bundleId}</strong>
      </div>

      <div className="landscape-device">
        <div className="device-side left" />
        <div className="device-side top" />
        <div className="device-side bottom" />
        <div className={`landscape-screen ${target.screenshotTone}`}>
          <div className="screen-island" />
          <div className="screen-hero">
            <span>Featured Target</span>
            <strong>{target.appName}</strong>
            <button type="button">Inspect</button>
          </div>
          <div className="screen-content">
            <div>
              <h2>{platformDetail[target.platform]}</h2>
              <p>{target.device}</p>
            </div>
            <div className="screen-card-row">
              <ScreenMini label="Frame" value={target.screenSize} />
              <ScreenMini label="Proxy" value={target.proxyLabel} />
              <ScreenMini label="Transport" value={target.transport} />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function ScreenMini({ label, value }: { label: string; value: string }) {
  return (
    <div className="screen-mini">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Inspector({ target, events }: { target: DeviceTarget; events: NetworkEvent[] }) {
  const errorCount = events.filter((event) => event.status >= 400).length;

  return (
    <aside className="hub-inspector" aria-label="Inspector">
      <div className="inspector-tabs" role="tablist" aria-label="Inspector sections">
        <button className="is-active" type="button">Info</button>
        <button type="button">Apps</button>
        <button type="button">Profiles</button>
      </div>

      <section className="app-tile" aria-label="Selected app">
        <div className="app-icon">
          <Activity size={18} />
        </div>
        <div>
          <strong>{target.appName}</strong>
          <span>{target.bundleId}</span>
        </div>
        <em>{target.statusLabel}</em>
      </section>

      <div className="metric-stack">
        <Metric icon={Gauge} label="FPS" value={target.fps.toString()} />
        <Metric icon={Clock3} label="Latency" value={`${target.latencyMs} ms`} />
        <Metric icon={Braces} label="AX Nodes" value={target.hierarchyNodes.toString()} />
        <Metric icon={DatabaseZap} label="HTTP Errors" value={errorCount.toString()} />
      </div>

      <dl className="inspector-details">
        <div>
          <dt>Device</dt>
          <dd>{target.device}</dd>
        </div>
        <div>
          <dt>Transport</dt>
          <dd>{target.transport}</dd>
        </div>
        <div>
          <dt>Proxy</dt>
          <dd>{target.proxyLabel}</dd>
        </div>
      </dl>

      <div className="inspector-footer">
        <Search size={15} />
        <span>Filter</span>
        <strong>Developer</strong>
        <ChevronDown size={14} />
      </div>
    </aside>
  );
}

function Metric({
  icon: Icon,
  label,
  value,
}: {
  icon: LucideIcon;
  label: string;
  value: string;
}) {
  return (
    <div className="metric">
      <Icon size={16} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function DeviceControls({ target }: { target: DeviceTarget }) {
  const actions = [
    { label: "Apps", Icon: Grid3X3 },
    { label: "Point", Icon: MousePointer2 },
    { label: "Probe", Icon: Crosshair },
    { label: "Home", Icon: Home },
    { label: "Rotate", Icon: RotateCw },
  ];

  return (
    <section className="device-controls" aria-label="Device controls">
      <div className="control-pill">
        {actions.map(({ label, Icon }) => (
          <button key={label} type="button" aria-label={label} title={label}>
            <Icon size={17} />
          </button>
        ))}
      </div>
      <div className={`last-action result-${target.actionResult}`}>
        <strong>Last</strong>
        <span>{target.lastAction}</span>
      </div>
    </section>
  );
}

function NetworkStrip({ events }: { events: NetworkEvent[] }) {
  return (
    <section className="evidence-strip" aria-label="Network evidence">
      <div className="strip-heading">
        <Network size={16} />
        <strong>Network</strong>
      </div>
      <div className="network-rows">
        {events.map((event) => (
          <div className="network-row" key={event.id}>
            <span className="method">{event.method}</span>
            <span className="path">{event.path}</span>
            <span className={event.status >= 400 ? "code is-error" : "code"}>{event.status}</span>
            <span>{event.latencyMs} ms</span>
            <span>{modeLabel[event.mode]}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function LogStrip({ entries }: { entries: LogEntry[] }) {
  return (
    <section className="evidence-strip log-strip" aria-label="Runtime logs">
      <div className="strip-heading">
        <TerminalSquare size={16} />
        <strong>Logs</strong>
      </div>
      <div className="log-rows">
        {entries.map((entry) => (
          <div className={`log-row log-${entry.level}`} key={entry.id}>
            <span>{entry.time}</span>
            <strong>{entry.level}</strong>
            <p>{entry.message}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
