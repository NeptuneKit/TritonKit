# SP-136 Collection Preflight Decision v01

## Decision

- **Adopt：只实现 offline collection preflight；拒绝在本 slice 生成 sample 或运行 harness。**

## Why

- SP-134 的 report 能验证真实 evidence，却不能证明未来样本会有统一 target/reset/slot contract。
- SP-135 已把 testrec simulated result 限定为 non-verdict，不能补作 3 × 20 的样本。
- 当前只有单条真实 imported proof；因此本期只能冻结 future collection 的安全输入，不能以合成 evidence 或虚构 receipt 声称采样准备完成。

## Minimal contract

1. 私有 JSON 固定声明：尚未创建的 evidence root、三条 imported iOS Simulator flow、各二十个 fresh slot、一个 plan digest 不复用 supported flow 的单一 negative control、initial-state/reset recipe identity，以及 explicit canonical `triton:ios-simulator:<UDID>/app:<bundle>` 的 binding digest。
2. preflight 读取并 validate 每条 plan 后重算 normalized-plan digest；它不相信自报 digest、target token 或 output path。
3. public response 仅发布 anonymized aliases、digest、counts 和 `ready_to_collect`，并固定 `eligibleForReliabilityGate=false`。
4. schema/capability 仅提示离线 preflight。真实执行必须由后继 live harness 取得 dedicated-target/server/reset ownership 后再调用既有 `test run`。

## Rejected

- 从 preflight 直接 fan-out 60 次 `test run`。
- 自动选择 `booted`/alias target，或自动创建/清空 evidence root。
- 记录 raw UDID、bundle、path、selector 或 reset receipt 到 stdout、schema example 或 Git fixture。
- 在 workspace、testrec executor 或共享 evidence model 中建立平行 collection 实现。
