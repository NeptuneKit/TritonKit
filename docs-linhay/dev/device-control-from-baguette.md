# Device Control From Baguette

## 背景

用户要求参考 `tddworks/baguette` 的设备控制实现，并与 Triton 现有能力结合。Baguette 的价值不在 Web UI，而在它把设备输入抽象成稳定的动作词汇：`tap`、`swipe`、`pinch`、`pan`、`button`、`key`、`type`，并让 one-shot CLI 与流式 JSON 共用同一套解析与执行通道。

## 可复用结论

1. 输入动作应使用领域名词，而不是把 CLI 参数、HTTP route 和底层执行揉在一起。
2. 坐标使用设备点或窗口点，保持与 hierarchy frame 同一单位；不要使用归一化坐标作为外部契约。
3. CLI one-shot 命令与 HTTP JSON 请求应共享同一套 payload。
4. 每个动作都必须返回机器可读结果：`ok`、`action`、`message`、命中对象信息。
5. 不支持的设备级动作必须显式返回 unsupported，不能伪装成功。

## Triton 第一阶段边界

Triton 当前运行时在被测 iOS App 进程内，通过 WebSocket 接收 CLI 请求。它不能直接使用 Baguette 的 SimulatorKit / Indigo HID host-side 路径。因此第一阶段只落地可通过公开 UIKit API 验证的 in-app 控制：

1. `tap`：支持坐标或 `oid`。命中 `UIControl` 时触发公开 control action；命中普通 view 时返回 unsupported。
2. `swipe`：支持坐标路径。命中 `UIScrollView` 时调整 `contentOffset`，用于列表/滚动区域控制；命中非 scroll view 返回 unsupported。
3. `type`：支持文本写入指定 `oid` 或当前 first responder 的 `UIKeyInput`。
4. `button` / `press`：保留契约，但当前 runtime 返回 unsupported；后续如果增加 macOS host-side simulator/device adapter，再接入真正 HID。
5. `ax` / `hit` / `geometry` / `screenshot`：作为 AI 观察闭环，当前从 App 内 UIKit view tree 与 key window 截取；`ax` 首版收敛为安全控件索引树，后续 host-side adapter 可扩展到系统级 AX 和 framebuffer。

## CLI / HTTP 契约

CLI：

```bash
triton act tap --target triton:local --at 120,240 --format json
triton act tap --target triton:local --oid 42 --format json
triton swipe --target triton:local --start-x 200 --start-y 700 --end-x 200 --end-y 300 --format json
triton act type --target triton:local "hello" --format json
triton act press --target triton:local home --format json
triton geometry --target triton:local --format json
triton debug ax --target triton:local --format json
triton debug hit --target triton:local --at 120,240 --format json
triton screenshot --target triton:local --output /tmp/triton-shot.png
triton act input --target triton:local --format json < gestures.ndjson
```

HTTP:

```http
POST /input
Content-Type: application/json

{"type":"tap","x":120,"y":240}
```

返回：

```json
{"ok":true,"action":"tap","targetOID":42,"targetClassName":"UIButton"}
```

失败或 unsupported：

```json
{"ok":false,"action":"button","message":"Host-side HID is not available in the embedded TritonKit runtime"}
```

## 后续阶段

若要接近 Baguette 的完整设备控制能力，需要新增 macOS host-side adapter，并明确它和 embedded TritonKit runtime 的关系：

1. Simulator 发现、boot/shutdown、screen geometry。
2. host-side HID tap/swipe/button/key/type。
3. screenshot 与 accessibility tree。
4. CLI target id 从 `triton:local` 扩展到 simulator/device 多 target。

这属于第二阶段能力，不应阻塞当前 in-app 可控闭环。

## 已验证闭环

2026-05-16 在 `TritonKitDemo` iOS Simulator 上验证通过：

- `triton geometry --format json` 返回 window bounds、safe area、scale、orientation。
- `triton debug ax --format json --output /tmp/triton-ax-smoke.json` 稳定输出 UIKit smoke panel 的 button、switch、text field、scroll、status 节点，不再导致 App 断连。
- `triton debug hit --at 270,300 --format json` 命中 `UIKitSmokeButton` 并返回 frame center。
- `triton screenshot --output /tmp/triton-screenshot-smoke.png --metadata` 写出 PNG 截图。
- `triton act input --format json < gestures.ndjson` 完成 tap、focus/type、swipe 批量动作，并由 XcodeBuildMCP UI 快照确认界面状态。
