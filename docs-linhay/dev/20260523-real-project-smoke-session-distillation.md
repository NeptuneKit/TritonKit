# Real Project Smoke Session Distillation

## 背景

本轮会话从 WebView runtime bridge、Harmony host-side 验证、CLI 文件治理一路推进到 Real Project Smoke P1。主线最新稳定提交为 `be30ba4 feat: add open-url readiness snapshot`，`main` 与 `origin/main` 已对齐；工作区另有未跟踪源码/测试 WIP，本次整理不纳入。

## 沉淀模式

真实项目 smoke 不应按单个命令孤立验收，而应按同一条闭环组织：

```text
prepare host target -> launch/open route -> wait/assert runtime or host state -> capture artifacts -> summarize/redact evidence -> report pass/fail
```

该闭环已经在 `docs-linhay/spaces/20260522-real-project-smoke-p1/` 中收敛为跨 issue 方案，并由以下主线提交提供当前可复用能力：

- `4bbd2a5 feat: add iOS smoke orchestration`：提供 `triton smoke ios` 编排层。
- `be30ba4 feat: add open-url readiness snapshot`：提供 `triton app open-url <url> --wait-ready --snapshot --json`。
- `b0612bf docs: expand webview bridge guidance` 与 `78b9efa docs: sync webview bridge skill docs`：固化 WebView provider / allowlist bridge / Harmony host-only 边界。

## BDD 场景

### 场景一：iOS smoke issue 收口

- Given 一条真实项目 iOS smoke issue 要求一命令完成 open route、等待、断言、截图和 evidence
- When `triton smoke ios ... --json` 在真实或结构化 runtime 环境中返回 `status=pass`
- Then issue 评论必须包含主线 commit、测试命令、真实/结构化验证摘要和 evidence 边界
- And 只有该 issue 的验收条件满足时才关闭

### 场景二：open-url readiness 不是业务成功

- Given `triton app open-url <url> --json` 返回 host action 成功
- When 没有后续 runtime ready、snapshot、wait 或 assert 证明业务状态
- Then 只能记录为 URL 提交成功
- And 不能把它作为 smoke 通过或 issue 关闭依据

### 场景三：跨 issue 共享编排层

- Given #12、#15、#17、#18 共享真实项目 smoke 编排层
- When 其中一个 slice 已进入 `main` 并完成验证
- Then 只关闭该 slice 对应 issue
- And 其余 issue 继续按各自 closure criteria 跟踪，不能因为共享实现而批量关闭

## 当前状态

- #17：`smoke ios` 已进入 `main`，完成 mock tests、CLI build/test、schema/help、structured failure 与真实 iOS Simulator / embedded runtime 正向复跑，已关闭。
- #18：priority 1 的 `xcode status/wait-idle` 与 priority 2 的 `app open-url --wait-ready --snapshot` 已完成；WebView URL/assert、prefs set、evidence summary/redact 与 failure diagnostics 仍需继续推进或拆 follow-up。
- #15：Harmony host-side P0/P1 已有真实验证和底层命令，但 `smoke harmony` 闭环尚未满足关闭条件。
- #12：仍作为 simulator takeover epic 保持打开，除非 P1/P2 范围被明确验收。

## 本次同步

- 更新 `tritonkit-real-project-regression` skill，新增 Real-Project Smoke Issue Closure 检查清单。
- 不更新 `AGENTS.md`：当前是具体领域流程沉淀，已有 repo-wide 规则足够。
- 记忆写入 `docs-linhay/memory/2026-05-23.md`。
- 验证走 docs/skill-only 门禁：`docs-linhay/scripts/check-docs.sh`、`git diff --check`、`docs-linhay/scripts/qmd-sync.sh`。
