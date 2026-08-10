# SP-161：Harmony assembleApp signed HAP 选择

## 边界

- 对应 GitHub issue：[#198](https://github.com/NeptuneKit/TritonKit/issues/198)
- 影响层：CLI host build artifact discovery、`TKBuildActionSummary` 与 Harmony install `nextAction`。
- 工作目录：`../TritonKit-worktrees/SP-161-issue-198-harmony-signed-hap/`
- 分支：`feat/SP-161-issue-198-harmony-signed-hap`
- 目标：`assembleApp` 同时产出多个 HAP 时，`artifact` 与 `nextAction --hap` 只选择可安装的 signed HAP。

## BDD / 验收

### 场景 1：signed sibling 优先

- Given Harmony `assembleApp` 输出普通/unsigned HAP 与 `*-signed.hap` sibling。
- When 执行 `triton build harmony ... --task assembleApp --json` 或 `--jsonl`。
- Then 成功结果的 `artifact`、`artifactPath` 和 `nextAction` 的 `--hap` 参数指向同一个 signed HAP。

### 场景 2：unsigned-only 安全边界

- Given `assembleApp` 只发现 unsigned HAP。
- When 执行 build。
- Then 不伪造成功，不填充 artifact，不生成 Harmony app-install nextAction；沿用现有 `hap_artifact_not_found` 失败 envelope，并提示补齐签名产物。

### 场景 3：默认 assembleHap 兼容

- Given 未使用 `assembleApp` 的既有 Harmony build 输出 unsigned HAP（例如 emulator debug fixture）。
- When 发现 artifact。
- Then 保留既有 discovery 行为，不把本 issue 的 real-device signing guard 扩散到旧流程。

## 非目标

- 不修改 Harmony 证书、profile、bundle 或 DevEco 工程配置。
- 不声明真实 Harmony 设备、HDC 安装或业务 smoke 已通过。
- 不新增 Web/Wails 控制面、远端设备或发布动作。

## 实施计划

1. 在 `BuildRunnerTests` 写 signed sibling、unsigned-only 与 artifact/nextAction 一致性的失败测试。
2. 在 `CLIBuildRuntime` 的 `assembleApp` artifact discovery 中优先过滤 signed HAP；无 signed 候选时 fail closed，保持单一错误 envelope。
3. 运行 focused CLI tests，确认默认 `assembleHap` unsigned 行为不回归；再按风险运行 CLI build/full tests 与文档检查。

## 当前状态

- 已完成实现与 focused 验证：`BuildRunnerTests` 10/10、`BuildRuntimeTests` 4/4，`git diff --check` 通过；真实 Harmony 工程、签名资产和设备不在本 space 范围内。
- `docs-linhay/scripts/check-docs.sh` 待主控登记 SP-161 全局索引后执行；当前仅因缺少该登记链接阻塞。
- 主控负责更新 `docs-linhay/spaces/INDEX.md`、`spaces/README.md`、memory、分支集成和 GitHub issue 收口。
