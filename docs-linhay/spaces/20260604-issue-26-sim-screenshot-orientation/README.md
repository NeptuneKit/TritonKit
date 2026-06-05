# Issue 26 - triton sim screenshot iPad mini orientation

## 背景

GitHub Issue #26 报告：在 iPad mini (A17 Pro) Simulator 上执行 `triton sim screenshot` 后，生成 PNG 内容相对用户看到的模拟器显示方向旋转 90 度。当前 JSON 输出只透传 simctl command/stderr，未归一化方向，也未暴露 orientation metadata。

## 目标

- 调查 `triton sim screenshot` host-side 实现与 JSON 输出契约。
- 通过测试覆盖 iPad/simctl screenshot 方向相关行为。
- 在不扩大产品边界的前提下，给出最小修复：优先让输出匹配可预期显示方向；若无法可靠归一化，则至少在 JSON 中暴露明确 orientation/display metadata 与文档说明。

## 非目标

- 不新增 Web/Wails UI。
- 不接入真机、远端 agent、设备云或内置 VLM loop。
- 不直接依赖 XcodeBuildMCP 对外 API；Triton CLI/HTTP schema 仍是 agent 入口。

## BDD 场景与验收

### 场景：agent 获取 simulator screenshot 结果时能判断方向语义

Given 一个 iPad Simulator 已启动并可截图
When agent 执行 `triton sim screenshot --simulator <UDID> --output <png> --json`
Then 命令应成功写出 PNG
And JSON 输出应让 agent 明确知道截图方向是否已归一化或包含足够 metadata 判断方向
And 文档应说明该行为，避免把 raw framebuffer orientation 误当最终证据方向

## 相关链接

- GitHub Issue: https://github.com/NeptuneKit/TritonKit/issues/26
