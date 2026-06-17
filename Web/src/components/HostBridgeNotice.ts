import { Info } from "lucide-react";
import { createElement } from "react";
import type { HostBridgeNotice as HostBridgeNoticeModel } from "../data/hostBridgePresentation";

export function HostBridgeNotice({
  notice,
}: {
  notice: HostBridgeNoticeModel;
}) {
  return createElement(
    "section",
    {
      className: `bridge-notice is-${notice.tone}`,
      role: "status",
      "aria-live": "polite",
      "aria-label": "Host bridge 状态",
    },
    [
      createElement(Info, { key: "icon", size: 16 }),
      createElement(
        "div",
        { key: "copy", className: "bridge-notice-copy" },
        [
          createElement("strong", { key: "title" }, notice.title),
          createElement("span", { key: "detail" }, notice.detail),
        ]
      ),
    ]
  );
}
