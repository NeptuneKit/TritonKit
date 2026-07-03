# 20260521 50-Round AI CLI Embedded SDK Loop

## 流程

本文件按用户指定流程执行 50 轮：

1. 设想场景。
2. 设计命令和数据。
3. 调研方案。
4. 可行则进入执行测试。
5. 暂不可行则记录到头脑风暴池。

本轮目标不是一次写完 50 个功能，而是把 AI 通过 `triton` CLI 直连 iOS embedded SDK 的能力上限拆成 50 个可验证场景。每轮都必须明确它提升的是观察、解释、执行、验证还是复盘能力。

状态说明：

- `test-now`：基于当前代码或 mock server 可立即测试。
- `research-first`：必须先完成技术调研，再写失败测试或实现。
- `brainstorm`：方向有价值，但不进入当前 P0/P1，实现前需要单独 space 或后续决策。

## 50 轮执行表

| 轮次 | 闭环能力 | 设想场景 | 命令和数据设计 | 调研方案 | 状态 | 测试或归档 |
| --- | --- | --- | --- | --- | --- | --- |
| 01 | 观察 | AI 第一次连接 App，需要知道 embedded SDK 是否启用 | `triton runtime manifest --json`；数据含 `platform/transport/enabled/sdkVersion/capabilities/limits/redaction` | 调研 `TKMessage` 新 request、Release no-op shape、schema/capabilities 暴露 | research-first | 进入 S0；先写 `technical-research-ai-cli-sdk-boundary-v01.md` |
| 02 | 观察 | AI 在没有 App 连接时需要知道下一步 | `triton capabilities --json`、`triton plan --json`；输出 server/target/runtime 状态和 nextAction | 盘点现有 bootstrap 契约是否足够表达 embedded SDK 缺失 | test-now | `docs-linhay/scripts/verify-cli-bootstrap.sh` |
| 03 | 解释 | AI 需要区分 embedded 能力和 host-side 能力 | `triton capabilities --json` 增加 `runtimeScope=embedded|host-side|unsupported` | 调研现有 command schema 字段是否足够，不足则新增 capability taxonomy | research-first | 进入 S0 |
| 04 | 解释 | AI 调用系统级动作时必须得到明确拒绝 | `triton press home --json` 返回 `unsupported_runtime_scope` 和 host-side hint | 调研现有 `press` unsupported envelope 是否要从 input result 升级为统一 error code | test-now | `verify-intent-cli-smoke.sh` 覆盖 press 基线；新增能力另写 schema 测试 |
| 05 | 复盘 | AI 需要知道 CLI 发出的每条 SDK request | `triton ledger --limit 100 --jsonl`；数据含 request type、source command、elapsedMs、result/error | 调研 ring buffer 存储位置、隐私字段、内存上限 | research-first | 进入 S4 |
| 06 | 观察 | AI 需要知道 App 身份和构建信息 | `triton debug state app --json`；数据含 bundle id、display name、version/build、locale、uptime | 调研 `Bundle`、`ProcessInfo`、`Locale`、memory footprint 公开 API | research-first | 进入 S1 |
| 07 | 观察 | AI 需要知道当前 scene/window | `triton debug state scene --json`；数据含 activationState、keyWindow、safeArea、orientation、window count | 调研 iOS 13+ scene API、多窗口、screen scale、安全区 | research-first | 进入 S1 |
| 08 | 观察 | AI 需要知道当前页面位置 | `triton debug state route --json`；数据含 top controller、presented stack、navigation title、selected tab | 调研 UINavigationController、UITabBarController、UISplitViewController、UIHostingController 边界 | research-first | 进入 S1 |
| 09 | 观察 | AI 要知道输入焦点在哪里 | `triton debug state responder --json`；数据含 firstResponder oid/class/frame/text traits | 调研 first responder 遍历、secure text、editable 状态 | research-first | 进入 S1 |
| 10 | 解释 | AI 点击失败时要知道目标是否 disabled | `triton attrs --oid <oid> --groups control --json`；数据含 enabled/selected/highlighted/actions | 调研 UIControl state、target/actions 安全输出边界 | research-first | 进入 S1 |
| 11 | 解释 | AI 填表前要知道输入框属性 | `triton attrs --groups text --json`；数据含 text length、placeholder、secure、keyboardType、returnKeyType | 调研 UITextField/UITextView 公开 API 与 redaction | research-first | 进入 S1 |
| 12 | 解释 | AI 需要知道 segment 可选项 | `triton attrs --groups control --json`；数据含 segment titles、selectedSegmentIndex | 调研 UISegmentedControl title/image/null title 边界 | research-first | 进入 S1 |
| 13 | 解释 | AI 需要知道开关状态 | `triton attrs --groups control --json`；数据含 `isOn` | 调研 UISwitch state 和 valueChanged 派发一致性 | research-first | 进入 S1/S3 |
| 14 | 解释 | AI 需要知道 slider/stepper 范围 | `triton attrs --groups control --json`；数据含 min/max/value/step | 调研 UISlider/UIStepper value API 和浮点格式 | research-first | 进入 S1/S3 |
| 15 | 解释 | AI 需要知道 scroll 是否还能滚动 | `triton attrs --groups scroll --json`；数据含 contentSize/contentOffset/insets/canScroll | 调研 UIScrollView adjustedContentInset、方向判断、分页 | research-first | 进入 S1/S3 |
| 16 | 观察 | AI 需要表格/列表可见 cell 摘要 | `triton attrs --groups collection --json`；数据含 visible index paths、cell text summary | 调研 UITableView/UICollectionView 公开 API，避免私有 cell 内省 | research-first | 进入 P1 |
| 17 | 观察 | AI 需要 App 内弹窗状态 | `triton debug state route --include-alerts --json`；数据含 UIAlertController title/actions | 调研只处理 App 内 UIAlertController，系统权限弹窗继续 unsupported | research-first | 进入 P1 |
| 18 | 观察 | AI 需要一次最小快照 | `triton snapshot --include app,scene,route,ax,geometry --json` | 调研 snapshot DTO、include 参数、各 artifact capturedAt | research-first | 进入 S2 |
| 19 | 观察 | AI 需要截图元数据但不一定要图片 | `triton snapshot --include screenshot-metadata --json` | 调研 screenshot dataRef/base64 与 metadata-only 的边界 | research-first | 进入 S2 |
| 20 | 解释 | AI 要知道快照是否过期 | snapshot 每个 artifact 带 `freshness`、cache state、target connection state | 调研现有 evidence freshness 复用方式 | research-first | 进入 S2/S4 |
| 21 | 解释 | 快照过大时 AI 仍要可用 | `snapshot` 输出 `truncated/skipped/limits` | 调研 payload budget、节点上限、字段截断策略 | research-first | 进入 S2 |
| 22 | 验证 | AI 需要比较操作前后状态 | `triton snapshot diff before.json after.json --json` | 当前不适合 P0，先评估是否用外部 jq/agent diff 足够 | brainstorm | 头脑风暴池 B01 |
| 23 | 执行 | AI 只聚焦输入框不写内容 | `triton focus "用户名" --json`；返回 target/strategy | 调研复用 `find` selector 到 `UIResponder.becomeFirstResponder()` | research-first | 进入 S3 |
| 24 | 执行 | AI 写入普通文本 | `triton set-text "用户名" "alice" --json`；数据含 clear+insert result | 调研是否复用 clear+type，还是新增原子 SDK action | research-first | 进入 S3 |
| 25 | 执行 | AI 写入密码但不泄露明文 | `triton set-text "密码" "$PASSWORD" --secure --json`；只回显 length/redacted | 调研 secure 参数贯穿 CLI、HTTP、ledger、evidence | research-first | 进入 S3/S4 |
| 26 | 执行 | AI 选择分段控件 | `triton select-segment "协议" "HTTP" --json` | 调研 title/index 选择、重复标题、valueChanged 派发 | research-first | 进入 S3 |
| 27 | 执行 | AI 设置开关 | `triton set-switch "记住我" on --json` | 调研 UISwitch 幂等设置、toggle、valueChanged | research-first | 进入 S3 |
| 28 | 执行 | AI 提交输入框 | `triton submit "搜索" --json` | 调研 UITextField returnKey、delegate、primaryActionTriggered 的公开触发方式 | research-first | 进入 S3/P1 |
| 29 | 执行 | AI 设置 slider | `triton set-slider "音量" 0.75 --ratio --json` | 调研 ratio/absolute value、bounds、valueChanged | research-first | 进入 S3/P1 |
| 30 | 执行 | AI 控制 stepper | `triton stepper "数量" increment --json` | 调研 stepValue/min/max/target action | research-first | 进入 S3/P1 |
| 31 | 执行 | AI 向下滚动一页 | `triton scroll "列表" --direction down --amount page --json` | 调研 scroll selector、contentOffset clamp、动画禁用 | research-first | 进入 S3 |
| 32 | 执行 | AI 滚动到目标文本 | `triton scroll-to-visible "退出登录" --json` | 调研可见树无法包含 offscreen cell 时的策略和限制 | research-first | 进入 S3/P1 |
| 33 | 执行 | AI 等 UI 短暂稳定 | `triton wait-idle --timeout 2 --json` | 调研 runloop/layout/animation 检测，明确不代表业务完成 | research-first | 进入 S3 |
| 34 | 解释 | AI 遇到重复文本时要消歧 | `triton find "hello" --all`、`tap --index`、`--within`、`--at` | 已有基础意图解析和 mock smoke，可作为新 selector 的复用基线 | test-now | `verify-intent-cli-smoke.sh` |
| 35 | 解释 | AI 点击静态标题不能假成功 | `triton tap "添加连接" --json` 应返回不可操作原因 | 复用现有 UIControl action 判断；新语义命令也要保留失败解释 | test-now | 真实 App smoke 已有，后续纳入 S5 |
| 36 | 解释 | AI 需要知道目标隐藏或祖先隐藏 | `find/tap` 不应命中 hidden ancestor 下文本 | 已有 mock smoke 覆盖 hidden hierarchy fallback | test-now | `verify-intent-cli-smoke.sh` |
| 37 | 验证 | AI 操作后等待业务文本出现 | `triton wait --text "登录成功" --timeout 15 --json` | 已有 wait/assert 基线；新 snapshot/state 可作为更强验证输入 | test-now | 现有 CLI tests + 后续 harness |
| 38 | 验证 | AI 断言文本不存在 | `triton assert text-not-exists "错误" --json` | 已有 assert 基线；后续补 state/snapshot artifact | test-now | Swift shared/UI assertion tests |
| 39 | 复盘 | AI 捕获完整证据包 | `triton capture --case <case> --output <dir.tritonevidence> --json` | 已有 capture/evidence；后续新增 snapshot/state/ledger artifact | test-now | 现有 evidence tests；新 artifact 待实现 |
| 40 | 复盘 | AI 只导出当前 UI archive | `triton export --format archive --output case.triton` | 已有 archive；后续 snapshot 可复用部分结构 | test-now | 现有 export/archive tests |
| 41 | 复盘 | AI 失败时分类原因 | error envelope 增加 `phase=observe|select|execute|verify|boundary` | 调研错误 taxonomy，不要破坏现有 code | research-first | 进入 S4 |
| 42 | 复盘 | AI 需要 action 耗时 | 所有语义命令返回 `elapsedMs` | 调研 CLI elapsed 与 SDK elapsed 的边界，ledger 保存哪一个 | research-first | 进入 S4 |
| 43 | 验证 | ComplexHarness 覆盖新表单页 | 新增 username/password/segment/switch/submit/status | 调研 harness 扩展位置和脚本证据命名 | research-first | 进入 S5 |
| 44 | 验证 | ComplexHarness 覆盖重复文本 | 两个同 label button，验证 `--index/--within/--at` | 已有 mock smoke，真实 harness 后续补 | test-now | `verify-intent-cli-smoke.sh` 先覆盖 mock |
| 45 | 验证 | Overloaded 安全 smoke 验证真实表单 | 用现有安全 smoke，不触发系统弹窗路径 | 调研是否需要新增新命令前的 baseline 证据 | test-now | `verify-overloaded-triton-smoke.sh` 需要真实 App 环境 |
| 46 | 观察 | SwiftUI hosting 页面 route 可解释 | `state route` 至少输出 UIHostingController，不反射私有 SwiftUI tree | 调研 SwiftUI 边界和不可承诺清单 | research-first | 进入 S1/S5 |
| 47 | 观察 | App 内 UIAlertController 可解释 | `state route --include-alerts` 输出 title/actions | 调研只处理 App 内弹窗，权限弹窗 excluded | research-first | 进入 P1 |
| 48 | 解释 | 系统权限弹窗遮挡时明确中断 | `ax/snapshot` 返回 `runtime_ui_interrupted` hint | 已有部分系统中断经验；需要纳入 manifest/capabilities 边界 | research-first | 进入 S0/S5 |
| 49 | 观察 | 业务主动暴露登录态和 feature flags | `triton provider state --json` 或 snapshot include `debug-state` | 默认不采集；必须 opt-in provider API 草案 | brainstorm | 头脑风暴池 B02 |
| 50 | 观察 | 业务主动暴露网络摘要 | `triton provider network --json`；只含 redacted host/path/status/duration | 默认不 hook；必须 opt-in wrapper/interceptor | brainstorm | 头脑风暴池 B03 |

## 可立即执行的测试队列

当前无需新增生产代码即可执行的验证：

1. `docs-linhay/scripts/verify-cli-bootstrap.sh`
2. `docs-linhay/scripts/verify-intent-cli-smoke.sh`
3. `swift test --filter TritonKitSharedTests`

其中 `verify-cli-bootstrap.sh` 覆盖无 server 时的 `version/schema/plan/doctor/capabilities/status` 机器可读行为；`verify-intent-cli-smoke.sh` 用 mock server 覆盖意图解析、重复文本、隐藏祖先、`tap/type/press` 等当前基线。

需要真实 App 或 simulator 连接的验证暂不自动执行：

1. `docs-linhay/scripts/verify-complex-harness.sh`
2. `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`

### 本轮基线执行结果

执行时间：2026-05-21。

| 命令 | 结果 | 结论 |
| --- | --- | --- |
| `docs-linhay/scripts/verify-intent-cli-smoke.sh` | 通过 | 当前 mock server 能覆盖意图解析、重复文本、隐藏祖先、`tap/type/press`、schema 默认输出等已实现基线。 |
| `swift test --filter TritonKitSharedTests` | 通过，Swift Testing 60 个测试通过 | Shared DTO、input、observation、assertion、evidence、schema、host adapter 等当前模型基线通过。 |
| `TRITON_PORT=19432 docs-linhay/scripts/verify-cli-bootstrap.sh` | 未通过 | 环境前提不满足：本机默认 `127.0.0.1:19421` 已有 `triton` server 监听，裸 `triton` 直接连到当前 App；脚本预期 server unavailable。需停止 PID `62859` 或在脚本中避免裸命令使用默认端口后重跑。 |

### S0 runtime manifest 执行结果

执行时间：2026-05-21。

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| Shared DTO | 已实现 | `TKRuntimeManifestResponse`、`TKRuntimeCapabilityDetail`、`TKRuntimeLimits`、`TKRuntimeRedactionPolicy` |
| Request type | 已实现 | `TKRequestType.runtimeManifest` 与 `TKCLICommandRequest(type: "manifest")` 映射 |
| Embedded handler | 已实现 | DEBUG 返回 `debugDefault` manifest；Release disabled 路径返回 no-op manifest shape |
| CLI | 已实现 | `triton runtime manifest --json` |
| Schema/capabilities | 已实现 | `triton schema --command runtime --json` 暴露 `runtime-manifest`；`capabilities` 暴露 `runtime-manifest` |
| Mock smoke | 已通过 | `verify-intent-cli-smoke.sh` 新增 mock `runtimeManifest` 响应与 schema 断言 |

## 头脑风暴池

| ID | 来源轮次 | 想法 | 暂不执行原因 | 重新评估条件 |
| --- | --- | --- | --- | --- |
| B01 | 22 | `triton snapshot diff before.json after.json --json` | P0 可先由 AI 或 jq 比较 JSON；内置 diff 会增加 CLI 复杂度 | snapshot DTO 稳定后，真实回归中多次需要统一 diff shape |
| B02 | 49 | App-defined debug state provider | 涉及业务语义、脱敏、provider API 和 Release no-op，不能默认采集 | P0 CLI/SDK 通道稳定后，另建 provider API 切片 |
| B03 | 50 | Network breadcrumbs opt-in provider | 默认 hook 网络风险高，可能改变业务行为或泄露数据 | 业务愿意显式接入 wrapper/interceptor，并给出字段 allowlist |

## 下一步

1. 先补 R0 调研文件：`technical-research-ai-cli-sdk-boundary-v01.md`。
2. 对 `verify-cli-bootstrap.sh` 和 `verify-intent-cli-smoke.sh` 做一次当前基线验证。
3. 基线通过后，进入 S0 的失败测试设计：manifest/capabilities/schema。
