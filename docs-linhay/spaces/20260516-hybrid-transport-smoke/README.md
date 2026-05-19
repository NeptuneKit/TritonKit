# 20260516 Hybrid Transport Smoke

## 背景

最新需求是将 TritonKit 推进到可由 AI agent 与自动化脚本稳定控制的首个闭环版本：iOS 端自动连接 macOS CLI，CLI 在同一端口提供 WebSocket 控制通道与 HTTP 二进制数据通道，并能完成可复跑的 smoke 验收。

## 目标

1. macOS CLI 可以构建并启动混合服务。
2. iOS TritonKit library 可以构建，并能响应 `ping`、`appInfo`、`hierarchy` 等基础控制消息。
3. CLI 默认端口与项目治理规则一致，示例 App 与 CLI 默认值保持一致。
4. SwiftPM 测试在 macOS runner 上可复跑，不因 UIKit 依赖导致整包失败。
5. CLI 提供机器可读状态、命令与 hierarchy 快照接口，供 AI agent 自动化读取和控制。
6. 需求状态、验证命令与风险写入文档和记忆。
7. CLI 命令面向 LookInside 的常用调试工作流靠拢，支持 `list`、`inspect`、`hierarchy` 与 `export`。
8. 参考 Baguette 的设备输入模型，补齐首批 CLI 可控动作契约，并明确 in-app 控制与 host-side HID 的边界。
9. 补齐 AI 自动化闭环所需的结构化观察、命中测试、截图、几何信息与批量动作入口。

## 范围

本期只收口 CLI + HTTP transport + iOS WebSocket client + 示例 App 的 smoke 链路；不恢复 Wails/Web UI，不提供浏览器页面。

AI agent 通过 CLI 进程暴露的 JSON 契约读取状态、下发命令和获取 hierarchy 快照。WebSocket 仍保留为 iOS App 与 CLI 的双向控制通道。

## BDD 验收场景

### 场景 1：macOS CLI 默认启动混合服务

- Given 开发者在仓库根目录构建 `tritonkit`
- When 运行 CLI 默认 `serve`
- Then 服务监听项目约定端口 `19421`
- And `GET /health` 返回 `200 OK`
- And `POST /data` 可返回 JSON 数据引用
- And `GET /data/:id` 可取回原始二进制内容

### 场景 2：SwiftPM 测试可在 macOS runner 上复跑

- Given 当前机器没有 UIKit for macOS SwiftPM library 构建环境
- When 运行 `swift test`
- Then 包测试通过
- And UIKit 相关能力只在 `canImport(UIKit)` 的平台参与编译

### 场景 3：iOS 示例 App 与 CLI 默认值一致

- Given CLI 默认端口为 `19421`
- When 启动示例 App
- Then UI 默认连接 `127.0.0.1:19421`
- And 日志展示的 WebSocket URL 与实际 route `/` 一致

### 场景 4：iOS library 可在 Simulator 构建

- Given 示例工程引用本地 TritonKit package
- When 在 iOS Simulator destination 构建 `TritonKitDemo`
- Then 构建成功
- And `TritonKit` 收到首条 WebSocket 消息后进入 `connected` 状态。

### 场景 5：AI agent 通过 CLI/HTTP 读取和控制 hierarchy

- Given CLI 已启动并暴露 `/status`、`/command` 与 `/hierarchy/latest`
- When iOS Demo 连接 CLI 并返回 hierarchy payload
- Then `/status` 返回连接状态和是否存在最新 hierarchy
- And `POST /command` 可下发 `ping`、`appInfo` 与 `hierarchy`
- And `/hierarchy/latest` 返回最新 hierarchy JSON

### 场景 6：命令行具备 LookInside 类似的目标调试工作流

- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 运行 `triton list --format json`
- Then 输出机器可读 target 列表，包含 target id、连接状态、app name、bundle id、device 与 OS
- When 运行 `triton inspect --target triton:local --format json`
- Then 输出指定 target 的完整摘要
- When 运行 `triton hierarchy --target triton:local --format json`
- Then 输出最新 hierarchy JSON
- When 运行 `triton hierarchy --target triton:local --format tree`
- Then 输出适合终端阅读的 tree
- When 当前只有一个 target 且运行 `triton hierarchy --format tree`
- Then CLI 自动选择唯一 target，输出同样的 tree，不要求传入 `--target`
- When 运行 `triton hierarchy --format tree`
- Then tree 默认隐藏 `UITransitionView`、`UIDropShadowView` 这类低信号 UIKit 包装视图，但保留其子树
- When 运行 `triton hierarchy --format tree --no-hide-noise`
- Then tree 输出完整原始层级中的包装视图，便于需要排查系统容器时使用
- When 页面内容位于 UINavigationController、SwiftUI hosting 或多层容器之下
- Then hierarchy 默认采集深度必须覆盖真实业务子树，不应在 `UILayoutContainerView` 等系统中间容器处截断
- And `triton serve` 必须允许大型 WebSocket hierarchy 帧，避免成熟 App 的完整层级因超过默认 16KB frame 上限而断开连接
- When 运行 `triton export --target triton:local --output /tmp/triton-hierarchy.json`
- Then 写出可复用的 hierarchy JSON 文件
- When 运行 `triton nodes --target triton:local --format json`
- Then 输出 hierarchy 节点摘要列表
- When 运行 `triton node --target triton:local --oid <oid> --format json`
- Then 输出单个节点的 class、frame、hidden、alpha、view oid 与 layer oid
- When 运行 `triton attrs --target triton:local --oid <layerOid> --format json`
- Then 实时返回该 layer 的属性组
- When 运行 `triton object --target triton:local --oid <oid> --format json`
- Then 实时返回该对象的 class chain 与内存地址

### 场景 7：命令行具备 Baguette 风格的输入控制契约

- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 运行 `triton tap --target triton:local --x <x> --y <y> --format json`
- Then CLI 通过机器可读 JSON 返回 tap 是否成功、命中的对象与说明信息
- When 运行 `triton tap --target triton:local --oid <viewOid> --format json`
- Then CLI 可以结合 hierarchy 中的 view oid 对公开可触发的 `UIControl` 执行 in-app tap
- When 运行 `triton swipe --target triton:local --start-x <x> --start-y <y> --end-x <x> --end-y <y> --format json`
- Then CLI 对命中的 `UIScrollView` 执行可验证的 content offset 调整；若命中对象不支持公开滚动控制，则返回 `ok=false`
- When 运行 `triton type --target triton:local --text "hello" --format json`
- Then CLI 对指定或当前 first responder 的 `UIKeyInput` 写入文本；不支持时返回 `ok=false`
- When 运行 `triton press --target triton:local --button home --format json`
- Then CLI 返回明确 unsupported 结果，不伪装成 host-side HID 已完成

### 场景 8：AI agent 具备观察、定位、截图和批量动作闭环

- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 运行 `triton geometry --target triton:local --format json`
- Then 输出机器可读 window bounds、safe area、scale 与 orientation
- When 运行 `triton ax --target triton:local --format json`
- Then 输出安全可操作控件索引树，包含 role、label、value、identifier、frame、enabled、focused、hidden 与 children；首版只为 UIKit 安全控件/文本/滚动区域生成叶子节点，避免递归序列化 SwiftUI/UIKit 私有视图
- When 运行 `triton ax --target triton:local --with-hierarchy --format json`
- Then CLI 按 `AX.viewOID/targetOID -> hierarchy.viewObject.oid` 输出映射结果，包含 hierarchy `layerOID`、class、frame、path、mapped/unmatched 统计，供 agent 在点击前解释命中链路
- When 运行 `triton hit --target triton:local --x <x> --y <y> --format json`
- Then 返回坐标命中的最深 UI 节点，并包含可直接用于 `tap` 的 frame center
- When 运行 `triton tap --target triton:local --ax-oid <oid> --format json` 或 `triton tap --target triton:local --ax-label <label> --format json`
- Then CLI 从当前 AX 树定位目标，并优先使用该 AX 节点的 `targetOID/viewOID` 发起 in-app tap；仅当节点没有 oid 时才回退到 frame center 坐标
- When 运行 `triton tap --target triton:local "HTTP" --format json`
- Then CLI 将文本作为用户意图解析，不要求调用者区分 AX、hierarchy、oid 或 segmented option；解析顺序为 AX 可操作节点、AX label/value、hierarchy 文本节点，命中文本/segment label 时使用其 frame center 发起 tap
- When 运行 `triton find --target triton:local "HTTP" --format json`
- Then CLI 使用与 `tap <文本>` 相同的解析器返回将要执行的目标来源、策略、oid、layer、frame 与 input request，便于冒烟失败时解释意图命中
- And 在 Overloaded 添加连接页中，`triton find "HTTP" --json` 应命中 `UISegmentLabel`，`triton tap "HTTP" --json` 后 `triton ax --json` 应读回 `UISegmentedControl.value="HTTP"`，且 App 不应断开 Triton server 连接
- When 运行 `triton screenshot --target triton:local --output /tmp/triton-shot.png`
- Then 写出当前 App 画面截图
- When 通过 stdin 执行 `triton input --target triton:local --format json < gestures.ndjson`
- Then 每一行动作返回一行 JSON ack，默认不中断后续动作；使用 `--fail-fast` 时遇到 `ok=false` 立即停止

### 场景 9：export 支持可复用自描述 archive

- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 运行 `triton export --target triton:local --format archive --output /tmp/triton-smoke.triton`
- Then 写出单文件 archive，包含 `schemaVersion`、`exportedAt`、`target`、`hierarchy`、`geometry`、`accessibility` 与 `screenshot`
- And archive 内截图使用 base64 内联，避免依赖 `/data/:id` 的临时运行时引用
- When 运行 `triton export --target triton:local --format auto --output /tmp/triton-smoke.triton`
- Then 自动推断为 archive 格式

### 场景 10：AI agent 可稳定诊断服务和能力状态

- Given `triton serve` 未运行
- When 运行 `triton doctor --format json`
- Then 输出 `ok=false`、`serverReachable=false`、`error.code=server_unavailable` 与可执行 hint，并以 0 退出供 AI 读取诊断结果
- When 运行 `triton status --format json`
- Then 输出稳定 `{ok:false,error:{code,message,endpoint,hint,nextAction}}` 并以非 0 退出，不暴露 Foundation 长错误
- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 运行 `triton capabilities --format json`
- Then 输出 `runtime=embedded`，in-app `tap/swipe/type/input/geometry/ax/hit/screenshot/export-*` 为 supported，`press` 明确 unsupported

### 场景 11：AI agent 可读取机器可用的 CLI schema

- Given 不论 `triton serve` 是否运行
- When 运行 `triton schema --format json`
- Then 输出 `schemaVersion`、commands 列表、参数、默认值、输出格式、依赖条件、runtime scope、退出码语义、成功/失败 shape 与示例
- When 运行 `triton schema --command input --format json`
- Then 输出 NDJSON input actions 的字段级 schema，包含字段类型、enum、`oneOfRequired`、坐标语义和示例

### 场景 12：AI agent 可从当前状态生成下一步计划

- Given `triton serve` 未运行
- When 运行 `triton plan --format json`
- Then 输出 `ok=false`、`serverReachable=false`、`nextStep=start-server`、`steps[]` 与 `error.nextAction={command,args,requiresLongRunningProcess}`，并以 0 退出
- Given `triton serve` 正在运行且 iOS Demo 已连接
- When 运行 `triton plan --format json`
- Then 输出 `ok=true`、`nextStep=observe`，并给出 `geometry`、`ax`、`hit`、`input`、`screenshot`、`export archive` 的推荐命令序列

### 场景 13：AI agent bootstrap 契约稳定

- Given 不论 `triton serve` 是否运行
- When 运行 `triton --version` 或 `triton version --format json`
- Then 输出 CLI 版本、`schemaVersion`、默认 host 与默认 port
- Given `triton serve` 正在运行
- When 运行 `triton status --format json`
- Then 成功响应也输出统一 envelope：`ok`、`serverReachable`、`runtime`、`connected`、`latestHierarchyAvailable`、`targetCount`
- Given `triton serve` 正在运行，且 iOS Demo 已连接
- When 通过 stdin 执行 `triton input --format json --summary --strict < gestures.ndjson`
- Then CLI 输出真正 JSONL：每行动作结果是一行 compact JSON，最终 `{ok,actionCount,failedCount}` summary 也是一行 compact JSON；若任一 action 失败，则进程以非 0 退出
- Given `triton serve` 未运行
- When 运行 `docs-linhay/scripts/verify-cli-bootstrap.sh`
- Then 验证 `version/schema/plan/doctor/capabilities/status` 的 JSON shape、退出码与 `nextAction`

### 场景 14：CLI 支持本地化语言切换

- Given 当前机器未启动 `triton serve`
- When 运行 `triton --language zh`
- Then 输出中文人读错误，包含 `服务器不可用` 与启动 `triton serve` 的下一步提示
- When 运行 `TRITON_LANGUAGE=zh triton`
- Then 同样输出中文人读错误
- When 运行 `triton version --language zh --json`
- Then JSON 仍保持机器可读英文字段，并包含 `language=zh` 与 `supportedLanguages=[en,zh]`
- When 运行 `triton --language zh -h` 或 `TRITON_LANGUAGE=zh triton -h`
- Then 根帮助输出中文概览、用法、选项和子命令说明

### 场景 15：复杂 iOS 测试目标可被深度观察和控制

- Given iOS Demo 已启动复杂 UIKit testbed
- When 运行 `triton ax --format json`
- Then 输出包含 `ComplexHarnessStatus`、`ComplexHarnessMode`、`ComplexHarnessSlider`、`ComplexHarnessStepper`、`ComplexHarnessSwitch`、`ComplexHarnessTextField`、`ComplexHarnessTextView`、`ComplexHarnessCarousel`、`ComplexHarnessPrimary`、`ComplexHarnessSecondary` 的可操作索引
- When 对 `ComplexHarnessMode`、`ComplexHarnessSlider`、`ComplexHarnessStepper`、`ComplexHarnessSwitch` 执行 `tap --oid <oid> --format json`
- Then embedded runtime 使用公开 UIKit API 更新控件状态，并在 `ComplexHarnessSummary` 中反映 mode/progress/count/switch/text 状态
- When 对 `ComplexHarnessTextField` 聚焦并执行 `type --text <text> --format json`
- Then 文本写入后 summary 同步更新
- When 对 `ComplexHarnessCarousel` 执行 `swipe --start-x ... --end-x ... --format json`
- Then 横向内容发生可观测位移，`attrs --oid <layerOid> --format json` 可读取更新后的 scroll offset
- When 运行 `triton screenshot --metadata` 与 `triton export --format archive`
- Then 截图和 archive 能保留复杂 testbed 的当前状态，作为回归验收产物
- When 运行 `docs-linhay/scripts/verify-complex-harness.sh`
- Then 自动完成 `ax` identifier 断言、七步 NDJSON input 控制、summary 断言、截图元数据校验和 archive 内容校验

## 当前结论

截至本 space 创建时，本地 `main` 已有一个未推送提交 `b97e4d0`，CLI product 可构建，但 `swift test` 因 UIKit 无条件编译失败，且缺少可复跑测试与文档记录。本期收口目标就是将这些缺口补齐。

## 完成记录

- `swift test` 通过，新增 Swift Testing 覆盖 `TKMessage` 编解码、`TKDisplayItem.flatItems` 与 macOS 非 UIKit fallback。
- `swift build --product triton` 通过。
- CLI HTTP smoke 通过：`GET /health`、`POST /data`、`GET /data/:id`、空 body `400`。
- iOS Simulator `TritonKitDemo` build/run 通过，并与 CLI 完成 `ping`、`hierarchy` 双向交换。
- AI CLI/HTTP smoke 通过：`GET /status` 返回连接状态，`POST /command` 可下发 `hierarchy`，`GET /hierarchy/latest` 返回最新 JSON。
- LookInside 类似 CLI 工作流通过：`triton status --format json`、`triton list --format json`、`triton list --ids-only`、`triton inspect --target triton:local --format json`、`triton hierarchy --target triton:local --format tree`、`triton hierarchy --target triton:local --format json --output /tmp/triton-hierarchy-smoke.json`、`triton nodes --target triton:local --format json`、`triton node --target triton:local --oid 1 --format json`、`triton attrs --target triton:local --oid 2 --format json`、`triton object --target triton:local --oid 1 --format json`、`triton export --target triton:local --output /tmp/triton-export-smoke.json`。
- 已归档 Baguette 参考项目到 `docs-linhay/references/baguette`，并将其设备输入模型收敛为 Triton 的首批 CLI/HTTP input 契约。
- Baguette 风格 input smoke 通过：`triton tap --x 270 --y 300 --format json` 触发 UIKit button；`triton tap --x 100 --y 358 --format json && triton type --text triton-smoke --format json` 聚焦并写入 `UITextField`；`triton swipe --start-x 350 --start-y 390 --end-x 100 --end-y 390 --format json` 将 `UIScrollView.contentOffset` 调整到 `250.0,-0.0`；`triton press --button home --format json` 明确返回 embedded runtime unsupported。
- AI 观察闭环 smoke 通过：`triton geometry --format json` 返回 `402x874`、safe area 与 portrait；`triton ax --format json --output /tmp/triton-ax-smoke.json` 输出 `UIKitSmokeButton`、`UIKitSmokeTextField`、`UIKitSmokeScroll`、`UIKitSmokeSwitch`、`UIKitSmokeStatus`；`triton hit --x 270 --y 300 --format json` 命中 `UIKitSmokeButton`；`triton screenshot --output /tmp/triton-screenshot-smoke.png --metadata` 写出 `402x874` PNG；`triton input --format json < gestures.ndjson` 完成 tap/type/swipe 批量动作。
- XcodeBuildMCP UI 快照确认：`UIKit smoke: 1`、`UIKitSmokeTextField` 值为 `ndjson-smoke`，横向 scroll 内容发生位移。
- Export archive smoke 通过：`triton export --format archive --output /tmp/triton-smoke.triton` 写出自描述 archive，包含 `schemaVersion=1`、`target=triton:local`、hierarchy、geometry、accessibility 与内联 PNG screenshot；`triton export --format auto --output /tmp/triton-auto.triton` 自动推断 archive；`triton export --format auto --output /tmp/triton-auto.json` 仍输出纯 hierarchy JSON。
- Subagent 体验反馈指出无服务时 JSON 错误不稳定；已新增 `triton doctor` 与 `triton capabilities`，并将 `status/list --format json` 的连接失败收敛为 `{ok:false,error:{code,message,endpoint,hint,nextAction?}}`。无服务 smoke 通过：`doctor/capabilities --format json` 输出 `server_unavailable` 且退出 0；`status/list --format json` 输出同一错误 envelope 且退出 1。连接态 smoke 通过：`capabilities --format json` 输出 `runtime=embedded`、`tap=true`、`press=false`。
- 第二、三轮 subagent 体验继续指出 help 仍偏人读；已新增 `triton schema`。Schema smoke 通过：`triton schema --format json` 输出 10 个高频命令 schema；`triton schema --command input --format json` 输出 `tap/swipe/type/button` 的字段类型、enum、`oneOfRequired`、`coordinateSpace=window-points` 与示例；`schema --command tap --format text` 可读。
- 第四轮 subagent 体验指出缺少结构化 recovery action，且 `status` 未进入 schema；已新增 `error.nextAction`、`triton plan`、`status/plan` schema。无服务 smoke 通过：`triton plan --format json/text` 输出 `nextStep=start-server` 与可执行 `serve` action；`triton status --format json` 输出同一 `nextAction` 并以 1 退出。连接态 smoke 通过：`triton plan --format json` 输出 `nextStep=observe` 与观察/动作/export 推荐序列。
- 第五轮 subagent 体验指出 bootstrap 仍需减少特判；已补齐全部已实现命令的 schema、`triton --version`、`triton version --format json`、`status --format json` 成功态 envelope，以及 `input --summary --strict` 的批次 summary 与失败退出语义。
- 已建立复杂 iOS testbed，并将 embedded runtime 的 tap 行为扩展到 `UISegmentedControl`、`UISlider`、`UIStepper`。复杂目标 smoke 通过：`triton ax --json` 发现 `ComplexHarnessStatus/Mode/Slider/Stepper/Switch/TextField/TextView/Carousel/Primary/Secondary` 等节点；identified AX 节点直接暴露 `targetOID/viewOID`；`triton input --json --summary --strict` 完成 mode、slider、stepper、switch、textField、type、carousel swipe 七步动作且 `failedCount=0`；summary 更新为 `mode=Edit progress=60 count=3 switch=on text=complex-oid`；截图与 archive 已生成。为保持 AX payload 稳定，`layerOID` 仍通过 `nodes/attrs` 工作流获取。
- 已补齐 AI 友好的 JSON alias 一致性：`capabilities/inspect/hierarchy/nodes/node/attrs/object/export/tap/swipe/type/press/geometry/hit` 等命令支持 `--json`，`screenshot --json` 等价于输出 metadata；`schema` 同步暴露这些 alias。
- 新增 `docs-linhay/scripts/verify-complex-harness.sh`，将复杂 testbed 的端到端验收固化为可复跑脚本：读取 `ComplexHarness*` AX 节点、生成七步 NDJSON、执行 `input --json --summary --strict`、断言 summary 文本、校验截图与 archive。真实 iOS Demo 验证通过，输出 `/tmp/triton-complex-harness/{ax.json,input.jsonl,screenshot.png,archive.triton}`。
- 已将 `input --json` 改为真正 JSONL compact 输出，便于 agent 流式读取；summary 同样 compact 单行输出。`inspect/hierarchy/nodes/node/attrs/object/export/tap/swipe/type/press/geometry/ax/hit/screenshot/input` 等 runtime 命令在 JSON 模式下若 target 解析失败，会输出统一 JSON error envelope。
- 已补齐 `validation_failed` 本地校验 envelope：`triton tap --json` 缺少 `--oid` 或坐标时 stdout 输出 `{ok:false,error:{code:"validation_failed",...}}`，stderr 为空。HTTP 管理 API 错误也升级为 `{ok:false,error:{...}}`，已验证 `/hierarchy/latest` 的 `hierarchy_unavailable` 与 `/input` 的 `target_unavailable`。
- 新增 `docs-linhay/scripts/verify-cli-bootstrap.sh`，在无服务状态验证 `version/schema/plan/doctor/capabilities/status` 的机器契约、退出码和 `nextAction`；本机验证通过。
- JSONL 改动后复杂 harness 真实 iOS 验证再次通过，`tail -n 1 /tmp/triton-complex-harness/input.jsonl | jq` 可直接读取最终 summary；截图归档为 v04。
- 2026-05-18 按专用模拟器要求新增并使用 `TritonKit Dedicated iPhone 17`（UDID `0333546D-2AC6-4C22-AF01-293E2F4BA5BC`）复跑 iOS 验收。`TritonKitDemo` build/run 成功，`triton status --json` 返回 `connected=true/latestHierarchyAvailable=true/runtime=embedded`，`TRITON_VERIFY_OUT_DIR=/tmp/triton-dedicated-complex-harness docs-linhay/scripts/verify-complex-harness.sh` 通过，最终 summary 为 `mode=Edit progress=60 count=3 switch=on text=complex-script`。
- 2026-05-18 修复本地安装后裸 `triton` 在 server 未启动时泄漏 Foundation `NSURLErrorDomain/LocalDataTask` 的问题。默认 `list` 和 text 模式 target 解析失败现在输出稳定人读错误：`server_unavailable`、endpoint、hint 与 `next: triton serve --host 127.0.0.1 --port 19421`；`--json` 继续输出 `{ok:false,error:{...}}`。
- 2026-05-18 新增 CLI 本地化语言切换：`--language en|zh` / `--lang en|zh` 与 `TRITON_LANGUAGE` / `TRITON_LANG` 环境变量可控制人读输出语言；JSON code 与字段保持英文稳定，`version --json` 暴露当前语言与支持语言。
- 2026-05-18 追加中文 help：`triton --language zh -h` 与 `TRITON_LANGUAGE=zh triton -h` 输出中文根帮助；`triton --language zh help input` 可查看中文子命令帮助。默认英文 ArgumentParser help 保持不变。
- 2026-05-18 补齐单 target 默认解析：runtime 命令在只有一个已连接 target 时可省略 `--target`，例如 `triton hierarchy --format tree`；若未来同时存在多个 target，默认 target 解析会返回 ambiguous 并要求显式传入 `--target <id>`。

## 验收产物

- iOS Demo 截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-demo-connected-after-v01.jpg`
- iOS input 控制后截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-input-control-after-v01.jpg`
- iOS 观察 + 批量控制闭环截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-observation-loop-after-v01.jpg`
- iOS 复杂 testbed 控制后截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-complex-harness-after-v01.png`
- iOS 复杂 testbed `viewOID` alias 打磨后截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-complex-harness-after-v02.png`
- iOS 复杂 testbed 可复跑脚本验证后截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-complex-harness-after-v03.png`
- iOS 复杂 testbed JSONL 与错误契约打磨后截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260516/ios/20260516-ios-complex-harness-after-v04.png`
- iOS 专用模拟器复杂 testbed 复验截图：`docs-linhay/spaces/20260516-hybrid-transport-smoke/screenshots/20260518/ios/20260518-ios-complex-harness-dedicated-after-v01.png`
