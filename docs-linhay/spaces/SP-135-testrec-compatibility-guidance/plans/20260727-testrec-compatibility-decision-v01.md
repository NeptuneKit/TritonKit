# SP-135 Testrec Compatibility Decision v01

## Decision

- **Adopt Plan A：先收紧 testrec simulated compatibility guidance。**

## Why

- SP-126 的 one-runtime rule 已把 `.tritontestcase` 定位为 capture/compiler/compatibility layer，真实 verdict 归 `test import -> test validate -> test run`。
- 当前 `local-simulated` / matrix 仍兼容输出 `passed`、`passedCount`，而 `CLIRuntimeTransport` 还把 agent 直接导向 local-simulated；这是当前即可离线修正的产品误导。
- collection-preflight 的建议有价值，但仓内只有一条可运行 canonical flow；没有 reset receipt 或 target binding producer。现在实现它会生成不可执行占位流程，无法推动真实 Go/No-Go。

## Execution Plan

1. 为 replay dry-run、run、matrix target/matrix response 及 executor profile 添加 optional `verdictBoundary`，新输出固定为 offline diagnostic / 非真实 verdict / 非 reliability sample。
2. 保留既有 `status`、`ok`、`passedCount`，并验证旧 JSON 缺少 boundary 仍可 decode。
3. 将 local-device 和 capability next action 改为纯模板式 import → validate → run migration；不自动执行、也不保证 importer 可映射任何 case。
4. 同步 schema、agent-facing docs、SP-126/space/memory；以 focused offline tests 与 release schema 收口。

## Borrowed

- 采纳 collection-preflight 审计的事实：真实 60 次采样需要显式 canonical target、reset receipt、fresh private evidence root 和三条冻结 imported flow。
- 将其保留为未编号的后继候选；待真实立项时再分配连续 space 编号，不与 SP-135 混写。

## Rejected

- 不在 SP-135 增加 testrec real executor、matrix live execution 或 shared evidence summary 重定义。
- 不启动 Simulator/server/Xcode，也不利用 synthetic fixture 伪造 collection readiness。

## Verification

- `TestRecorderContractTests`、`TestImportTests`、schema/capability focused tests。
- release `triton schema --command testrec --json` 与 JSON encode/decode regression。
- `git diff --check`、`docs-linhay/scripts/check-docs.sh`、`docs-linhay/scripts/verify.sh --ci-docs`。
