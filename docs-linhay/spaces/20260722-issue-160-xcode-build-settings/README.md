# GitHub Issue #160：Xcode One-off Build Settings

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#160](https://github.com/NeptuneKit/TritonKit/issues/160)
>
> Branch：`feat/20260722-issue-160-xcode-build-settings`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-160-xcode-build-settings/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 背景

`triton xcode settings/build/test/run` 尚不能表达临时 `KEY=VALUE` build settings，导致真实 CocoaPods/业务工程诊断必须离开 Triton schema 回退裸 `xcodebuild`。

## 范围

- 为 settings/build/test/run 增加 repeatable `--build-setting <KEY=VALUE>`。
- 在共享 Xcode invocation model 中保留 argv 边界与输入顺序，并进入 sourceCommand、help 与 schema。
- 接受包含空格、`$(inherited)` 等 value；对空 key、非法 key 或缺少 `=` 返回稳定 validation error。
- 不引入 shell parsing，不自动修改工程、Pods 或签名资产。

## BDD 场景

### 场景 1：重复 setting 按独立 argv 透传

- Given 两个合法 `KEY=VALUE` 输入
- When 解析 settings/build/test/run invocation
- Then xcodebuild argv 按输入顺序包含两个独立参数
- And sourceCommand 与 schema 可审计这些参数

### 场景 2：value 保持原样

- Given value 包含空格或 `$(inherited)`
- When 构建 invocation
- Then value 不经 shell 拆分或二次转义

### 场景 3：非法 key 在 host command 前拒绝

- Given 缺少 `=`、空 key 或不符合 Xcode setting key 规则的输入
- When 执行命令
- Then 返回 `validation_failed` 与可操作 hint
- And 不启动 `xcodebuild`

## 验收门禁

- 先补参数解析、argv、schema 失败测试并确认红灯。
- focused CLI tests、nested CLI full tests、根包 `swift test`、release build 和 docs gate 通过。
- 使用 `triton schema --command xcode.build --json` 与最小 package/workspace smoke 证明契约；只有 schema 明确不足时才 fallback 裸 `xcodebuild`。
- 同步 Xcode takeover space/技术文档、README、相关 public skills 与 memory。

## 停止条件

三个场景、自动化验证、main 集成与线上 CI 全部满足后评论并关闭 #160。
