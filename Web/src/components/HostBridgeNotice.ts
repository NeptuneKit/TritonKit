import React from "react";

export function HostBridgeNotice({ notice }: { notice: { tone: string; title: string; detail: string } }) {
  return React.createElement(
    "div",
    { className: `bridge-notice is-${notice.tone}`, role: "status", "aria-label": "Host bridge 状态" },
    React.createElement("strong", null, notice.title),
    React.createElement("span", null, notice.detail)
  );
}
