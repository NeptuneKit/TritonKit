import { Card, Descriptions, Flex, Space, Table, Tabs, Tag, Typography } from "antd";
import type { TableProps } from "antd";
import { Activity, Map, Route, Terminal } from "lucide-react";

import { mockWorkspaceWorkbench } from "../data/mockData";
import type { WorkspaceWorkbenchDTO } from "../types";
import {
  getWorkbenchOverviewItems,
  getWorkbenchPathRows,
  getWorkbenchSuggestedCommands,
  tagColorForTone,
  toneForPathHealth,
  type WorkbenchPathRow,
} from "../workbenchModel";

type RunWorkbenchCardProps = {
  nodeId: string;
  workbench?: WorkspaceWorkbenchDTO;
};

export function RunWorkbenchCard({ workbench = mockWorkspaceWorkbench }: RunWorkbenchCardProps) {
  const overviewItems = getWorkbenchOverviewItems(workbench);
  const pathRows = getWorkbenchPathRows(workbench);
  const commandRows = getWorkbenchSuggestedCommands(workbench);
  const mapSummary = workbench.run.appMap;
  const pathColumns: TableProps<WorkbenchPathRow>["columns"] = [
    {
      title: "Path",
      dataIndex: "name",
      key: "name",
      render: (_, row) => (
        <div className="workbench-path-title">
          <strong>{row.name}</strong>
          <span>{row.pathId}</span>
        </div>
      ),
    },
    {
      title: "State",
      key: "state",
      width: 190,
      render: (_, row) => (
        <Space size={4} wrap>
          <Tag color={tagColorForTone(toneForPathHealth(row.health))}>{row.health}</Tag>
          {row.confirmed && <Tag color="green">confirmed</Tag>}
          {row.requiresVLM && <Tag color="purple">VLM</Tag>}
          {!row.replayable && <Tag color="red">blocked</Tag>}
        </Space>
      ),
    },
    {
      title: "Source runs",
      dataIndex: "sourceRuns",
      key: "sourceRuns",
      width: 210,
      render: (runs: string[]) => <span className="workbench-muted">{runs.join(", ")}</span>,
    },
    {
      title: "Replay command",
      dataIndex: "primaryCommand",
      key: "primaryCommand",
      render: (command: string | null) => (
        command ? <code className="workbench-inline-code">{command}</code> : <Tag color="gold">export first</Tag>
      ),
    },
  ];

  return (
    <Card className="bento-card workbench-card" variant="borderless">
      <div className="workbench-shell">
        <div className="workbench-header">
          <Flex align="center" gap="small" wrap>
            <Activity size={16} />
            <div className="workbench-title">
              <strong>Run / Atlas Workbench</strong>
              <span>{workbench.run.runId}</span>
            </div>
          </Flex>
          <Space size={4} wrap>
            <Tag color={workbench.run.providersReady ? "green" : "gold"}>LLM</Tag>
            <Tag color={workbench.run.vlmEnabled ? "purple" : "default"}>VLM</Tag>
            <Tag color={workbench.run.status === "failed" ? "red" : "blue"}>{workbench.run.status}</Tag>
          </Space>
        </div>

        <div className="workbench-scroll">
          <Tabs
            size="small"
            defaultActiveKey="overview"
            items={[
              {
                key: "overview",
                label: (
                  <Space size={4}>
                    <Map size={13} />
                    Overview
                  </Space>
                ),
                children: (
                  <div className="workbench-tab">
                    <Descriptions
                      size="small"
                      column={{ xs: 1, sm: 1, md: 2, lg: 3 }}
                      items={overviewItems.map((item) => ({
                        key: item.key,
                        label: item.label,
                        children: (
                          <span className={`workbench-fact is-${item.tone}`}>
                            {item.value}
                          </span>
                        ),
                      }))}
                    />
                    <div className="workbench-map-grid">
                      <div>
                        <span>Map ref</span>
                        <strong>{mapSummary.mapRef}</strong>
                      </div>
                      <div>
                        <span>Coverage</span>
                        <strong>{mapSummary.coverageStatus}</strong>
                      </div>
                      <div>
                        <span>Paths</span>
                        <strong>{mapSummary.pathIds.join(", ")}</strong>
                      </div>
                    </div>
                    <div className="workbench-proposals">
                      {workbench.run.latestBootstrapProposal && (
                        <div>
                          <strong>{workbench.run.latestBootstrapProposal.title}</strong>
                          <span>{workbench.run.latestBootstrapProposal.summary}</span>
                        </div>
                      )}
                      {workbench.run.latestRecoveryProposal && (
                        <div>
                          <strong>{workbench.run.latestRecoveryProposal.title}</strong>
                          <span>{workbench.run.latestRecoveryProposal.summary}</span>
                        </div>
                      )}
                    </div>
                  </div>
                ),
              },
              {
                key: "paths",
                label: (
                  <Space size={4}>
                    <Route size={13} />
                    Atlas paths
                  </Space>
                ),
                children: (
                  <Table
                    className="workbench-path-table"
                    columns={pathColumns}
                    dataSource={pathRows}
                    pagination={false}
                    rowKey="pathId"
                    scroll={{ x: 880 }}
                    size="small"
                  />
                ),
              },
              {
                key: "commands",
                label: (
                  <Space size={4}>
                    <Terminal size={13} />
                    Commands
                  </Space>
                ),
                children: (
                  <div className="workbench-command-list">
                    {commandRows.map((command) => (
                      <div className="workbench-command-row" key={command.key}>
                        <Flex justify="space-between" align="center" gap="small" wrap>
                          <Typography.Text strong>{command.label}</Typography.Text>
                          <Tag color={command.source === "run" ? "blue" : "cyan"}>{command.source}</Tag>
                        </Flex>
                        <code>{command.command}</code>
                      </div>
                    ))}
                  </div>
                ),
              },
            ]}
          />
        </div>
      </div>
    </Card>
  );
}
