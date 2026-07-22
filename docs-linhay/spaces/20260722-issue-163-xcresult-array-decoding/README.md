# GitHub Issue #163：Xcode 26.6 xcresult Array Decoding

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#163](https://github.com/NeptuneKit/TritonKit/issues/163)
>
> Branch：`feat/20260722-issue-163-xcresult-array-decoding`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-163-xcresult-array-decoding/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 背景

Xcode 26.6 `xcresulttool get test-results summary` 把 `devicesAndConfigurations` 输出为 array，而当前 decoder 只接受 dictionary，导致有效 `.xcresult` 被映射为 `xcresult_parse_failed`；`xcresult failures` 会先解析 summary，因此也被同一错误阻断。

## 范围

- decoder 同时接受历史 dictionary 与 Xcode 26.6 array 两种 shape。
- 将两种输入规范化为同一内部 test/failure summary，不把兼容分支泄漏到 public contract。
- 对真正未知或缺失字段继续返回明确 parse error，不用宽泛 `Any` 吞掉结构问题。
- 增加脱敏 compact JSON fixture；不提交私有 `.xcresult` bundle。

## BDD 场景

### 场景 1：Xcode 26.6 array 可解码

- Given `devicesAndConfigurations` 为 array 的 test-results summary JSON
- When 解析 summary/failures
- Then 返回正常计数与失败列表
- And 不返回 `xcresult_parse_failed`

### 场景 2：旧 dictionary 保持兼容

- Given 历史 dictionary shape fixture
- When 使用同一 decoder
- Then 输出与修改前一致

### 场景 3：无效 shape 仍明确失败

- Given `devicesAndConfigurations` 为非 array/dictionary 或元素缺少必要结构
- When 解析
- Then 返回稳定 parse failure 与诊断
- And 不崩溃、不生成伪造测试结果

## 验收门禁

- 先补 Xcode 26.6 array fixture 失败测试并确认红灯。
- focused parser/CLI tests、nested CLI full tests、根包 `swift test`、release build 与 docs gate 通过。
- 使用 `triton xcresult failures` 复验可用的本地脱敏 bundle/fixture；schema 与公开输出形状保持稳定。
- 同步 Xcode takeover 文档、相关 public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化验证、main 集成与线上 CI 全部满足后评论并关闭 #163。

## 实施记录

- Triton-first facts 已采集：0.2.14 的 status/doctor/capabilities 正常，`xcode` / `xcresult` schema 暴露测试和 result reader 契约；`triton plan xcresult --json` 返回 `validation_failed`，证明该 plan action 尚未覆盖，后续仅以脱敏 shape 查询回退到原生 `xcresulttool`。
- 使用 `triton xcode test --package Package.swift --scheme TritonKit-Package --destination platform=macOS --result-bundle ... --jsonl` 生成本机 Xcode 26.6 bundle，真实复现 summary 在 `devicesAndConfigurations` array 上 type mismatch。首层修复后又确认 `testFailures` 同为 array；两者已收敛为受类型约束的 single-or-array decoder，公开 summary DTO 保持既有单值形状。
- 同一个真实 bundle 的 tests tree 不再包含 `Test Case Run`，失败诊断直接挂在 failed `Test Case` 下。parser 现在兼容历史 nested run 与 Xcode 26.6 flattened case，并避免在同时存在 run child 时重复生成 failure record。
- 红灯分别确认 array summary type mismatch、`testFailures` type mismatch 与 flattened failed case 返回 0 records。实现后 `TKXcodeWorkflowModelsTests` 19 tests、`XcresultCommandTests` 4 tests 通过。
- 修复后的 debug CLI 对真实 bundle 返回 `ok:true`、227 total / 226 passed / 1 failed，并输出 1 条结构化 failure record；输出仅检查脱敏计数、类型和测试标识，未提交或公开原始 `.xcresult`。
- README、agent 控制文档、Xcode takeover 技术设计、项目级 skill 与 public dev-feedback skill 已同步。
- 完整本地门禁通过：`git diff --check`、`check-docs.sh`、SwiftPM boundary、iOS DEBUG isolation、Swift 230 tests / 27 suites、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build 均成功。release CLI 对同一真实 bundle 也返回 227 total / 226 passed / 1 failed 与 1 条 failure record。
- nested CLI 全量执行 669 tests / 52 suites，其中 issue-focused `XcresultCommandTests` 4 tests 全过；全量仍有 23 个非本 issue 问题：13 个既有 schema fact-source 基线、9 个依赖本机 target 状态的 TestRecorder 基线，以及仅在全量序列中出现的 streaming `/bin/pwd` 30 秒超时。前 22 个已在 main 基线复现；streaming 测试单独重跑 0.076 秒通过，判定为测试隔离/时序瞬态，不由 xcresult decoder 改动引入。
- main 集成和线上 CI 待收口。
