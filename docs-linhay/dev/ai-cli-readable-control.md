# AI CLI Readable Control

## 决策

TritonKit 首期不需要 Web 端。AI agent 的读取与控制入口收敛到 CLI 进程暴露的机器可读 HTTP 契约，以及 serve 进程的 stdin 快捷命令。

1. iOS App 与 CLI 继续使用 WebSocket 双向通信，用于 `ping`、`appInfo`、`hierarchy` 等控制消息。
2. AI agent 通过 `GET /status` 读取连接状态，通过 `POST /command` 下发控制命令。
3. CLI 收到 hierarchy payload 后保存最新快照，AI agent 通过 `GET /hierarchy/latest` 读取完整 JSON。
4. 不提供 `/ui`、`/events` 或浏览器 SSE 渲染，避免把首期能力分散到人类 Web 展示层。

## 接口

- `GET /status`：返回 `connected` 与 `latestHierarchyAvailable`。
- `GET /targets`：返回当前可调试 target 列表；`triton serve` 支持多个 embedded runtime WebSocket 同时连接。
- `POST /command`：请求体为 `{"type":"ping","target":"<target-id>"}`、`{"type":"appInfo","target":"<target-id>"}` 或 `{"type":"hierarchy","target":"<target-id>"}`；成功返回请求 `id` 和 `type`。
- `POST /request`：请求体为 `{"type":"<requestType>","payload":"...","target":"<target-id>"}`；会等待 iOS 端按 request id 返回 payload，适合 `attrs`、`object`、`input` 等同步读取/控制。
- `POST /input`：请求体直接使用 Baguette 风格 input payload，例如 `{"type":"tap","x":120,"y":240}`；成功或失败都返回 `TKInputResult` JSON。
- `GET /hierarchy/latest?target=<target-id>`：返回指定 target 最近一次 hierarchy JSON；尚未收到 hierarchy 时返回 `404`。
- `POST /data` 与 `GET /data/:id`：保留为二进制数据通道。
- `ws://host:19421/`：保留为 iOS 与 CLI 的控制通道。

## CLI 命令

### CLI 能力进入原则

后续从 ai-phone、Harness、XcodeBuildMCP 等参考项目吸收能力时，默认按以下标准决定是否进入 `triton` CLI：

1. AI agent 在一次回归中需要直接观察、准备、执行、验证或归档。
2. 能力需要稳定 JSON/JSONL 输出，供上层自动决策。
3. 动作或结果需要进入 `.tritonevidence`、`.tritonplan` 或 command ledger。
4. 它能替代裸 `xcrun`、`hdc`、`adb`、`plutil` 等不稳定人读命令。
5. 无 Web/Wails、无运维大盘时仍应可复跑。

不满足这些条件、且更偏后台调度、数据库、消息队列、权限、多租户或大盘展示的能力，不进入 CLI 首期。CLI 可以提供 `status/list/submit/cancel/fetch/test` 这类 agent 入口，但后台状态机归 `triton serve` 或部署配置负责。

- `triton serve`：启动本地控制服务。
- `triton --version` / `triton version --format json`：读取 CLI 版本、schema version 与默认 host/port。
- `triton status --format json`：读取本地控制服务状态；成功态也返回 `ok/serverReachable/runtime/connected/latestHierarchyAvailable/activeHierarchyAvailable/hierarchyCacheState/targetConnectionState/targetCount` envelope，用于区分当前连接状态与 stale hierarchy cache。
- `triton doctor --format json`：诊断 server、target、runtime 与能力状态；即使 server 不可达也输出机器可读诊断并以 0 退出。
- `triton capabilities --format json`：输出当前 runtime 能力矩阵，说明哪些命令可用、哪些需要连接 target、哪些因 embedded runtime 边界 unsupported。
- `triton schema --format json`：输出机器可读 CLI 契约，包括命令参数、默认值、依赖条件、runtime scope、退出码语义、示例、成功/失败 shape；`--command input` 可读取 NDJSON action 字段级 schema。
- `triton runtime manifest --format json`：通过 CLI 读取 embedded SDK runtime manifest、platform、transport、DEBUG/Release enabled 状态、SDK version、capabilities、payload limits 与 redaction policy。默认经由本机 `triton serve` 和已连接 target；验证独立 embedded HTTP runtime（例如 Harmony SDK demo server）时可用 `--runtime-base-url http://127.0.0.1:<port>` 直连。
- `triton state app|scene|route|responder --format json`：读取 App identity/environment、UIWindowScene/window、UIViewController route/container、first responder/text input traits，或在 Harmony provider 已注册时读取 App 主动上报的 scene/route/responder 语义。iOS 默认只使用公开 UIKit/Foundation API；SwiftUI 私有 tree、系统窗口、剪贴板和文本内容默认不采集。独立 embedded HTTP runtime 可用 `--runtime-base-url` 直连。
- `triton snapshot --include app,scene,route,ax,geometry --format json`：通过 embedded runtime 返回一次聚合 App 内快照，包含 include 列表、app/scene/route/responder/geometry/ax/screenshot metadata、artifacts、skipped 与 truncation。它是 agent 决策输入，不替代写文件的 `capture/evidence`；独立 embedded HTTP runtime 可用 `--runtime-base-url` 直连。
- `triton webview list|current|current-url|call|events --format json`：读取当前 WebView provider 元数据、解析当前 URL、执行页面显式 allowlist bridge、或读取页面事件 buffer。iOS 端的 `webview list/current/current-url` 直接读取当前可见 `WKWebView` metadata；`call` 只能调用页面或 App 显式注册的 allowlist 方法，不能退化成任意 JavaScript eval；`events` 只读页面主动上报的结构化事件。Harmony 未注册 WebView provider 时只保留 host-side layout/candidate 边界，不能声明 DOM、JS 或 bridge 可用。
- `triton route assert-current-url <expected-url> --format json`：断言当前 WebView provider URL，支持 `--ignore-query`。匹配返回 `status=pass`；不匹配返回 `status=fail`、expected/actual、hint 并以非 0 退出；没有 WebView provider URL 时返回 `webview_provider_unavailable`，不把 AX/WebKit 容器伪装成 URL 可用。
- `triton focus <selector> --format json`、`triton set-text <selector> <text> --secure --format json`、`triton select-segment <selector> <title|index> --format json`、`triton set-switch <selector> on|off|toggle --format json`：语义动作入口，默认先复用 `find/tap` 的 selector 解析与 `--index/--within/--at` 消歧，再向 embedded runtime 发送 `semanticAction`。使用 `--runtime-base-url` 时直接把 selector 和动作参数交给 App provider，适合 Harmony 等由业务侧实现语义动作的 runtime。返回 `strategy/targetOID/targetClassName/elapsedMs/redaction`，让 agent 不必用脆弱的坐标链表达表单操作。
- `triton ledger --limit 50 --jsonl`：读取 embedded runtime 最近 request/action/error ring buffer。每行是 `TKRuntimeLedgerEntry`，包含 request type、action、ok、elapsedMs、errorCode、message 与 redaction；secure input 不写入明文。独立 embedded HTTP runtime 可用 `--runtime-base-url` 直连。
- `triton plan --format json`：根据当前 server/target 状态输出下一步计划；server 不可达时返回 `nextStep=start-server` 与 `error.nextAction`，连接态返回观察、动作和 archive 导出的推荐序列。
- `triton sim list --format json`：通过 host-side `xcrun simctl list devices available --json` 列出 simulator，输出 `sim:<udid>` target、runtime、platform、state、isBooted 与 source。
- `triton sim use <udid> --format json`：将 workspace 默认 simulator 写入 `.triton/host-defaults.json`，后续可作为 session defaults 的本地状态来源。
- `triton sim boot <udid> --format json`、`triton sim boot <udid> --wait --jsonl`、`triton sim shutdown <udid|booted> --format json`：首批 simulator lifecycle 入口，`--wait --jsonl` 输出 boot 轮询进度，失败时返回稳定 Triton error envelope。
- `triton sim screenshot --simulator <udid|booted> --output <path> --format json`：采集 host-side simulator framebuffer 截图，不依赖 embedded runtime。
- `triton app list --simulator <udid|booted> --user-only --format json`：读取已安装 App 列表，输出 bundle id、display name、version、application type、bundle/data/group container 等结构化字段。
- `triton app info --bundle-id <id> --simulator <udid|booted> --format json`：读取单个已安装 App 元数据；当 `simctl appinfo` 对缺失 bundle 只回显 `CFBundleIdentifier` 时，归一为 `app_info_not_available`。
- `triton app install --app <path.app> --simulator <udid|booted> --format json`、`triton app uninstall --bundle-id <id> --simulator <udid|booted> --confirm --format json`、`triton app launch --bundle-id <id> --format json`、`triton app terminate --bundle-id <id> --format json`：App 生命周期首批入口，返回 host action envelope；`uninstall` 必须显式 `--confirm`，业务就绪仍需继续用 `status/wait/find/assert/prefs` 验证。
- `triton app open-url <url> --simulator <udid|booted> --format json`：提交 deep link 或 URL 到 simulator；该命令只证明 URL 已提交，业务完成需继续用 `wait/find/assert` 或 preferences 验证。若目标 App 已接入 DEBUG embedded runtime，可追加 `--wait-ready --snapshot --snapshot-include app,scene,route,ax,geometry --max-ax-nodes <n>`，让单次输出同时包含 host action、runtime readiness 和 app/route/AX snapshot 摘要。
- `triton app container --bundle-id <id> --kind data --format json`：读取 simulator App container path。
- `triton app prefs get <key> --bundle-id <id> --format json`、`triton app prefs dump --bundle-id <id> --format json`：读取 App preferences plist，避免 agent 解析 `plutil -p` 人读文本。
- `triton app prefs set <key> <json-value> --bundle-id <id> --format json`：向 iOS Simulator App data container 中的 preferences plist 写入一个 property-list compatible JSON 值，支持 string/bool/int/double/array/object，拒绝 `null`，输出 `previousValue/newValue/plistPath/restartAdvice`。同一 plist 的多 key 设置应串行执行，避免并发写入产生最后写入覆盖。
- `triton xcode discover --path . --format json`：发现 `.xcworkspace`、`.xcodeproj` 与 `Package.swift` 候选，作为未知 Apple repo 的入口；多候选时返回 candidates，不暴露 XcodeBuildMCP tool 名。
- `triton xcode use --workspace <path>|--project <path> --scheme <scheme> --configuration Debug --simulator <udid> --format json`：写入 repo-local `.triton/host-defaults.json`，同时保留 `triton sim use` 的默认 simulator。
- `triton xcode status --format json` / `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --format json`：诊断本机 `xcodebuild`、Swift build service 和 `xctest` 占用；`status` 返回 best-effort PID、workspace/project、scheme、destination、DerivedData 与 elapsed，`wait-idle` 超时返回 `xcode_not_idle` 和 blocking PIDs。
- `triton xcode schemes/settings/build/test/run --format json|--jsonl`：封装 `xcodebuild -list -json`、`-showBuildSettings -json`、`build`、`test` 与 build/install/launch 复合流程；长任务使用 JSONL progress 加最终 summary envelope，大型 workspace 可用 `--timeout <seconds>` 放宽超时。`--jsonl` 会输出 invocation、stdout/stderr samples、heartbeat 和 summary，并带 stdout/stderr log path 与 byte count，便于 agent 判断是真卡住还是仍有输出。
- `triton xcode run --jsonl` 只证明 build/install/launch 已提交，业务就绪仍必须继续用 `triton status/wait/find/assert/screenshot/evidence` 验证。
- `triton smoke ios --simulator booted --bundle-id <bundle-id> --open-url <url> --wait-text <text> --assert-text <text> --screenshot <png> --evidence <dir.tritonevidence> --format json`：一命令 iOS real-project smoke 编排入口，顺序提交 host open-url、等待 embedded runtime ready/text、执行断言、采集 simulator screenshot 并写 evidence。host action ack 只算 step 提交成功，整体 pass 必须由 wait/assert/evidence 证明。
- `triton device doctor --platform harmony --format json`：只读探测 HarmonyOS NEXT / DevEco Emulator 的 HDC/Emulator 工具路径、版本摘要和 P0 能力，不保存真实 UI、layout、日志正文或设备文件。
- `triton device list --platform harmony --format json`：通过 host-side `hdc list targets -v` 列出 HDC target，输出 `harmony:<target>`、`target/state/transport/isConnected/source`；`Offline` target 保留在列表中，但不进入默认候选。
- `triton device use --platform harmony --target <target> --format json`：解析一个 `Connected` HDC target；多 `Connected` 且未指定 target 时返回 `error.code=ambiguous_target` 与候选提示。
- `triton device wait-ready --platform harmony --target <target> --format json`：轮询 `param get bootevent.boot.completed`，只接受 `true` 为 ready，超时返回 `device_not_ready`，所有 host 命令都带 timeout 和 `sourceCommand`。
- `triton device runtime-url --platform harmony --target <target> --probe-manifest --format json`：为 Harmony embedded HTTP runtime 准备 host-side `hdc fport tcp:<local> tcp:<remote>`，返回可直接传给 `--runtime-base-url` 的 `baseURL`，并可立即探测 `/v2/runtime/manifest`。默认 host-access embedded runtime 端口为 `28767`，可用 `--local-port` / `--remote-port` 调整；`18765` 保留为 demo UI 中 device-to-host gateway fallback 端口，不能作为 host 直连 runtime 默认值；`--no-forward` 只打印 URL，不改变 HDC 端口映射。
- `triton app inspect --platform harmony --bundle <bundle> --format json`：通过 HDC `bm dump -n` 读取 Harmony App 元数据摘要。
- `triton app install --platform harmony --hap <path.hap> --format json`：通过 HDC `install -r` 安装 debug-signed HAP；返回 host action envelope，结果只代表安装命令成功。
- `triton app launch --platform harmony --bundle <bundle> --ability <ability> --format json`：通过 HDC `aa start` 启动 Harmony Ability，结果只代表启动命令已提交，仍需截图、AX 或日志验证业务状态。
- `triton app open-url --platform harmony --bundle <bundle> --ability <ability> <url> --format json`：通过 HDC `aa start -a <ability> -b <bundle> -U <url>` 提交 Harmony deep link；仍需后续 `wait/ax/screenshot` 验证业务完成。
- `triton app terminate --platform harmony --bundle <bundle> --format json`：通过 HDC `aa force-stop` 停止 Harmony App。
- `triton ax --platform harmony --output <path> --format json`：执行 `uitest dumpLayout`，解析 `DumpLayout saved to:<remote>` 并 `file recv` 到本地 layout artifact；JSON 只返回 artifact 路径与 source commands，不内联真实 UI 内容。
- `triton wait --platform harmony --text <text> --timeout <seconds> --format json`：轮询 Harmony layout 中的 `attributes.text`；支持 `--text/--exists/--gone`，成功或超时都输出机器可读结果。
- `triton tap <text> --platform harmony --format json`：读取 Harmony layout，按 `attributes.text` 找到第一个节点，解析 `[x1,y1][x2,y2]` bounds 后用中心点执行 `uitest uiInput click x y`；也支持 `--x/--y` 或 `--at x,y` 直接坐标点击。
- `triton screenshot --platform harmony --output <path.jpeg> --format json`：通过 HDC `snapshot_display -f /data/local/tmp/<name>.jpeg` 截图再 `file recv` 到本地；artifact 可能包含真实 UI 数据，公开前必须检查和脱敏。
- `triton smoke harmony --target <hdc-target> --bundle <bundle> --ability <ability> --open-url <url> --wait-text <text> --tap-text <text> --post-tap-wait-text <text> --screenshot <jpeg> --evidence <dir.tritonevidence> --format json`：一命令 Harmony host-side smoke 编排入口，顺序执行 device wait-ready、app inspect、ability/deep-link launch、layout text wait、可选 text tap、post-tap wait、layout/screenshot artifact 和 evidence manifest。真实 HDC target 不可用时返回 `target_offline` 或 `device_not_ready`，不能用 fake smoke 代替真实业务 pass。
- Harmony DEBUG-only 内置采集器当前只固化共享 JSON 契约，不是已实现 CLI 入口。契约包含 `TKHarmonyCollectorManifest`、`TKHarmonyCollectorConfiguration`、`TKHarmonyCollectorSnapshot`、App/Page 状态、redaction status 和 screenshot metadata；Release 配置必须 `enabled=false` 且 capabilities 为空。
- `triton list --format json`：列出可调试 target。
- iOS Simulator embedded runtime target id 采用 `triton:ios-simulator:<SIMULATOR_UDID>`；`TKTargetSummary` 同时暴露 `simulatorUDID`。`--target` 可传完整 target id，也可直接传 simulator UDID。只有一个 runtime target 时 `triton:local` 会自动选择；多个 runtime target 同时连接时，默认 `triton:local` 返回 `error.code=ambiguous_target`，要求显式传 `--target`，避免并行模拟器误控。
- `triton inspect --target triton:local --format json`：查看 target 摘要。
- `triton hierarchy --target triton:local --format tree|json`：读取 hierarchy。
- `triton nodes --target triton:local --format text|json`：列出 hierarchy 节点摘要。
- `triton node --target triton:local --oid <oid> --format text|json`：读取单个节点摘要。
- `triton attrs --target triton:local --oid <layerOid> --format text|json`：实时读取 layer 属性组。
- `triton object --target triton:local --oid <oid> --format text|json`：实时读取对象 class chain 与地址。
- `triton export --target triton:local --output <path>`：导出 hierarchy JSON；当 `--format archive` 或输出扩展名为 `.triton`、`.tritonkit`、`.archive`、`.lookinside` 时，导出自描述 archive。
- `triton evidence --output <dir.tritonevidence> --format json`：导出 agent 回归证据包目录，固定写入 `manifest.json`，并按 `--include` 采集 `status/list/version/hierarchy/ax/screenshot/geometry/archive` 等 artifact；当前 embedded runtime 不支持的 `logs` 会进入 `manifest.skipped`，不静默忽略。`triton evidence inspect <dir.tritonevidence> --format json` 只读取 manifest，不重新连接 runtime。
- `triton evidence summary <dir.tritonevidence> --format json`：离线读取 evidence manifest 并输出 artifact count、sensitive count、skipped count、target、CLI version、artifact metadata 和建议的 redaction 命令，不内联截图、完整日志或私有 UI 内容。
- `triton evidence redact <dir.tritonevidence> --profile ios-private --output <redacted.tritonevidence> --format json`：写出可公开转交的 redacted evidence。非敏感 artifact 会复制并标记 `included`；截图、AX、hierarchy、geometry、archive、logs 等敏感 artifact 写成 `redacted/<kind>.json` 占位并标记 `redacted`。
- `triton capture --case <case> --output <dir.tritonevidence> --format json`：一站式回归证据包入口，默认采集 `status/list/version/hierarchy/ax/screenshot/geometry/archive`。
- `triton assert text-exists|text-not-exists <text> --format json`：执行 UI 文本断言；支持 `--role`、`--count`、`--min-count`、`--max-count`、`--within x,y,width,height`，返回 matches、sample、target/cache freshness 和失败原因。失败时会返回 nearestText 与 suggestedCommands，帮助 agent 先 `find --all` 或采集 snapshot 再继续排查。
- `triton record --output <file.tritonplan> --format json`：生成可编辑 replay plan 模板；首期不是交互式真实录制，不捕获终端历史或全局输入事件。
- `triton plan inspect <file.tritonplan> --format json`：离线读取 `.tritonplan` 摘要，返回 schema version、变量、step count、actions 和 target metadata。
- `triton replay <file.tritonplan> --format json`：按 `.tritonplan` 复跑短 smoke 流程；支持 `--dry-run`、`--var key=value`、`--var key-env=ENV_NAME`，步骤覆盖 `tap/paste/type/clear/wait/screenshot/evidence`，secure 步骤只回显 `<redacted:length>`。
- `triton find "HTTP"`：按用户意图解析可见文本、AX label、identifier、value 或 segmented option title，只返回目标来源、策略、oid、layer、frame 与将执行的 input request；默认 JSON，`--format text` 可切换为人读输出。同文案多目标时使用 `triton find "hello" --all` 获取 `candidates[].index/frame/targetOID`；已知目标点位时可用 `triton find "hello" --at x,y` 只保留包含该点的候选。
- `triton wait --text "我的" --timeout 15 --format json`：等待异步 UI 条件，支持 `--text`、`--gone`、`--exists --role`、`--idle`、`--hierarchy-change --since latest` 和安全谓词 `--predicate 'text.exists("console") && !text.exists("登录")'`；成功或超时都返回 `TKWaitResult`，包含 `elapsedMs/pollCount/timedOut/lastObservedTextSample/match`，超时以非 0 退出。
- `triton tap "HTTP"`：意图优先点击入口；调用方不需要区分 AX、hierarchy、坐标、oid 或 segmented option。默认选择第一个候选；同文案多目标优先用 `--at x,y` 按候选 frame 包含点消歧，也可用 `--index <n>` 按 `find --all` 的序号点击，或用 `--within x,y,width,height` 限定区域。仍保留 `--x/--y`、`--oid`、`--ax-oid`、`--ax-label` 作为诊断和精确控制入口；无文本时也可用 `triton tap --at x,y` 直接坐标点击。文本解析失败时 JSON error 会带 nearestCandidates、candidateCount 与 suggestedCommands。
- `triton swipe --target triton:local --start-x <x> --start-y <y> --end-x <x> --end-y <y>`：对命中的 `UIScrollView` 调整 `contentOffset`。
- `triton type <text>` / `triton type --text <text>`：向当前 first responder 或 `--oid` 指定的 `UIKeyInput` 写入文本。
- `triton paste "console"`：向当前 first responder、`--oid`、`--at x,y` 或 `--x/--y` 命中的输入框精确插入文本；`--secure` 只回显 `insertedLength` 与 redaction 状态，不回显原文。
- `triton clear`：清空当前 first responder、`--oid`、`--at x,y` 或 `--x/--y` 命中的输入框。
- `triton press <button>` / `triton press --button <button>`：保留设备按钮契约；embedded runtime 当前返回 unsupported。
- `triton geometry --target triton:local --format json`：读取当前可见 window 的 bounds、safe area、scale 与 orientation。
- `triton ax --target triton:local --format json`：读取当前 App 内安全可操作控件索引树。
- `triton hit --target triton:local --at <x,y> --format json`：按坐标命中最深 UI 节点，并返回中心点；`--x/--y` 保持兼容。
- `triton screenshot --target triton:local --output <path>`：输出当前 App 截图；embedded runtime 使用 UIKit 截图，后续 host-side adapter 可替换为 simulator framebuffer。
- `triton input --target triton:local --format json --summary --strict < gestures.ndjson`：批量读取 Baguette 风格 NDJSON 动作，每行返回一行 `TKInputResult`；`--summary` 输出最终 `{ok,actionCount,failedCount}`，`--strict` 在任一 action 失败时以非 0 退出。

面向 AI agent 的 JSON 入口统一支持 `--json` alias；`screenshot --json` 等价于 `--metadata`，用于在写出 PNG 后额外输出机器可读截图元数据。

## 边界

CLI/HTTP 是 AI 自动化控制入口；Web/Wails 不参与首期闭环。后续如果需要 UI，也应只消费只读 DTO，不能先于 CLI/HTTP 定义业务控制能力。

WebView 是 CLI 的一部分，但仍必须遵循 provider 边界：iOS 侧优先拿 metadata，再通过 allowlist bridge 读事件或执行业务动作；Harmony 侧没有 provider 时只能退回 host layout，不能把 Web 容器误报成可执行 DOM/JS 页面。

## 已知取舍

首期 hierarchy builder 使用有限深度和子节点上限，保证 smoke payload 适合 WebSocket 与 JSON 快照读取。后续需要完整树、增量更新或节点分页时，再单独扩展 CLI/HTTP 契约。

`attrs` 与 `object` 通过 `/request` 复用 WebSocket 请求/响应 id，属于实时读取；`nodes` 与 `node` 基于最新 hierarchy snapshot，适合 AI 先定位 oid。`export` 支持两类产物：`.json` 保持纯 hierarchy snapshot；archive 是单文件 JSON，包含 `schemaVersion`、`exportedAt`、`target`、`hierarchy`、`geometry`、`accessibility` 与内联 base64 screenshot。archive 不是 LookInside 原生归档格式；`.lookinside` 扩展名当前只作为便携 archive 自动推断入口，后续如需与 LookInside App 原生兼容，需要单独定义转换层。`evidence` 则面向测试报告和 GitHub issue 附件，首期采用目录包而不是 zip：`manifest.json` 记录 `formatVersion`、`artifacts[]`、`skipped[]`、target identity、connection/cache state、CLI version 和每个 artifact 的 freshness，artifact 路径均相对证据包目录。

`doctor`、`capabilities` 与 `runtime manifest` 是 AI 的首选探测入口。无服务时 `doctor/capabilities` 返回 `ok=false`、`serverReachable=false`、`error.code=server_unavailable`、启动 hint 和 `error.nextAction`，但进程退出码保持 0，方便上层读取诊断。`runtime manifest` 需要已连接 embedded target；失败时返回稳定 error envelope，成功时返回 SDK manifest、capabilities、limits 与 redaction policy。`capabilities` 还暴露 host-side `host-device`、`harmony-device-doctor`、`harmony-device-list`、`harmony-device-wait-ready`、`harmony-app-install`、`harmony-app-open-url`、`harmony-ax`、`harmony-wait-text`、`harmony-tap-text` 和 `harmony-screenshot`，这些能力不依赖 embedded runtime。普通动作命令如 `status --format json` 与 `list --format json` 在连接失败时返回同一 `{ok:false,error:{code,message,endpoint,hint,nextAction?}}` envelope，并以非 0 退出，方便 shell 流水线阻断。

`schema` 是 AI 的首选规划入口，不依赖 server。`schema --format json` 返回全部已实现命令的命令级 schema；`schema --command input --format json` 返回 NDJSON action schema，包含 `tap`、`swipe`、`type`、`button` 的 required/optional 字段、字段类型、enum、`oneOfRequired`、`coordinateSpace` 与 example；`schema --command device --format json` 返回 Harmony host adapter 的 doctor/list/use/wait-ready 参数，`schema --command app|webview|route|ax|wait|tap|screenshot --format json` 返回 simulator、WebView URL/assert 和 Harmony smoke adapter 的 host-side 参数、成功 shape 和失败 shape，`schema --command smoke --format json` 返回 `smoke ios` 的 one-command summary / failure shape。坐标统一为 window points，与 `geometry`、`ax`、`hit` 返回的 frame 坐标一致；Harmony host-side 坐标来自 `uitest dumpLayout` 的 bounds。

Host-side adapter 使用 `riskLevel`、`requiredConfig` 和 execution policy 做审计与客观运行配置校验，不再使用交互式 `requiresConfirmation` gate。缺少 target、artifactDir、redaction policy、timeout 或 audit record 这类客观配置时应返回 machine-readable blocked/error；风险等级本身不打断长自动化。

Harmony 有两条明确分层：host-side adapter 使用 HDC/DevEco 工具完成设备、App、UI、截图和日志自动化；未来 embedded collector 只在业务 App DEBUG 包内提供 App 内快照增强。两者的 `platform` 都是 `harmony`，但 transport 分别是 `hdc` 与 `embedded-websocket`，不能把 collector manifest 当成设备级能力。

`plan` 是 AI 的状态恢复入口，不依赖 server 存活。它会把当前能力诊断收敛为 `nextStep` 和有序 `steps[]`：无 server 时第一步是可直接执行的 `triton serve --host 127.0.0.1 --port 19421`；server 与 target 已就绪时第一步是 `observe`，推荐 `geometry`、`ax`、`wait`、`hit`、`input --summary --strict`、`screenshot` 与 `export --format archive`。`error.nextAction` 的 `command` 不带 `triton` 前缀，调用方可用 `["triton", command] + args` 直接组装进程参数。

`record/replay` 是 AI 的可复跑 smoke artifact 入口。`.tritonplan` 首期 schema version 为 1，核心字段为 `name`、`variables`、`target` 和 `steps[]`；步骤中的字符串支持 `${name}` 占位。`replay --dry-run` 不连接 runtime，只检查变量并输出每一步将执行的命令摘要；真实 `replay` 默认在首个失败步骤停止，整体结果返回 `{ ok, dryRun, planName, stepCount, executedCount, failedStepIndex?, elapsedMs, steps[] }`。`record` 当前只生成模板，不能宣称已录制真实用户操作。

`assert` 是 agent 回归判断入口，适合把“截图里看起来没有 stale 文本”改成机器可读结论。重复文本场景优先用 `--role`、`--count` 或 `--within` 收敛范围；例如右侧二级列表区域可以用 `triton assert text-not-exists "Qinghai" --within 180,120,190,500 --json` 验证 stale 子项不存在。`assert` 使用当前 runtime AX tree，不能处理系统弹窗或跨 App 内容。

`input --json` 输出真正的 JSONL：每个 action 结果是一行 compact JSON，`--summary` 的最终汇总也是一行 compact JSON。AI 自动化推荐显式使用 `--summary --strict --fail-fast`。这样既能继续消费每个 action 的细粒度 ack，又能用 summary 和退出码判断整批动作是否可靠完成；`--fail-fast` 还能避免前一步 tap 失败后，后续 `type` 继续写入旧 first responder。

所有会先解析 target 的主要 runtime 命令在 JSON 模式下都会把 `/targets` 解析失败收敛为同一 `{ok:false,error:{code,message,endpoint,hint,nextAction?}}` envelope；这覆盖 `inspect/hierarchy/nodes/node/attrs/object/export/wait/tap/swipe/type/press/geometry/ax/hit/screenshot/input` 等入口。运行时 HTTP 非 2xx 响应若本身已经是 Triton error envelope，CLI 在 `--json` 下会原样输出该 envelope 并退出非 0，避免把 `runtime_ui_interrupted` 等机器错误码揉进 ArgumentParser 文本错误。

## 本地化

CLI 支持人读输出语言切换：`--language en|zh`、`--lang en|zh`、`TRITON_LANGUAGE` 或 `TRITON_LANG`。语言切换只影响 text 输出、错误提示和 plan/schema 的人读标签；JSON 字段名、`error.code`、命令名和机器契约保持英文稳定。

`triton version --json` 会返回当前语言和支持语言，例如 `language=zh`、`supportedLanguages=["en","zh"]`，便于 agent 发现能力但不需要根据语言解析不同 JSON shape。

本地参数校验在 JSON 模式下也输出机器可读 envelope；输入动作命令默认就是 JSON，例如 `triton tap` 缺少目标选择器时返回 `error.code=validation_failed`，stderr 保持为空，方便 agent 直接解析 stdout。

HTTP 管理 API 的错误响应同样使用 `{ok:false,error:{code,message,endpoint,hint}}`。例如无 hierarchy 时 `/hierarchy/latest` 返回 `hierarchy_unavailable`，无连接 target 时 `/input` 返回 `target_not_found`，多 embedded target 且未指定目标时返回 `ambiguous_target`。

## 复杂测试目标

iOS Demo 现在内置 `ComplexHarness`，用于替代过于简单的单按钮 smoke。它同时覆盖嵌套 stack、状态标签、`UIButton`、`UISwitch`、`UISegmentedControl`、`UISlider`、`UIStepper`、`UITextField`、`UITextView` 与横向 `UIScrollView` carousel。所有关键控件都通过 `ComplexHarness*` accessibility identifier 暴露给 `triton ax`。

Demo 同时注册 `tritonkitdemo://` URL scheme，作为 `triton smoke ios` 的正向 open-url 入口。该 scheme 只用于让 iOS Simulator 将 Demo 拉到前台；业务 ready 仍必须由 embedded runtime 的 `wait` / `assert` 和 evidence target 状态证明，不能把 `simctl openurl` 的 host ack 当作 smoke 成功。

embedded runtime 的 `tap` 会对常见公开 UIKit 控件执行确定性动作：`UITextField`/`UITextView` 聚焦，自定义 `UIKeyInput`/可成为 first responder 的编辑 surface 可通过坐标 tap 聚焦，`UISwitch` toggle，`UISegmentedControl` 按坐标选择或按 oid 循环下一项，`UISlider` 按坐标设置或按 oid 递增，`UIStepper` 按坐标增减或按 oid 递增。普通未知 `UIControl` 只在能发现 `.primaryActionTriggered` 或 `.touchUpInside` target-action 时才返回成功并异步派发；没有可派发 action 的控件返回失败，避免导航标题等 no-op `UIControl` 造成假成功。这让 AI agent 可以只通过 `ax -> input --summary --strict --fail-fast -> wait -> ax/screenshot/export` 完成复杂状态回归。

`UISegmentedControl` 的 valueChanged 触发不再直接依赖 `UIControl.sendActions(for:)` 的内部枚举，而是先稳定写入 `selectedSegmentIndex`，再在下一次 main queue tick 对已注册 target/action 调用 `UIApplication.sendAction`。这避免 Triton 侧 dispatch 与 App 侧重建 cell 时出现额外的 UIControl 内部重入。Overloaded 的 `HTTP`/`HTTPS` 协议切换冒烟还暴露了 App 自身 `SKPublished` setter 内同步 sink 读取同一属性的 Swift 独占访问问题；测试用 App 已在本地把 `scheme` 变化后的 `updateModels()` 延后一拍执行。

普通未知 `UIControl` 的 target-action 派发也改为下一轮 main queue 异步执行，`tap` 只确认“已派发”而不等待 App 业务 action 完成。这个边界来自 Overloaded `导入连接` 场景：业务 action 会读取剪贴板并触发 iOS 系统权限弹窗；如果 runtime 在 request handler 内同步派发 action，控制通道会把业务弹窗阻塞误报为 HTTP 408。现在 `triton tap "导入连接"` 会立即返回 `ok=true,message=Dispatched UIControl.touchUpInside`，随后若系统弹窗挡住 App 内 UIKit tree，`triton ax` 会返回 `error.code=runtime_ui_interrupted`，hint 明确说明 embedded runtime 不能 inspect 或点击 SpringBoard/CoreSimulatorBridge 弹窗。相对地，`triton tap "添加连接"` 这类命中导航标题的 no-op control 会返回 `ok=false,message=Target UIControl has no primary or touchUpInside action` 或不可操作错误。

复杂目标的可复跑端到端验收脚本是 `docs-linhay/scripts/verify-complex-harness.sh`。它要求 `triton serve` 已运行且 iOS Demo 已连接，随后自动执行 `ax` identifier 断言、七步 NDJSON input 控制、summary 状态断言、截图元数据校验和 archive 内容校验。

Overloaded 真实 App 的可复跑 smoke 脚本是 `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`。默认覆盖安全场景：`添加` 入口、导航标题 `添加连接` 不产生假成功、`HTTP/HTTPS` segment 意图点击与端口联动、`名称` 输入框聚焦和 `type` 写入、disabled `验证连接` 明确失败、静态标题 `连接信息` 不误触业务动作、重复文本 `导入连接` 优先命中 row control。全新安装首次出现 App 内相册权限引导时，脚本会先点击 `稍后再说` 进入主流程。会触发系统剪贴板权限弹窗的 `导入连接` 动作默认不执行；需要尝试验证系统中断错误时显式设置 `TRITON_OVERLOADED_INCLUDE_SYSTEM_PROMPT=1`。由于 iOS 模拟器可能记住 pasteboard 权限状态，即使重装 App 也不一定出现系统弹窗；此时脚本记录 `system-prompt-skipped.txt` 并通过。若必须把“未出现系统弹窗”视为失败，额外设置 `TRITON_OVERLOADED_REQUIRE_SYSTEM_PROMPT=1`。

本轮继续体验挖掘得到的优先能力缺口：

1. `ax --with-hierarchy` 能证明 AX 与 hierarchy 可以稳定映射，但 Overloaded 复杂表单中同名 AX 节点会出现多份候选；读状态和断言需要去重、当前可见候选标记或 ambiguity 解释。
2. `hit` 对自定义 row button 已能提升到可操作父控件，但缺少 raw hit、actionable target、提升路径、reason 和 suggested input；这些字段能让 agent 在坐标失败时自动修正。
3. `attrs` 仍主要是 class/layout/layer 样式。后续应补 Accessibility/Responder/Control groups，例如 label/value/identifier、firstResponder、UIButton title/enabled/selected、UITextField text/placeholder/secure、UISegmentedControl selectedSegmentIndex/segments、UIScrollView canScroll。
4. `type` 已支持 `triton type <text>`，并保留 `type --text <text>` 兼容入口；`press` 已支持 `triton press home`，旧的 `press --button home` 保持兼容。
5. 首批显式语义动作已落地：`focus`、`set-text`、`select-segment`、`set-switch`。后续仍缺 `submit`、`set-slider`、`stepper`、`scroll-to-visible` 和 `wait-idle`，这些能力继续按公开 UIKit API 与 harness 验证推进。

意图解析有两个优先级约束：`UITextField`/`UITextView` 这类输入控件默认用 frame center 坐标点击，避免 AX oid 因 cell 重建后弱引用失效；hierarchy 文本 fallback 必须继承祖先可见性，隐藏 cell 或 alpha 为 0 的子 label 不能作为 `HTTP/HTTPS` 这类可点击选项候选。

意图优先 CLI 的轻量 mock smoke 脚本是 `docs-linhay/scripts/verify-intent-cli-smoke.sh`。它不依赖 iOS App，覆盖唯一 target 时省略 `--target` 的 `triton tap "HTTP"`、输入框 `名称` 使用坐标策略、`triton type "hello"` 位置参数、动作命令默认 JSON、`tap/find --at` 点位消歧、`tap/hit/paste/clear --at` 坐标简写、`press home` 位置参数、隐藏祖先中的 `HTTPS` 不参与 hierarchy 文本命中、找不到文本时的 JSON 错误 envelope、HTTP 408 `runtime_ui_interrupted` 的稳定透传，以及 `snapshot/focus/set-text/select-segment/set-switch/ledger --jsonl` 的 agent-facing schema 与输出 shape。

无服务 bootstrap 契约的可复跑验收脚本是 `docs-linhay/scripts/verify-cli-bootstrap.sh`。它要求 `19421` 无监听进程，随后验证 `version/schema/plan/doctor/capabilities/status` 的 JSON shape、退出码与 `nextAction`。

`ax` 的 identified actionable 节点同时暴露 `targetOID` 与 `viewOID`，两者当前都可作为 `input.targetOID` 使用。`layerOID` 不在 `ax` 中批量输出，避免在复杂 UIKit/Accessibility 场景里把 payload 放大并触发连接不稳定；需要 layer 属性时继续走 `nodes -> attrs --oid <layerOid>`。

设备控制参考 Baguette 的动作模型，但当前 TritonKit 运行在被测 App 进程内，不具备 host-side SimulatorKit / HID 权限。第一阶段只承诺公开 UIKit API 可验证的 in-app 控制；系统按钮、全局键盘、跨 App home/app-switcher 等能力需要后续新增 macOS host-side adapter。

观察能力也遵循 embedded runtime 边界：`ax` 基于当前 App 内 UIKit view tree 生成安全控件索引树，只为 `UIControl`、`UILabel`、`UITextField`、`UITextView`、`UIScrollView`、`UIImageView` 等可读/可操作类型生成节点，避免递归读取 SwiftUI/UIKit 私有视图导致 App 断连；它不是 SpringBoard 或跨 App 的系统级 AX tree。`UICollectionView` / `UITableView` 这类 scroll 容器会继续展开可见子树，并把 cell 内可读文本挂到容器 `children` 下；无 label、无 identifier、无子节点的空 `UIImageView` / 空 label 不进入 AX 输出，避免复杂页面提前耗尽节点预算。`screenshot` 是当前 App window 截图，不是 host-side framebuffer。
