import { Table, Tag } from "antd";
import { TerminalSquare } from "lucide-react";
import { localizeLogEntry, logLevelLabel, type DisplayLanguage } from "./inspectorWorkspaceModel";
import type { LogEntry } from "../types";

export function LogStrip({
  id,
  hidden,
  language,
  entries,
}: {
  id?: string;
  hidden?: boolean;
  language: DisplayLanguage;
  entries: LogEntry[];
}) {
  const columns = [
    {
      title: "Time",
      dataIndex: "time",
      key: "time",
      width: 80,
      render: (_: unknown, record: LogEntry) => {
        const localized = localizeLogEntry(record, language);
        return localized.timeLabel;
      },
    },
    {
      title: "Level",
      dataIndex: "level",
      key: "level",
      width: 60,
      render: (level: LogEntry["level"]) => (
        <Tag color={level === "error" ? "error" : level === "warn" ? "warning" : "default"}>
          {logLevelLabel[language][level]}
        </Tag>
      ),
    },
    {
      title: "Source",
      key: "source",
      width: 80,
      render: (_: unknown, record: LogEntry) => {
        const localized = localizeLogEntry(record, language);
        return localized.sourceLabel;
      },
    },
    {
      title: "Message",
      key: "message",
      ellipsis: true,
      render: (_: unknown, record: LogEntry) => {
        const localized = localizeLogEntry(record, language);
        return <span title={localized.originalMessage}>{localized.messageLabel}</span>;
      },
    },
  ];

  return (
    <section
      id={id}
      className="evidence-strip log-strip"
      role={id ? "tabpanel" : undefined}
      aria-label={language === "zh-CN" ? "运行日志" : "Runtime logs"}
      hidden={hidden}
    >
      <div className="strip-heading">
        <TerminalSquare size={16} />
        <strong>{language === "zh-CN" ? "日志" : "Logs"}</strong>
      </div>
      <Table
        dataSource={entries}
        columns={columns}
        rowKey="id"
        size="small"
        pagination={false}
        scroll={{ y: 400 }}
      />
    </section>
  );
}
