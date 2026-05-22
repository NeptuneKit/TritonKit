# Real Project Smoke P1

## 背景

本 space 收敛 GitHub issue #12、#15、#17、#18 的下一阶段实现方案。

四个 issue 表面分别是 simulator takeover、Harmony host-side adapter、iOS one-command smoke evidence 和真实项目 iOS 诊断，但它们指向同一个真实项目回归闭环：

```text
prepare host target -> launch/open route -> wait/assert runtime or host state -> capture artifacts -> summarize/redact evidence -> report pass/fail
```

当前 TritonKit 已经有不少底层能力：

- iOS Simulator / App P0 host adapter：`sim list/use/boot/shutdown/screenshot` 与 `app list/info/install/uninstall/launch/terminate/open-url/container/prefs`。
- Xcode P0：`xcode discover/use/schemes/settings/build/test/run`。
- Runtime / action / evidence：`status/list/wait/assert/find/tap/screenshot/capture/evidence/record/replay`。
- Harmony host-side P0/P1 部分能力：`device doctor/list/wait-ready`、`app inspect/launch`、`observe current/tree`、`node resolve`。
- WebView provider metadata 与 allowlist bridge：`webview list/current/call/events`。

缺口不是单个命令，而是跨 host、runtime、evidence 的稳定编排层。

## 关联 issue

| Issue | 角色 | 本 space 处理策略 |
| --- | --- | --- |
| #12 Add comprehensive simulator takeover | Epic | 继续作为 P1+ 能力池；本轮只选真实 smoke 需要的高价值 slice，不默认关闭 |
| #15 Add Harmony host-side smoke adapter commands | Feature | 通过 `smoke harmony` 或等价编排闭环关闭 |
| #17 Add one-command iOS smoke evidence flow | Feature | 通过 `smoke ios` 关闭 |
| #18 Improve real-project iOS smoke diagnostics | Feature bundle | 优先落地 Xcode occupancy、open-url wait snapshot、WebView URL/assert、prefs set、evidence summary/redact、failure diagnostics；剩余项必要时拆 issue |

## 目标

1. 给 AI agent 一个可发现、可复跑、可审计的一命令 smoke 入口。
2. 让 iOS 和 Harmony 真实项目 smoke 使用同一种 JSON summary / artifact manifest / failure envelope。
3. 把 host-side 启动、deep link、runtime wait/assert、WebView URL 检查、截图和 evidence 汇总编成稳定流程。
4. 失败时输出下一步可执行命令，而不是只返回布尔失败。
5. 保持本机 CLI + 本机 simulator/emulator 边界，不新增 Web/Wails UI、远端 agent、设备云或真机默认流程。

## 非目标

1. 不一次性吃完 #12 的全部 simulator takeover epic。
2. 不把 smoke 命令做成内置 LLM agent loop。
3. 不默认做真机、远端调度、多租户服务或 Web 控制台。
4. 不开放任意 WebView JavaScript eval。
5. 不把 host action ack 当作业务成功；业务成功必须由 wait/assert/snapshot/evidence 证明。
6. 不在测试中依赖私有真实 App 标识、截图、日志或账号。

## 产品形态

新增跨平台 smoke namespace：

```bash
triton smoke ios \
  --simulator booted \
  --bundle-id <bundle-id> \
  --open-url "<scheme>://nativejump/<route>" \
  --wait-text "<expected-title>" \
  --assert-text "<expected-subtitle>" \
  --screenshot /tmp/case.png \
  --evidence /tmp/case.tritonevidence \
  --json

triton smoke harmony \
  --target <hdc-target> \
  --bundle <bundle-name> \
  --ability <ability-name> \
  --open-url "<scheme>://nativejump/<route>" \
  --wait-text "<expected-title>" \
  --screenshot /tmp/case.jpeg \
  --evidence /tmp/case.tritonevidence \
  --json
```

`smoke ios` 和 `smoke harmony` 是编排层，不替代底层命令。它们必须把每一步实际调用、耗时、artifact、错误和 next action 写入 summary。

## BDD 验收场景

### 场景一：iOS deep link smoke 成功

- Given iOS Simulator 已 boot，目标 App 已安装，DEBUG runtime 已连接
- When 执行 `triton smoke ios --open-url <url> --wait-text <title> --assert-text <subtitle> --screenshot <png> --evidence <dir> --json`
- Then TritonKit 依次提交 open-url、等待 runtime ready、等待文本、执行断言、采集 simulator screenshot、写入 evidence
- And 输出 `status=pass`、steps、assertions、artifacts 和 redaction summary
- And 每个 step 都包含 source command、target、elapsedMs 和 result

### 场景二：iOS host action 成功但业务未 ready

- Given `app open-url` 返回成功
- And runtime 未在 timeout 内出现目标文本
- When 执行 `triton smoke ios`
- Then 输出 `status=fail`
- And 失败 step 为 `runtime.waitText`
- And summary 包含最近 AX / snapshot artifact、nearest candidates 和 suggested commands
- And 不把 open-url ack 误判为 pass

### 场景三：Xcode build/test 占用诊断

- Given 同一 Mac 上存在一个或多个 `xcodebuild` / SwiftBuildService 进程
- When 执行 `triton xcode status --json`
- Then 输出 active processes、workspace/project/scheme/destination/derivedDataPath 可探测字段、elapsed、log activity 和 confidence
- When 执行 `triton xcode wait-idle --workspace <workspace> --timeout 120 --json`
- Then 直到同 workspace build/test 空闲或超时
- And 超时返回 `xcode_not_idle` 与 blocking processes

### 场景四：WebView current URL 断言

- Given iOS DEBUG runtime 暴露当前 WKWebView provider metadata
- When 执行 `triton webview current-url --json`
- Then 返回当前 URL、title、pageSessionID、providerStatus 和 capability 边界
- When 执行 `triton route assert-current-url "https://example.invalid/path" --json`
- Then URL 匹配时 pass，不匹配时返回 expected/actual 和 next action
- And 没有 provider 时返回 `webview_provider_unavailable`，不伪装 DOM/JS 可用

### 场景五：安全设置 App preferences

- Given 目标 App data container 存在于 iOS Simulator
- When 执行 `triton app prefs set <key> <json-value> --bundle-id <bundle-id> --simulator booted --json`
- Then TritonKit 验证 JSON value 类型，写入 simulator-only preferences
- And 返回 previousValue/newValue、plist path、container path 和 restartAdvice
- And container 缺失时返回 `app_container_not_found`

### 场景六：Harmony host-side smoke 成功

- Given HDC target connected，目标 Harmony App 已安装或可启动
- When 执行 `triton smoke harmony --target <target> --bundle <bundle> --ability <ability> --wait-text <text> --screenshot <jpeg> --evidence <dir> --json`
- Then TritonKit 等待 device ready、启动 ability、dump layout、按 text wait/assert、采集 screenshot、写入 evidence
- And 输出 `status=pass`、platform=harmony、transport=hdc、layout/screenshot artifact

### 场景七：Harmony 多 target 消歧

- Given 存在多个 Connected HDC target
- When 执行 `triton smoke harmony` 且未传 `--target`
- Then 返回 `ambiguous_target`
- And 输出 candidates 与推荐命令
- And 不默认选择第一个 target

### 场景八：evidence summary / redact

- Given 存在 `.tritonevidence` 目录
- When 执行 `triton evidence summary <dir> --json`
- Then 输出 platform/version、commands、capabilities、failure codes、artifact counts 和脱敏状态
- And 默认不输出截图内容、私有路径、账号、bundle id 原文
- When 执行 `triton evidence redact <dir> --profile ios-private --output <redacted-dir> --json`
- Then 写出可公开转交的 redacted evidence

## 分期

### 当前实现状态（2026-05-22）

- S0 方案与测试基线已完成：本 space 的 README 与 technical design 已落地。
- S1 Xcode / host readiness diagnostics 已完成第一刀：`triton xcode status --json`、`triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json` 已进入 CLI 和 schema。
- S2 `smoke ios` 已实现并接入 CLI / schema / help；已通过 mock tests、`swift build --package-path CLI --scratch-path .build/cli --product triton`、`swift test --package-path CLI --scratch-path .build/cli-tests`、`triton schema --command smoke --json`、`triton smoke ios --help`、本机 structured-failure 验证，以及真实 iOS Simulator / embedded runtime 正向复跑。#17 的本地关闭条件已满足；#18 继续推进 priority 2/3 与 evidence/failure diagnostics；#15/#12 仍未进入关闭条件。

#### 2026-05-22 iOS runtime 正向复跑

- 环境：`TritonKit Dedicated iPhone 17`，UDID `0333546D-2AC6-4C22-AF01-293E2F4BA5BC`，App `TritonKitDemo`，bundle id `com.neptunekit.tritonkit.demo`。
- Demo 为正向 smoke 注册 `tritonkitdemo://` URL scheme，避免 `simctl openurl` 因无 scheme 失败；该 URL 只负责把 Demo 拉到前台，业务 ready 仍由 embedded runtime 的 wait/assert 证明。
- 构建安装验证：`triton xcode run --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --derived-data-path .triton/DerivedData --timeout 180 --jsonl` 返回 `ok=true`。
- 连接验证：`triton status --json` 返回 `connected=true`、`runtime=embedded`、`targetCount=1`；`triton list --json` 返回唯一 target `TritonKitDemo` / `com.neptunekit.tritonkit.demo` / `triton:local`。
- URL 验证：`triton app open-url tritonkitdemo://smoke --simulator booted --json` 返回 `ok=true`，source command 为 `xcrun simctl openurl booted tritonkitdemo://smoke`。
- 正向 smoke 命令：

```bash
triton smoke ios \
  --simulator booted \
  --target triton:local \
  --bundle-id com.neptunekit.tritonkit.demo \
  --open-url tritonkitdemo://smoke \
  --wait-text "Complex harness: 0" \
  --assert-text Primary \
  --screenshot /tmp/triton-smoke-positive.png \
  --evidence /tmp/triton-smoke-positive.tritonevidence \
  --evidence-name ios-runtime-positive \
  --evidence-note "simulator/runtime positive replay on TritonKitDemo" \
  --timeout 20 \
  --interval 0.5 \
  --json
```

- 结果：`ok=true`、`status=pass`、steps 为 `app.open-url`、`runtime.wait`、`runtime.assert`、`sim.screenshot`、`evidence.capture`，全部 `pass`；`assertions[0].query=Primary`、`count=2`；evidence target 为 `TritonKitDemo` 且 `targetConnectionState=connected`、`hierarchyCacheState=active`。

### S0：方案与测试基线

- 建立本 space 的 README 和 technical design。
- 明确 issue closure criteria。
- 为后续实现创建独立 branch/worktree。

### S1：Xcode / host readiness diagnostics

- `triton xcode status --json`
- `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json`
- 覆盖 #18 priority 1。

### S2：iOS one-shot smoke

- `triton smoke ios`
- 编排 app open-url、runtime wait/assert、sim screenshot、evidence summary。
- 覆盖 #17 与 #18 priority 2。

### S3：WebView URL / route assertion 与 prefs set

- `triton webview current-url --json`
- `triton route assert-current-url <url> --json`
- `triton app prefs set <key> <json-value> --bundle-id <bundle-id> --simulator <udid> --json`
- 覆盖 #18 priority 3 和 preferences setup。

### S4：Harmony one-shot smoke

- `triton smoke harmony`
- 编排 device wait-ready、app launch/open-url、layout wait/assert、screenshot、evidence。
- 覆盖 #15。

### S5：Evidence summary/redact 与失败诊断

- `triton evidence summary`
- `triton evidence redact`
- `find/tap/assert/wait` 失败 envelope 增加 nearest candidates、artifact refs 和 suggested commands。
- 覆盖 #18 evidence / failure diagnostics。

### S6：Simulator takeover P1 高价值补片

- 优先候选：`app prefs set`、`sim pasteboard`、`sim status-bar`、bounded logs。
- 只实现 smoke 主线需要的 slice。
- #12 不因本轮自动关闭，除非 P1 closure criteria 全部满足。

## Issue 关闭标准

### #15

可关闭条件：

1. `triton smoke harmony` 或等价计划模板可完成 host-side launch/wait/layout/screenshot/evidence。
2. mock HDC/uitest 测试覆盖成功、tool missing、ambiguous target、text not found、screenshot suffix。
3. 本地至少通过 `docs-linhay/scripts/verify-harmony-host-smoke.sh`。
4. README / real-project skill / emulator skill 已同步。

### #17

可关闭条件：

1. `triton smoke ios` 一命令完成 open-url/wait/assert/screenshot/evidence。
2. 单元测试覆盖 step ordering、host ack but runtime failure、artifact manifest、redaction summary。
3. 本地通过 Swift tests、CLI build、iOS mock or simulator smoke。
4. GitHub issue 评论附命令、测试与验证摘要。

### #18

可关闭或拆分条件：

1. priority 1-3 已落地：xcode occupancy、one-shot open-url wait snapshot、WebView current URL/assert。
2. preferences set、evidence summary/redact、failure diagnostics 至少完成或拆成独立 follow-up issue。
3. 所有公开评论保持脱敏。

### #12

默认保持 open。

只有在 simulator takeover P1 的 real-project state preparation 能力基本完成，且 plan/evidence host artifacts 可用时才关闭。否则本轮只评论完成项和剩余拆分。

## 验证门禁

每个实现切片至少运行：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
```

按能力追加：

```bash
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command smoke --json
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton schema --command evidence --json
TRITON_BIN=.build/cli/debug/triton docs-linhay/scripts/verify-harmony-host-smoke.sh
```

真实 simulator / emulator smoke 只在当前机器状态安全且不会修改私有业务数据时执行。
