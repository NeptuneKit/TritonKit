import { useMemo, useState } from "react";
import {
  Activity,
  ArrowDown,
  ArrowUp,
  Bolt,
  Braces,
  CircleDot,
  Clock3,
  Command,
  Crosshair,
  DatabaseZap,
  Gauge,
  Home,
  Keyboard,
  MousePointer2,
  Network,
  PanelRight,
  Pause,
  Play,
  RadioTower,
  RefreshCw,
  Search,
  ShieldCheck,
  TerminalSquare,
} from "lucide-react";
import { logs, networkEvents, targets } from "./data/mockData";
import type { DeviceTarget, NetworkEvent } from "./types";

const platformLabel = {
  ios: "iOS Simulator",
  android: "Android Emulator",
  harmony: "Harmony / DevEco",
};

const modeLabel = {
  record: "Record",
  mock: "Mock",
  blocked: "Blocked",
  off: "Off",
};

export function App() {
  const [selectedId, setSelectedId] = useState(targets[0].id);
  const [streaming, setStreaming] = useState(true);
  const selected = useMemo(
    () => targets.find((target) => target.id === selectedId) ?? targets[0],
    [selectedId]
  );
  const selectedEvents = networkEvents[selected.id] ?? [];
  const selectedLogs = logs[selected.id] ?? [];

  return (
    <main className="app-shell">
      <aside className="sidebar" aria-label="Device targets">
        <div className="brand-lockup">
          <div className="brand-mark">
            <Command size={18} />
          </div>
          <div>
            <strong>TritonKit</strong>
            <span>Local Control</span>
          </div>
        </div>

        <label className="search-box">
          <Search size={16} />
          <input placeholder="Filter target, app, bundle" />
        </label>

        <div className="target-list">
          {targets.map((target) => (
            <button
              className={`target-row ${target.id === selected.id ? "is-active" : ""}`}
              key={target.id}
              onClick={() => setSelectedId(target.id)}
              type="button"
            >
              <span className="target-icon" style={{ color: target.accent }}>
                <target.Icon size={20} />
              </span>
              <span className="target-copy">
                <strong>{target.name}</strong>
                <span>{platformLabel[target.platform]}</span>
              </span>
              <StatusDot target={target} />
            </button>
          ))}
        </div>

        <div className="sidebar-footer">
          <span>HTTP API</span>
          <strong>127.0.0.1:19421</strong>
        </div>
      </aside>

      <section className="workspace">
        <header className="topbar">
          <div>
            <p className="eyebrow">Web Console Mock</p>
            <h1>本机三端模拟器控制台</h1>
          </div>
          <div className="topbar-actions">
            <button className="icon-button" aria-label="Refresh mock data" type="button">
              <RefreshCw size={18} />
            </button>
            <button
              className={`stream-toggle ${streaming ? "is-live" : ""}`}
              onClick={() => setStreaming((value) => !value)}
              type="button"
            >
              {streaming ? <Pause size={16} /> : <Play size={16} />}
              {streaming ? "Live" : "Paused"}
            </button>
          </div>
        </header>

        <section className="hero-grid" aria-label="Selected target overview">
          <DeviceMirror target={selected} streaming={streaming} />
          <TargetInspector target={selected} events={selectedEvents} />
        </section>

        <section className="lower-grid">
          <ActionDeck target={selected} />
          <NetworkPanel events={selectedEvents} />
          <LogPanel logs={selectedLogs} />
        </section>
      </section>
    </main>
  );
}

function StatusDot({ target }: { target: DeviceTarget }) {
  return (
    <span className={`status-dot status-${target.status}`} aria-label={target.statusLabel}>
      <CircleDot size={14} />
    </span>
  );
}

function DeviceMirror({ target, streaming }: { target: DeviceTarget; streaming: boolean }) {
  return (
    <section className="mirror-panel" aria-label="Device mirror">
      <div className="mirror-toolbar">
        <div className="target-title">
          <span className="target-platform" style={{ color: target.accent }}>
            {platformLabel[target.platform]}
          </span>
          <h2>{target.appName}</h2>
          <p>{target.bundleId}</p>
        </div>
        <div className="codec-control" aria-label="Display codec mode">
          <button className="is-selected" type="button">H.264</button>
          <button type="button">MJPEG</button>
        </div>
      </div>

      <div className="phone-stage">
        <div className="side-button side-button-top" />
        <div className="side-button side-button-bottom" />
        <div className={`phone-frame ${target.screenshotTone}`}>
          <div className="phone-statusbar">
            <span>9:41</span>
            <span>{streaming ? "Live" : "Paused"}</span>
          </div>
          <div className="mock-screen-content">
            <div className="app-header">
              <span>{target.appName}</span>
              <Activity size={16} />
            </div>
            <div className="screen-card primary">
              <span>{target.device}</span>
              <strong>{target.screenSize}</strong>
            </div>
            <div className="screen-list">
              <span />
              <span />
              <span />
            </div>
            <div className="screen-nav">
              <span />
              <span />
              <span />
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function TargetInspector({ target, events }: { target: DeviceTarget; events: NetworkEvent[] }) {
  const errorCount = events.filter((event) => event.status >= 400).length;

  return (
    <aside className="inspector" aria-label="Target inspector">
      <div className="section-heading">
        <PanelRight size={18} />
        <h2>Target Inspector</h2>
      </div>

      <div className="metric-grid">
        <Metric icon={Gauge} label="FPS" value={target.fps.toString()} />
        <Metric icon={Clock3} label="Latency" value={`${target.latencyMs} ms`} />
        <Metric icon={Braces} label="AX Nodes" value={target.hierarchyNodes.toString()} />
        <Metric icon={DatabaseZap} label="HTTP Errors" value={errorCount.toString()} />
      </div>

      <dl className="detail-list">
        <div>
          <dt>Device</dt>
          <dd>{target.device}</dd>
        </div>
        <div>
          <dt>OS</dt>
          <dd>{target.os}</dd>
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

      <div className="contract-strip">
        <ShieldCheck size={18} />
        <span>Web consumes mock DTOs; CLI / HTTP remain the control contract.</span>
      </div>
    </aside>
  );
}

function Metric({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Gauge;
  label: string;
  value: string;
}) {
  return (
    <div className="metric">
      <Icon size={17} />
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function ActionDeck({ target }: { target: DeviceTarget }) {
  const actions = [
    { label: "Tap", Icon: MousePointer2 },
    { label: "Swipe Up", Icon: ArrowUp },
    { label: "Swipe Down", Icon: ArrowDown },
    { label: "Type", Icon: Keyboard },
    { label: "Home", Icon: Home },
    { label: "Probe", Icon: Crosshair },
  ];

  return (
    <section className="panel action-panel" aria-label="Device actions">
      <div className="section-heading">
        <Bolt size={18} />
        <h2>Actions</h2>
      </div>
      <div className="action-grid">
        {actions.map(({ label, Icon }) => (
          <button key={label} type="button">
            <Icon size={18} />
            <span>{label}</span>
          </button>
        ))}
      </div>
      <div className={`action-result result-${target.actionResult}`}>
        <strong>Last result</strong>
        <span>{target.lastAction}</span>
      </div>
    </section>
  );
}

function NetworkPanel({ events }: { events: NetworkEvent[] }) {
  return (
    <section className="panel network-panel" aria-label="Network events">
      <div className="section-heading">
        <Network size={18} />
        <h2>Network</h2>
      </div>
      <div className="network-table">
        {events.map((event) => (
          <div className="network-row" key={event.id}>
            <span className="method">{event.method}</span>
            <span className="path">{event.path}</span>
            <span className={event.status >= 400 ? "status-code is-error" : "status-code"}>
              {event.status}
            </span>
            <span className="latency">{event.latencyMs} ms</span>
            <span className="mode">{modeLabel[event.mode]}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function LogPanel({ logs: entries }: { logs: { id: string; time: string; level: string; message: string }[] }) {
  return (
    <section className="panel log-panel" aria-label="Runtime logs">
      <div className="section-heading">
        <TerminalSquare size={18} />
        <h2>Logs</h2>
      </div>
      <div className="log-list">
        {entries.map((entry) => (
          <div className={`log-line log-${entry.level}`} key={entry.id}>
            <span>{entry.time}</span>
            <strong>{entry.level}</strong>
            <p>{entry.message}</p>
          </div>
        ))}
      </div>
      <div className="radio-strip">
        <RadioTower size={17} />
        <span>Local only</span>
      </div>
    </section>
  );
}
