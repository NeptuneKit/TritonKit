# AI CLI Readable Control

## 决策

TritonKit 首期不需要 Web 端。AI agent 的读取与控制入口收敛到 CLI 进程暴露的机器可读 HTTP 契约，以及 serve 进程的 stdin 快捷命令。

1. iOS App 与 CLI 继续使用 WebSocket 双向通信，用于 `ping`、`appInfo`、`hierarchy` 等控制消息。
2. AI agent 通过 `GET /status` 读取连接状态，通过 `POST /command` 下发控制命令。
3. CLI 收到 hierarchy payload 后保存最新快照，AI agent 通过 `GET /hierarchy/latest` 读取完整 JSON。
4. 不提供 `/ui`、`/events` 或浏览器 SSE 渲染，避免把首期能力分散到人类 Web 展示层。

## 接口

- `GET /status`：返回 `connected` 与 `latestHierarchyAvailable`。
- `GET /targets`：返回当前可调试 target 列表；首期只有本地连接 target。
- `POST /command`：请求体为 `{"type":"ping"}`、`{"type":"appInfo"}` 或 `{"type":"hierarchy"}`；成功返回请求 `id` 和 `type`。
- `POST /request`：请求体为 `{"type":"<requestType>","payload":"..."}`；会等待 iOS 端按 request id 返回 payload，适合 `attrs`、`object`、`input` 等同步读取/控制。
- `POST /input`：请求体直接使用 Baguette 风格 input payload，例如 `{"type":"tap","x":120,"y":240}`；成功或失败都返回 `TKInputResult` JSON。
- `GET /hierarchy/latest`：返回最近一次 hierarchy JSON；尚未收到 hierarchy 时返回 `404`。
- `POST /data` 与 `GET /data/:id`：保留为二进制数据通道。
- `ws://host:19421/`：保留为 iOS 与 CLI 的控制通道。

## CLI 命令

- `triton serve`：启动本地控制服务。
- `triton --version` / `triton version --format json`：读取 CLI 版本、schema version 与默认 host/port。
- `triton status --format json`：读取本地控制服务状态；成功态也返回 `ok/serverReachable/runtime/connected/latestHierarchyAvailable/activeHierarchyAvailable/hierarchyCacheState/targetConnectionState/targetCount` envelope，用于区分当前连接状态与 stale hierarchy cache。
- `triton doctor --format json`：诊断 server、target、runtime 与能力状态；即使 server 不可达也输出机器可读诊断并以 0 退出。
- `triton capabilities --format json`：输出当前 runtime 能力矩阵，说明哪些命令可用、哪些需要连接 target、哪些因 embedded runtime 边界 unsupported。
- `triton schema --format json`：输出机器可读 CLI 契约，包括命令参数、默认值、依赖条件、runtime scope、退出码语义、示例、成功/失败 shape；`--command input` 可读取 NDJSON action 字段级 schema。
- `triton plan --format json`：根据当前 server/target 状态输出下一步计划；server 不可达时返回 `nextStep=start-server` 与 `error.nextAction`，连接态返回观察、动作和 archive 导出的推荐序列。
- `triton list --format json`：列出可调试 target。
- `triton inspect --target triton:local --format json`：查看 target 摘要。
- `triton hierarchy --target triton:local --format tree|json`：读取 hierarchy。
- `triton nodes --target triton:local --format text|json`：列出 hierarchy 节点摘要。
- `triton node --target triton:local --oid <oid> --format text|json`：读取单个节点摘要。
- `triton attrs --target triton:local --oid <layerOid> --format text|json`：实时读取 layer 属性组。
- `triton object --target triton:local --oid <oid> --format text|json`：实时读取对象 class chain 与地址。
- `triton export --target triton:local --output <path>`：导出 hierarchy JSON；当 `--format archive` 或输出扩展名为 `.triton`、`.tritonkit`、`.archive`、`.lookinside` 时，导出自描述 archive。
- `triton evidence --output <dir.tritonevidence> --format json`：导出 agent 回归证据包目录，固定写入 `manifest.json`，并按 `--include` 采集 `status/list/version/hierarchy/ax/screenshot/geometry/archive` 等 artifact；当前 embedded runtime 不支持的 `logs` 会进入 `manifest.skipped`，不静默忽略。`triton evidence inspect <dir.tritonevidence> --format json` 只读取 manifest，不重新连接 runtime。
- `triton capture --case <case> --output <dir.tritonevidence> --format json`：一站式回归证据包入口，默认采集 `status/list/version/hierarchy/ax/screenshot/geometry/archive`。
- `triton assert text-exists|text-not-exists <text> --format json`：执行 UI 文本断言；支持 `--role`、`--count`、`--min-count`、`--max-count`、`--within x,y,width,height`，返回 matches、sample、target/cache freshness 和失败原因。
- `triton record --output <file.tritonplan> --format json`：生成可编辑 replay plan 模板；首期不是交互式真实录制，不捕获终端历史或全局输入事件。
- `triton plan inspect <file.tritonplan> --format json`：离线读取 `.tritonplan` 摘要，返回 schema version、变量、step count、actions 和 target metadata。
- `triton replay <file.tritonplan> --format json`：按 `.tritonplan` 复跑短 smoke 流程；支持 `--dry-run`、`--var key=value`、`--var key-env=ENV_NAME`，步骤覆盖 `tap/paste/type/clear/wait/screenshot/evidence`，secure 步骤只回显 `<redacted:length>`。
- `triton find "HTTP" --format json`：按用户意图解析可见文本、AX label、identifier、value 或 segmented option title，只返回目标来源、策略、oid、layer、frame 与将执行的 input request。
- `triton wait --text "我的" --timeout 15 --format json`：等待异步 UI 条件，支持 `--text`、`--gone`、`--exists --role`、`--idle`、`--hierarchy-change --since latest` 和安全谓词 `--predicate 'text.exists("console") && !text.exists("登录")'`；成功或超时都返回 `TKWaitResult`，包含 `elapsedMs/pollCount/timedOut/lastObservedTextSample/match`，超时以非 0 退出。
- `triton tap "HTTP" --format json`：意图优先点击入口；调用方不需要区分 AX、hierarchy、坐标、oid 或 segmented option。仍保留 `--x/--y`、`--oid`、`--ax-oid`、`--ax-label` 作为诊断和精确控制入口。
- `triton swipe --target triton:local --start-x <x> --start-y <y> --end-x <x> --end-y <y> --format json`：对命中的 `UIScrollView` 调整 `contentOffset`。
- `triton type --target triton:local --text <text> --format json`：向当前 first responder 或 `--oid` 指定的 `UIKeyInput` 写入文本。
- `triton paste "console" --format json`：向当前 first responder、`--oid` 或 `--x/--y` 命中的输入框精确插入文本；`--secure` 只回显 `insertedLength` 与 redaction 状态，不回显原文。
- `triton clear --format json`：清空当前 first responder、`--oid` 或 `--x/--y` 命中的输入框。
- `triton press --target triton:local --button <button> --format json`：保留设备按钮契约；embedded runtime 当前返回 unsupported。
- `triton geometry --target triton:local --format json`：读取当前可见 window 的 bounds、safe area、scale 与 orientation。
- `triton ax --target triton:local --format json`：读取当前 App 内安全可操作控件索引树。
- `triton hit --target triton:local --x <x> --y <y> --format json`：按坐标命中最深 UI 节点，并返回中心点。
- `triton screenshot --target triton:local --output <path>`：输出当前 App 截图；embedded runtime 使用 UIKit 截图，后续 host-side adapter 可替换为 simulator framebuffer。
- `triton input --target triton:local --format json --summary --strict < gestures.ndjson`：批量读取 Baguette 风格 NDJSON 动作，每行返回一行 `TKInputResult`；`--summary` 输出最终 `{ok,actionCount,failedCount}`，`--strict` 在任一 action 失败时以非 0 退出。

面向 AI agent 的 JSON 入口统一支持 `--json` alias；`screenshot --json` 等价于 `--metadata`，用于在写出 PNG 后额外输出机器可读截图元数据。

## 边界

CLI/HTTP 是 AI 自动化控制入口；Web/Wails 不参与首期闭环。后续如果需要 UI，也应只消费只读 DTO，不能先于 CLI/HTTP 定义业务控制能力。

## 已知取舍

首期 hierarchy builder 使用有限深度和子节点上限，保证 smoke payload 适合 WebSocket 与 JSON 快照读取。后续需要完整树、增量更新或节点分页时，再单独扩展 CLI/HTTP 契约。

`attrs` 与 `object` 通过 `/request` 复用 WebSocket 请求/响应 id，属于实时读取；`nodes` 与 `node` 基于最新 hierarchy snapshot，适合 AI 先定位 oid。`export` 支持两类产物：`.json` 保持纯 hierarchy snapshot；archive 是单文件 JSON，包含 `schemaVersion`、`exportedAt`、`target`、`hierarchy`、`geometry`、`accessibility` 与内联 base64 screenshot。archive 不是 LookInside 原生归档格式；`.lookinside` 扩展名当前只作为便携 archive 自动推断入口，后续如需与 LookInside App 原生兼容，需要单独定义转换层。`evidence` 则面向测试报告和 GitHub issue 附件，首期采用目录包而不是 zip：`manifest.json` 记录 `formatVersion`、`artifacts[]`、`skipped[]`、target identity、connection/cache state、CLI version 和每个 artifact 的 freshness，artifact 路径均相对证据包目录。

`doctor` 与 `capabilities` 是 AI 的首选探测入口。无服务时它们返回 `ok=false`、`serverReachable=false`、`error.code=server_unavailable`、启动 hint 和 `error.nextAction`，但进程退出码保持 0，方便上层读取诊断。普通动作命令如 `status --format json` 与 `list --format json` 在连接失败时返回同一 `{ok:false,error:{code,message,endpoint,hint,nextAction?}}` envelope，并以非 0 退出，方便 shell 流水线阻断。

`schema` 是 AI 的首选规划入口，不依赖 server。`schema --format json` 返回全部已实现命令的命令级 schema；`schema --command input --format json` 返回 NDJSON action schema，包含 `tap`、`swipe`、`type`、`button` 的 required/optional 字段、字段类型、enum、`oneOfRequired`、`coordinateSpace` 与 example。坐标统一为 window points，与 `geometry`、`ax`、`hit` 返回的 frame 坐标一致。

`plan` 是 AI 的状态恢复入口，不依赖 server 存活。它会把当前能力诊断收敛为 `nextStep` 和有序 `steps[]`：无 server 时第一步是可直接执行的 `triton serve --host 127.0.0.1 --port 19421`；server 与 target 已就绪时第一步是 `observe`，推荐 `geometry`、`ax`、`wait`、`hit`、`input --summary --strict`、`screenshot` 与 `export --format archive`。`error.nextAction` 的 `command` 不带 `triton` 前缀，调用方可用 `["triton", command] + args` 直接组装进程参数。

`record/replay` 是 AI 的可复跑 smoke artifact 入口。`.tritonplan` 首期 schema version 为 1，核心字段为 `name`、`variables`、`target` 和 `steps[]`；步骤中的字符串支持 `${name}` 占位。`replay --dry-run` 不连接 runtime，只检查变量并输出每一步将执行的命令摘要；真实 `replay` 默认在首个失败步骤停止，整体结果返回 `{ ok, dryRun, planName, stepCount, executedCount, failedStepIndex?, elapsedMs, steps[] }`。`record` 当前只生成模板，不能宣称已录制真实用户操作。

`assert` 是 agent 回归判断入口，适合把“截图里看起来没有 stale 文本”改成机器可读结论。重复文本场景优先用 `--role`、`--count` 或 `--within` 收敛范围；例如右侧二级列表区域可以用 `triton assert text-not-exists "Qinghai" --within 180,120,190,500 --json` 验证 stale 子项不存在。`assert` 使用当前 runtime AX tree，不能处理系统弹窗或跨 App 内容。

`input --json` 输出真正的 JSONL：每个 action 结果是一行 compact JSON，`--summary` 的最终汇总也是一行 compact JSON。AI 自动化推荐显式使用 `--summary --strict --fail-fast`。这样既能继续消费每个 action 的细粒度 ack，又能用 summary 和退出码判断整批动作是否可靠完成；`--fail-fast` 还能避免前一步 tap 失败后，后续 `type` 继续写入旧 first responder。

所有会先解析 target 的主要 runtime 命令在 JSON 模式下都会把 `/targets` 解析失败收敛为同一 `{ok:false,error:{code,message,endpoint,hint,nextAction?}}` envelope；这覆盖 `inspect/hierarchy/nodes/node/attrs/object/export/wait/tap/swipe/type/press/geometry/ax/hit/screenshot/input` 等入口。运行时 HTTP 非 2xx 响应若本身已经是 Triton error envelope，CLI 在 `--json` 下会原样输出该 envelope 并退出非 0，避免把 `runtime_ui_interrupted` 等机器错误码揉进 ArgumentParser 文本错误。

## 本地化

CLI 支持人读输出语言切换：`--language en|zh`、`--lang en|zh`、`TRITON_LANGUAGE` 或 `TRITON_LANG`。语言切换只影响 text 输出、错误提示和 plan/schema 的人读标签；JSON 字段名、`error.code`、命令名和机器契约保持英文稳定。

`triton version --json` 会返回当前语言和支持语言，例如 `language=zh`、`supportedLanguages=["en","zh"]`，便于 agent 发现能力但不需要根据语言解析不同 JSON shape。

本地参数校验在 JSON 模式下也输出机器可读 envelope，例如 `triton tap --json` 缺少 `--oid` 或坐标时返回 `error.code=validation_failed`，stderr 保持为空，方便 agent 直接解析 stdout。

HTTP 管理 API 的错误响应同样使用 `{ok:false,error:{code,message,endpoint,hint}}`。例如无 hierarchy 时 `/hierarchy/latest` 返回 `hierarchy_unavailable`，无连接 target 时 `/input` 返回 `target_unavailable`。

## 复杂测试目标

iOS Demo 现在内置 `ComplexHarness`，用于替代过于简单的单按钮 smoke。它同时覆盖嵌套 stack、状态标签、`UIButton`、`UISwitch`、`UISegmentedControl`、`UISlider`、`UIStepper`、`UITextField`、`UITextView` 与横向 `UIScrollView` carousel。所有关键控件都通过 `ComplexHarness*` accessibility identifier 暴露给 `triton ax`。

embedded runtime 的 `tap` 会对常见公开 UIKit 控件执行确定性动作：`UITextField`/`UITextView` 聚焦，`UISwitch` toggle，`UISegmentedControl` 按坐标选择或按 oid 循环下一项，`UISlider` 按坐标设置或按 oid 递增，`UIStepper` 按坐标增减或按 oid 递增。普通未知 `UIControl` 只在能发现 `.primaryActionTriggered` 或 `.touchUpInside` target-action 时才返回成功并异步派发；没有可派发 action 的控件返回失败，避免导航标题等 no-op `UIControl` 造成假成功。这让 AI agent 可以只通过 `ax -> input --summary --strict --fail-fast -> wait -> ax/screenshot/export` 完成复杂状态回归。

`UISegmentedControl` 的 valueChanged 触发不再直接依赖 `UIControl.sendActions(for:)` 的内部枚举，而是先稳定写入 `selectedSegmentIndex`，再在下一次 main queue tick 对已注册 target/action 调用 `UIApplication.sendAction`。这避免 Triton 侧 dispatch 与 App 侧重建 cell 时出现额外的 UIControl 内部重入。Overloaded 的 `HTTP`/`HTTPS` 协议切换冒烟还暴露了 App 自身 `SKPublished` setter 内同步 sink 读取同一属性的 Swift 独占访问问题；测试用 App 已在本地把 `scheme` 变化后的 `updateModels()` 延后一拍执行。

普通未知 `UIControl` 的 target-action 派发也改为下一轮 main queue 异步执行，`tap` 只确认“已派发”而不等待 App 业务 action 完成。这个边界来自 Overloaded `导入连接` 场景：业务 action 会读取剪贴板并触发 iOS 系统权限弹窗；如果 runtime 在 request handler 内同步派发 action，控制通道会把业务弹窗阻塞误报为 HTTP 408。现在 `triton tap "导入连接" --json` 会立即返回 `ok=true,message=Dispatched UIControl.touchUpInside`，随后若系统弹窗挡住 App 内 UIKit tree，`triton ax` 会返回 `error.code=runtime_ui_interrupted`，hint 明确说明 embedded runtime 不能 inspect 或点击 SpringBoard/CoreSimulatorBridge 弹窗。相对地，`triton tap "添加连接"` 这类命中导航标题的 no-op control 会返回 `ok=false,message=Target UIControl has no primary or touchUpInside action` 或不可操作错误。

复杂目标的可复跑端到端验收脚本是 `docs-linhay/scripts/verify-complex-harness.sh`。它要求 `triton serve` 已运行且 iOS Demo 已连接，随后自动执行 `ax` identifier 断言、七步 NDJSON input 控制、summary 状态断言、截图元数据校验和 archive 内容校验。

Overloaded 真实 App 的可复跑 smoke 脚本是 `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`。默认覆盖安全场景：`添加` 入口、导航标题 `添加连接` 不产生假成功、`HTTP/HTTPS` segment 意图点击与端口联动、`名称` 输入框聚焦和 `type` 写入、disabled `验证连接` 明确失败、静态标题 `连接信息` 不误触业务动作、重复文本 `导入连接` 优先命中 row control。全新安装首次出现 App 内相册权限引导时，脚本会先点击 `稍后再说` 进入主流程。会触发系统剪贴板权限弹窗的 `导入连接` 动作默认不执行；需要尝试验证系统中断错误时显式设置 `TRITON_OVERLOADED_INCLUDE_SYSTEM_PROMPT=1`。由于 iOS 模拟器可能记住 pasteboard 权限状态，即使重装 App 也不一定出现系统弹窗；此时脚本记录 `system-prompt-skipped.txt` 并通过。若必须把“未出现系统弹窗”视为失败，额外设置 `TRITON_OVERLOADED_REQUIRE_SYSTEM_PROMPT=1`。

本轮继续体验挖掘得到的优先能力缺口：

1. `ax --with-hierarchy` 能证明 AX 与 hierarchy 可以稳定映射，但 Overloaded 复杂表单中同名 AX 节点会出现多份候选；读状态和断言需要去重、当前可见候选标记或 ambiguity 解释。
2. `hit` 对自定义 row button 已能提升到可操作父控件，但缺少 raw hit、actionable target、提升路径、reason 和 suggested input；这些字段能让 agent 在坐标失败时自动修正。
3. `attrs` 仍主要是 class/layout/layer 样式。后续应补 Accessibility/Responder/Control groups，例如 label/value/identifier、firstResponder、UIButton title/enabled/selected、UITextField text/placeholder/secure、UISegmentedControl selectedSegmentIndex/segments、UIScrollView canScroll。
4. `type` 与 `press` 还没有完全意图优先：当前仍需要 `type --text <text>`、`press --button home`。第一版 CLI 重设计可考虑支持 `triton type "hello"`、`triton press home`，保持旧参数作为精确/脚本入口。
5. 输入控制缺少显式语义动作：`clearText`、`setText`、`focus`、`submit`、`selectSegment`、`scrollToVisible` 能减少 “tap 后再 type” 和坐标滚动的不确定性。

意图解析有两个优先级约束：`UITextField`/`UITextView` 这类输入控件默认用 frame center 坐标点击，避免 AX oid 因 cell 重建后弱引用失效；hierarchy 文本 fallback 必须继承祖先可见性，隐藏 cell 或 alpha 为 0 的子 label 不能作为 `HTTP/HTTPS` 这类可点击选项候选。

意图优先 CLI 的轻量 mock smoke 脚本是 `docs-linhay/scripts/verify-intent-cli-smoke.sh`。它不依赖 iOS App，覆盖唯一 target 时省略 `--target` 的 `triton tap "HTTP"`、输入框 `名称` 使用坐标策略、隐藏祖先中的 `HTTPS` 不参与 hierarchy 文本命中、找不到文本时的 JSON 错误 envelope、以及 HTTP 408 `runtime_ui_interrupted` 在 `--json` 下的稳定透传。

无服务 bootstrap 契约的可复跑验收脚本是 `docs-linhay/scripts/verify-cli-bootstrap.sh`。它要求 `19421` 无监听进程，随后验证 `version/schema/plan/doctor/capabilities/status` 的 JSON shape、退出码与 `nextAction`。

`ax` 的 identified actionable 节点同时暴露 `targetOID` 与 `viewOID`，两者当前都可作为 `input.targetOID` 使用。`layerOID` 不在 `ax` 中批量输出，避免在复杂 UIKit/Accessibility 场景里把 payload 放大并触发连接不稳定；需要 layer 属性时继续走 `nodes -> attrs --oid <layerOid>`。

设备控制参考 Baguette 的动作模型，但当前 TritonKit 运行在被测 App 进程内，不具备 host-side SimulatorKit / HID 权限。第一阶段只承诺公开 UIKit API 可验证的 in-app 控制；系统按钮、全局键盘、跨 App home/app-switcher 等能力需要后续新增 macOS host-side adapter。

观察能力也遵循 embedded runtime 边界：`ax` 基于当前 App 内 UIKit view tree 生成安全控件索引树，只为 `UIControl`、`UILabel`、`UITextField`、`UITextView`、`UIScrollView`、`UIImageView` 等可读/可操作类型生成节点，避免递归读取 SwiftUI/UIKit 私有视图导致 App 断连；它不是 SpringBoard 或跨 App 的系统级 AX tree。`UICollectionView` / `UITableView` 这类 scroll 容器会继续展开可见子树，并把 cell 内可读文本挂到容器 `children` 下；无 label、无 identifier、无子节点的空 `UIImageView` / 空 label 不进入 AX 输出，避免复杂页面提前耗尽节点预算。`screenshot` 是当前 App window 截图，不是 host-side framebuffer。
