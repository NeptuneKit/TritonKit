# 2026-05-22 Harmony Host-side Real Smoke

## 目标

验证 WebView Runtime Bridge v02 的 P0 host-side 路径能在真实 DevEco / Harmony emulator target 上工作，不依赖 fake HDC，不要求业务 App 替换 `Web(...)`，也不要求 embedded runtime 可用。

## Target

- HDC target：`127.0.0.1:10100`
- transport：`TCP`
- state：`Connected`
- artifact 目录：`docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/`

## 已执行命令

```bash
hdc list targets -v
.build/cli/release/triton device list --platform harmony --json
.build/cli/release/triton device doctor --platform harmony --json
.build/cli/release/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 60 --json
.build/cli/release/triton ax --platform harmony --target 127.0.0.1:10100 --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/20260522-harmony-host-layout-real-v01.json --json
.build/cli/release/triton screenshot --platform harmony --target 127.0.0.1:10100 --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/20260522-harmony-host-screenshot-real-v01.jpeg --json
.build/cli/release/triton wait --platform harmony --target 127.0.0.1:10100 --text console --timeout 5 --interval 0.5 --json
.build/cli/release/triton tap "点赞" --platform harmony --target 127.0.0.1:10100 --json
.build/cli/release/triton screenshot --platform harmony --target 127.0.0.1:10100 --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/20260522-harmony-host-screenshot-after-tap-like-real-v01.jpeg --json
.build/cli/release/triton wait --platform harmony --target 127.0.0.1:10100 --text "点赞" --timeout 5 --interval 0.5 --json
.build/cli/release/triton ax --platform harmony --target 127.0.0.1:10100 --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/20260522-harmony-host-layout-after-tap-like-real-v02.json --json
.build/cli/release/triton observe tree --platform harmony --target 127.0.0.1:10100 --max-nodes 80 --output docs-linhay/spaces/20260521-webview-runtime-bridge/screenshots/20260522/harmony-host-real/20260522-harmony-host-observe-tree-layout-real-v02.json --json
.build/cli/release/triton node resolve --platform harmony --target 127.0.0.1:10100 --text console --all --json
```

## 结果

1. `device list` 成功返回唯一 Connected target：`harmony:127.0.0.1:10100`。
2. `device wait-ready` 返回 `ok=true`、`ready=true`，底层 source command 为 `hdc -t 127.0.0.1:10100 shell param get bootevent.boot.completed`。
3. `ax --platform harmony` 成功保存真实 layout artifact，底层执行 `uitest dumpLayout` 与 `file recv`。
4. layout 中存在 host-side Web 容器节点，`type=Web`，bounds 为 `[0,318][1308,2612]`。
5. `screenshot --platform harmony` 成功保存真实 JPEG artifact，尺寸为 `1308x2880`。
6. `wait --platform harmony --text console` 一次轮询命中，返回 `ok=true`、`matched=true`、`timedOut=false`，匹配节点 bounds 为 `x=168,y=690,width=147,height=50`。
7. `tap "点赞" --platform harmony` 成功通过 host layout 解析文本 bounds `[853,2720][924,2761]`，并提交坐标点击 `x=889,y=2741`。
8. 点击后 `screenshot --platform harmony` 成功保存 after 截图，尺寸仍为 `1308x2880`。
9. 点击后 `wait --platform harmony --text "点赞"` 一次轮询命中，证明 target 在点击后仍可通过 layout 观测。
10. 点击后重新执行 `ax --platform harmony` 成功保存 after layout artifact。首次并发抓 after layout 时 `uitest dumpLayout` 曾 30s timeout，单独重试后成功，说明真实环境下 `dumpLayout` 与其他采集并发时可能存在短时占用。
11. `observe tree --platform harmony` 成功输出统一 observation JSON，`sources[0].name=host-layout`，`runtime-tree` 因未提供 runtime base URL 标记 unavailable，`webview-provider` 因未注册 provider 标记 unavailable。
12. `observe tree` 在 `--max-nodes 80` 下返回 `partial=true`、`nodeCount=80`，其中 2 个疑似 Web 节点标记 `candidateOnly=true`，缺失能力包含 `webview.dom` 与 `webview.bridge-call`。
13. `node resolve --platform harmony --text console --all` 成功解析当前可见节点，返回 `ok=true`、`matchCount=1`、`node.text=console`、`node.source=host-layout`、`candidateOnly=false`，bounds 为 `x=168,y=690,width=147,height=50`。
14. 曾出现一次把两条 `node resolve` 并发写入同一 artifact 的污染文件，最终证据以串行重跑后的 `20260522-harmony-host-node-resolve-console-real-v02.json` 为准。真实 Harmony `uitest dumpLayout` / host layout 采集应串行执行，避免 timeout 或 stdout artifact 交错。

## 已知边界

本轮按用户确认执行了真实点击，但 host action 成功仍只代表点击命令已提交。业务侧是否完成“点赞”需要业务 runtime/provider、服务端状态或页面内部 bridge 进一步验证；P0 host-only 只能用 fresh layout / screenshot 证明点击后页面仍可观测。

## 结论

真实 emulator 上 P0 host-side 观测和执行链路成立：TritonKit CLI 能通过 HDC 获取当前页面 layout、识别 Web 容器、保存截图、通过 host layout 等待可见文本，并按文本解析 bounds 后提交坐标点击。该验证不依赖业务替换 `Web(...)`，符合 Host + Runtime first 的 P0 边界。

新增的 `observe tree` 与 `node resolve` 真实 smoke 进一步证明：即使没有 Harmony embedded runtime 和 Web provider，CLI 也能用 host layout 读取当前可见节点、给出 Web candidate 边界，并解析可点击/可定位目标；但 P0 仍不能声明 DOM、JS 或页面 bridge 可用。

## 隐私说明

layout 与 screenshot artifact 可能包含业务页面私有 UI 内容；公开 issue、PR 或外部报告中只能引用脱敏摘要，不应直接附带原始 artifact。
