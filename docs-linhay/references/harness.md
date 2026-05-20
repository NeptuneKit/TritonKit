# Harness Reference

## 来源

- GitHub: `https://github.com/awizemann/harness`
- 版本线索：README 显示 v0.3.1、macOS 14+、Swift 6。
- 本地源码快照：`/tmp/harness`

## 项目定位

Harness 是一个 native macOS developer tool，用 AI agent 驱动 iOS Simulator、macOS app 或 Web app 做“真实用户测试”。它不是 scripted UI test，而是让 agent 按 persona 和自然语言 goal 操作界面，输出三类产物：

1. goal 是否完成：success / failure / blocked + summary。
2. 用户路径：可回放的 screens + actions。
3. 摩擦点：agent 标记的 UX friction events。

对 TritonKit 的参考价值主要在 **agent run loop、run artifact、friction taxonomy、platform adapter、credential redaction、证据清洁**，而不是直接复用它的 GUI 产品形态。

## 架构要点

Harness 的核心链路：

```text
RunCoordinator
  -> PlatformAdapter.prepare
  -> UXDriving.screenshot
  -> AgentLoop.step
  -> UXDriving.execute
  -> RunLogger append JSONL
  -> RunHistoryStore / replay
```

关键分层：

- `PlatformAdapter`：按 iOS Simulator、macOS app、Web app 提供 prepare/teardown、tool schema、platform prompt context。
- `UXDriving`：平台中立的 per-step driver，只负责 screenshot、execute tool call、relaunchForNewLeg。
- `AgentLoop`：预算、历史压缩、parse retry、cycle detector、LLM step。
- `RunLogger` / `RunLogParser`：append-only JSONL、截图、meta、partial run replay。
- `ProcessRunner`：唯一的 subprocess owner，支持 one-shot、streaming、timeout、cancel -> SIGTERM -> SIGKILL。

## 值得 TritonKit 抄的设计

### 1. UX Run 作为一等产物

Harness 把一次用户测试定义为 `goal + persona + target + model + mode + budget`，产物是 run directory。

TritonKit 可吸收为 `.tritonrun` 或 `.tritonevidence` 的 UX 子类型：

```text
<case>.tritonevidence/
  run/
    events.jsonl
    meta.json
    step-001.png
    step-002.png
  artifacts/
    host/
    runtime/
    xcode/
```

现有 `capture/evidence/.tritonplan` 更偏“验证和证据”；Harness 提醒我们需要补一个“agent 真实用户尝试路径”的表达，尤其适合提 issue 和产品回归。

### 2. Append-only JSONL run log

Harness 的 run log 规则很硬：

- 每行完整 JSON object。
- 每行带 `schemaVersion/runId/ts/kind`。
- append-only，不重写历史行。
- screenshot 先落盘，再写 `step_started`。
- parser 忍受最后一行截断，旧 schema 永久可读。
- meta.json 作为 offline portable summary。

TritonKit 应在 `.tritonevidence` / `.tritonplan replay` 中补同类事件：

```text
run_started
step_started
tool_call
tool_result
friction
step_completed
run_completed
```

这比当前“命令结果 + artifacts”更适合还原 agent 做了什么、为什么这么做、在哪一步卡住。

### 3. Friction taxonomy

Harness 的摩擦分类非常适合真实项目回归：

- `dead_end`
- `ambiguous_label`
- `unresponsive`
- `confusing_copy`
- `unexpected_state`
- `auth_required`
- system synthesized: `agent_blocked`

TritonKit 可以把它作为 issue/evidence 的标准分类，而不是让每个 agent 自由写“体验不好”。这能把回归报告从“截图 + 失败”升级成“用户为什么会失败”。

建议 TritonKit 先在 evidence manifest 中增加：

```json
{
  "kind": "friction",
  "step": 3,
  "frictionKind": "ambiguous_label",
  "detail": "按钮只写了 Go，我不知道它会提交还是跳转。"
}
```

### 4. Persona + Goal 分离

Harness 把 persona 注入 system prompt，把 goal 作为目标，不混在一起。这个边界很好：

- persona 决定耐心、探索程度、摩擦敏感度。
- goal 决定任务完成条件。
- persona 不改写 goal，也不增加能力。

TritonKit 若后续做 `triton run --persona ... --goal ...`，应采用同一规则。

### 5. 每步 fresh screenshot + observation/intent/action

Harness 每轮强制 fresh screenshot，并要求每个 tool call 携带：

- `observation`：当前看到了什么。
- `intent`：为什么这一步服务 goal。
- `input`：实际动作。
- `tool_result`：执行结果。

TritonKit 的 `.tritonplan` replay 更偏脚本执行，缺少 agent 的“为什么”。如果加入 agent-run 模式，应该把 observation/intent 写入 JSONL，用于后续人工 review。

### 6. Cycle detector

Harness 用 screenshot perceptual hash + 最近 3 次 tool call 等价判断卡死：

- screenshot hash Hamming distance 小于阈值。
- tool call 同类且坐标接近。
- 连续 3 次则 blocked，并生成 friction。

TritonKit 可在 `replay` / `capture --agent` / `wait` 中引入类似机制，避免 agent 在同一屏幕重复 tap 浪费时间和 token。

### 7. Credential redaction

Harness 的 credential 设计值得直接吸收：

- 密码存在 Keychain，不进 prompt。
- prompt 只告诉 agent 有哪个 credential label / username。
- agent 调 `fill_credential(field:"password")`，日志只记录 field，不记录值。
- JSONL 里 grep 密码应为 0。

TritonKit 真实项目回归经常会遇到账号登录。后续不要让 agent 把账号密码写入 `.tritonplan`、prompt、events.jsonl 或截图描述；应该提供 host-side credential binding。

### 8. Agent scaffolding 不落盘

Harness v0.3.1 的 Set-of-Mark web targeting 有一个很好的不变量：

- agent 收到带编号标记的 in-memory marked image。
- 磁盘 PNG 保持 clean page，replay / friction report / shared screenshot 不含调试标记。

TritonKit 如果未来为 AX candidate、tap target、matched text 做 screenshot overlay，也应遵守：

- agent-only overlay 可以存在于内存或临时 payload。
- evidence 中保存的 screenshot 默认必须是用户真实看到的干净画面。
- overlay 另存为独立 debug artifact，不能覆盖主证据图。

### 9. PlatformAdapter / UXDriving

Harness 用 `PlatformAdapter` 和 `UXDriving` 屏蔽 iOS/macOS/Web 差异。TritonKit 已经在 Apple simulator、Harmony HDC/DevEco、embedded runtime 之间面临同类问题。

建议 TritonKit 的 host adapter core 吸收两个概念：

1. `prepare/teardown` 管 lifecycle。
2. `screenshot/execute/relaunch` 管 per-step UX driving。

但 TritonKit 不应把 embedded runtime 也塞进 host driver；runtime 仍是单独服务，Plan/Evidence 编排两者。

### 10. WebDriverAgent 作为黑盒 fallback

Harness 的 WDA 结论值得记录：它从 idb 迁到 WebDriverAgent，因为 iOS 26+ 上 idb HID injection 能显示绿色触点但不一定进入 UIKit responder chain；WDA 通过 XCTest / `XCUICoordinate.tap` 路径触发真实 UIEvent。

TritonKit 决策：

- 不把 WDA 放进 P0/P1 默认依赖。
- 可作为 P3/P4 黑盒 App fallback：当业务 App 没接 embedded runtime，仍可做有限 tap/swipe/type。
- 如果引入，必须 cache WDA build by iOS runtime + WDA SHA，并把 WDA build log 归档为 artifact。

### 11. ProcessRunner actor

Harness 的 `ProcessRunner` 和用户提到的 `SKProcessRunner` 方向一致：

- 所有 `Process()` 由单一 runner 管。
- 支持 streaming output。
- 支持 timeout。
- cancellation 先 SIGTERM，再 SIGKILL。
- non-zero exit 带 stdout/stderr tail。

TritonKit host adapter 可以吸收这套契约，避免每个命令自己处理 pipe、timeout 和取消。

### 12. Xcode build 细节

Harness 的 XcodeBuilder 有一个对 TritonKit 很实用的签名策略：

```text
CODE_SIGN_IDENTITY=-
CODE_SIGNING_REQUIRED=YES
CODE_SIGNING_ALLOWED=YES
CODE_SIGN_STYLE=Manual
DEVELOPMENT_TEAM=
ONLY_ACTIVE_ARCH=YES
```

它避免简单 `CODE_SIGNING_ALLOWED=NO` 导致 entitlements 不应用，进而出现 simulator Keychain entitlement 问题。TritonKit 的 `xcode build/run` 需要把这作为可选默认策略评估，而不是盲目关闭签名。

## 不建议抄的部分

1. 不抄 GUI-first 产品形态。TritonKit 的事实入口仍是 CLI/HTTP 机器可读契约。
2. 不抄 SwiftData run history 作为核心依赖；TritonKit 证据应优先 filesystem portable。
3. 不抄 WebDriverAgent 作为 P0 依赖；它重、构建慢、引入 submodule 和 XCTest runner 生命周期。
4. 不抄 provider-specific LLM orchestration 到核心 CLI。TritonKit 默认服务外部 AI agent，而不是内置一个 agent runtime。
5. 不抄 Harness 的 app support 目录结构；TritonKit 应继续使用 workspace `.triton/` 与显式 output path。
6. 不把 UI step approval gate 放入 CLI 默认模式；可作为 future interactive / desktop 功能。

## TritonKit 采纳优先级

### P0/P1 可直接吸收

- evidence JSONL run event schema。
- friction taxonomy。
- screenshot-before-event 与 append-only writer 不变量。
- credential redaction invariant。
- clean screenshot vs agent-only overlay invariant。
- process runner 契约。
- status bar override 用于稳定截图。
- Xcode ad-hoc signing strategy 作为 `xcode build/run` 选项。

### P2/P3 再吸收

- agent-run mode：`goal + persona + budget + friction`。
- cycle detector。
- platform adapter / UX driver 抽象收敛 Apple/Harmony/Web。
- WDA black-box input fallback。
- prompt single-source-of-truth 与 provider-neutral tool schema。

### P4 或不吸收

- native macOS GUI run history。
- SwiftData persistence。
- web WKWebView target driving。
- step-by-step human approval UI。

## 与现有 TritonKit spaces 的关系

- Harness UX run evidence：`docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`
- Simulator takeover：吸收 WDA 评估、status bar override、input fallback、clean screenshot evidence。
- Xcode workflow takeover：吸收 ad-hoc signing strategy、run artifact layout、process streaming runner。
- Real project regression：吸收 persona/goal/friction、credential redaction、append-only run replay。
- Harmony emulator alignment：吸收 platform adapter / UXDriving 的抽象，但保持 HDC/DevEco 为底层 driver。
