import { useState, type ReactNode } from "react";
import {
  Badge,
  CopyButton,
  Disclosure,
  EmptyState,
  Inline,
  KeyValue,
  Notice,
  Skeleton,
  Stack,
  Tabs,
  Text,
  type Tone,
} from "@linhey/rhine-design";
import type { WorkspaceAppMapPathSummary, WorkspaceCommandSuggestion, WorkspaceRunProposalSummary, WorkspaceRunStatus, WorkspaceWorkbenchDTO } from "../types";
import "./runWorkbench.css";

export type RunWorkbenchViewProps = {
  workbench?: WorkspaceWorkbenchDTO | null;
  state?: "ready" | "loading" | "error";
  errorMessage?: string;
  copyCommand?: (command: string) => Promise<void>;
  headerActions?: ReactNode;
};

const runLabels: Record<WorkspaceRunStatus, string> = {
  running: "进行中", paused: "已暂停", passed: "已通过", failed: "失败", stopped: "已停止",
};
const pathLabels: Record<WorkspaceAppMapPathSummary["status"], string> = {
  candidate: "候选", verified: "已验证", unhealthy: "异常", blocked: "受阻",
};
function runTone(status: WorkspaceRunStatus): Tone {
  return status === "failed" ? "error" : status === "passed" ? "success" : status === "paused" ? "warning" : "neutral";
}
function healthTone(health: WorkspaceAppMapPathSummary["health"]): Tone {
  return health === "healthy" ? "success" : health === "warning" ? "warning" : "error";
}

export function RunWorkbenchView({ workbench, state = "ready", errorMessage, copyCommand, headerActions }: RunWorkbenchViewProps) {
  const [tab, setTab] = useState("overview");
  const loading = state === "loading";
  const failed = state === "error";
  const run = workbench?.run;
  const hasCommands = Boolean(run?.suggestedCommands.length || workbench?.paths.some(path => path.suggestedCommands.length));

  return <section className="rhine-workbench" role="region" aria-label="运行与路径" aria-busy={loading}>
    <header className="rhine-workbench-header">
      <Text as="h2" variant="heading">运行与路径</Text>
      {headerActions && <div className="rhine-workbench-header-actions">{headerActions}</div>}
    </header>
    <div className="rhine-workbench-body"><Stack gap={4}>
      {failed && <Notice tone="error" title="工作台读取失败">
        {errorMessage || "暂时无法读取运行记录。"} 请检查连接后重新读取。
        {workbench && " 以下保留上次读取的记录。"}
      </Notice>}
      {loading && (workbench
        ? <Notice title="正在读取工作台">保留上次读取的记录，等待新的结果。</Notice>
        : <Skeleton label="正在读取工作台" lines={4} />)}
      {!workbench && !loading && !failed && <EmptyState title="暂无运行记录" description="选择已有运行后查看任务、路径和建议命令。" />}
      {workbench && run && <>
        <section aria-label="当前运行摘要"><Stack gap={3}>
          <Inline gap={2}>
            <Text as="span" variant="caption" tone="muted">{run.runId}</Text>
            <Badge tone={runTone(run.status)}>{runLabels[run.status] ?? run.status} · {run.status}</Badge>
          </Inline>
          <Text as="h3" variant="section">{run.goal || "未提供运行目标"}</Text>
          <div className="rhine-workbench-facts">
            <Stack gap={1}><Text variant="caption" tone="muted">应用</Text><Text>{run.app.name || "—"}</Text></Stack>
            <Stack gap={1}><Text variant="caption" tone="muted">当前目标 · {run.target.platform}/{run.target.scope}</Text><Text>{run.target.name || "—"}</Text></Stack>
          </div>
          <div className="rhine-workbench-coverage">
            <Text as="span">Atlas 覆盖</Text>
            <Badge tone={run.appMap.coverageStatus === "covered" ? "success" : "warning"}>{run.appMap.coverageStatus || "unknown"}</Badge>
          </div>
          <Text>{run.appMap.screenCount} 个界面 · {run.appMap.stateCount} 个状态 · {run.appMap.transitionCount} 次转换 · {run.appMap.pathCount} 条路径</Text>
          {run.latestPause && <Notice tone="warning" title="最近暂停">{run.latestPause.reason || "未提供暂停原因"}</Notice>}
          {!run.providersReady && <Notice tone="warning" title="Provider 未就绪 · not ready" />}
        </Stack></section>
        <Tabs label="运行工作台内容" value={tab} onValueChange={setTab} items={[
          {
            value: "overview", label: "当前运行",
            content: <Stack gap={3}>
              {run.latestRecoveryProposal && <Proposal title="恢复建议" proposal={run.latestRecoveryProposal} />}
              {run.latestBootstrapProposal && <Proposal title="启动建议" proposal={run.latestBootstrapProposal} />}
              <Disclosure title="运行详情">
                <KeyValue items={[
                  { key: "app", label: "App 标识", value: run.app.bundleId || "—" },
                  { key: "target", label: "目标选择器", value: run.target.targetSelector || "—" },
                  { key: "providers", label: "Provider", value: `${run.llmEnabled ? "LLM on" : "LLM off"} · ${run.vlmEnabled ? "VLM on" : "VLM off"}${run.providersReady ? " · ready" : ""}` },
                  { key: "map", label: "Map ref", value: run.appMap.mapRef || "—" },
                  { key: "paths", label: "Path IDs", value: run.appMap.pathIds.join(", ") || "—" },
                  ...(run.latestPause ? [{ key: "pause-evidence", label: "暂停证据", value: run.latestPause.evidenceRef || "—" }] : []),
                  ...(workbench.evidenceRefs.length ? [{ key: "evidence", label: "运行证据", value: <References values={workbench.evidenceRefs} /> }] : []),
                ]} />
              </Disclosure>
            </Stack>,
          },
          {
            value: "paths", label: "Atlas 路径",
            content: workbench.paths.length ? <ul className="rhine-workbench-paths" aria-label="Atlas 路径列表">
              {workbench.paths.map(path => <li key={path.pathId} className="rhine-workbench-path">
                <Stack gap={2}>
                  <Text as="h3" variant="heading">{path.name}</Text>
                  <Inline gap={2}>
                    <Badge tone={path.status === "blocked" || path.status === "unhealthy" ? "error" : path.status === "verified" ? "success" : "neutral"}>{pathLabels[path.status]} · {path.status}</Badge>
                    {path.health !== path.status && <Badge tone={healthTone(path.health)}>健康 · {path.health}</Badge>}
                    {path.health === path.status && <Text as="span" variant="caption" tone="error">健康异常</Text>}
                  </Inline>
                  <Text tone={path.replayable ? "default" : "warning"}>{path.confirmed ? "已确认" : "未确认"} · {path.replayable ? "可回放" : "不可回放"}{path.requiresVLM ? " · 需要 VLM" : ""}</Text>
                  {!path.suggestedCommands.some(command => command.key.includes("run")) && <Text tone="warning">未提供回放命令 · export first</Text>}
                  <Disclosure title="来源与命令">
                    <Stack gap={3}>
                      <KeyValue items={[
                        { key: "id", label: "Path ID", value: path.pathId },
                        { key: "runs", label: "来源 Run", value: path.sourceRuns.length ? <References values={path.sourceRuns} /> : "—" },
                        { key: "vlm", label: "视觉要求", value: path.requiresVLM ? "需要 VLM" : "不需要 VLM" },
                      ]} />
                      {path.suggestedCommands.length ? <CommandList commands={path.suggestedCommands} source={`路径 · ${path.name}`} copyCommand={copyCommand} />
                        : <Text tone="muted">此路径没有建议命令。</Text>}
                    </Stack>
                  </Disclosure>
                </Stack>
              </li>)}
            </ul> : <EmptyState title="暂无路径" description="当前 Atlas 没有可展示的路径。" />,
          },
          {
            value: "commands", label: "建议命令",
            content: hasCommands ? <Stack gap={4}>
              <CommandList commands={run.suggestedCommands} source="当前 Run" copyCommand={copyCommand} />
              {workbench.paths.filter(path => path.suggestedCommands.length > 0).map(path => <CommandList key={path.pathId}
                commands={path.suggestedCommands} source={`路径 · ${path.name}`} copyCommand={copyCommand} />)}
            </Stack> : <EmptyState title="暂无建议命令" description="当前记录没有提供可用命令。" />,
          },
        ]} />
      </>}
    </Stack></div>
  </section>;
}

function CommandList({ commands, source, copyCommand }: { commands: WorkspaceCommandSuggestion[]; source: string; copyCommand?: (command: string) => Promise<void> }) {
  if (!commands.length) return null;
  return <Stack gap={3}>
    {commands.map(command => <section className="rhine-workbench-command-entry" key={command.key} aria-label={`${source} · ${command.label}`}>
      <Stack gap={2}>
        <div className="rhine-workbench-command-heading">
          <Stack gap={1}><Text as="h4" variant="heading">{command.label}</Text><Text variant="caption" tone="muted">{source}</Text></Stack>
          <div className="rhine-workbench-command-actions"><CopyButton value={command.command} label={`复制命令：${command.label}`} copy={copyCommand} /></div>
        </div>
        <Text as="code" variant="code" className="rhine-workbench-command">{command.command}</Text>
      </Stack>
    </section>)}
  </Stack>;
}

function Proposal({ title, proposal }: { title: string; proposal: WorkspaceRunProposalSummary }) {
  return <section aria-label={title}><Stack gap={1}>
    <Text as="h3" variant="heading">{proposal.title}</Text>
    <Text>{proposal.summary}</Text>
    {proposal.evidenceRefs.length > 0 && <Disclosure title={`${title}证据`}><References values={proposal.evidenceRefs} /></Disclosure>}
  </Stack></section>;
}

function References({ values }: { values: string[] }) {
  return <ul className="rhine-workbench-references">{values.map((value, index) => <li key={`${index}:${value}`}><Text as="span" variant="code">{value}</Text></li>)}</ul>;
}
