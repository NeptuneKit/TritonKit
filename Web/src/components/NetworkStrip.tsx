import { Table, Tag } from "antd";
import { Network } from "lucide-react";
import { modeLabel, type DisplayLanguage } from "./inspectorWorkspaceModel";
import type { NetworkEvent } from "../types";

export function NetworkStrip({
  id,
  hidden,
  language,
  events,
}: {
  id?: string;
  hidden?: boolean;
  language: DisplayLanguage;
  events: NetworkEvent[];
}) {
  const columns = [
    {
      title: "Method",
      dataIndex: "method",
      key: "method",
      width: 70,
    },
    {
      title: "Path",
      dataIndex: "path",
      key: "path",
      ellipsis: true,
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      width: 70,
      render: (status: number) => (
        <Tag color={status >= 400 ? "error" : "success"}>{status}</Tag>
      ),
    },
    {
      title: "Latency",
      dataIndex: "latencyMs",
      key: "latencyMs",
      width: 90,
      render: (latencyMs: number) => `${latencyMs} ms`,
    },
    {
      title: "Mode",
      dataIndex: "mode",
      key: "mode",
      width: 80,
      render: (mode: NetworkEvent["mode"]) => modeLabel[language][mode],
    },
  ];

  return (
    <section
      id={id}
      className="evidence-strip"
      role={id ? "tabpanel" : undefined}
      aria-label={language === "zh-CN" ? "Trace 证据" : "Trace evidence"}
      hidden={hidden}
    >
      <div className="strip-heading">
        <Network size={16} />
        <strong>Trace</strong>
      </div>
      <Table
        dataSource={events}
        columns={columns}
        rowKey="id"
        size="small"
        pagination={false}
        scroll={{ y: 400 }}
      />
    </section>
  );
}
