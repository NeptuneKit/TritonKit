# 20260617 Issue 62 Discovery Timeout

## 背景

GitHub Issue #62 反馈 Homebrew arm64 二进制环境中，agent-facing discovery 命令可能在 5 秒内没有任何 stdout/stderr，典型命令包括：

- `triton version --json`
- `triton schema --command device --json`
- `triton device doctor --platform harmony --json`

这会让 agent 无法判断 TritonKit 是否可用，也无法拿到 schema / doctor 的机器可读恢复动作。该问题优先按 CLI discovery 契约修复：快速查询不能触发设备发现；必须触发 host-side discovery 的 doctor 需要有有界 timeout 或 JSON error envelope。

## 范围

### 目标

1. `triton version --json` 使用快速路径，不触发 iOS / Android / Harmony 设备发现或外部 host 进程。
2. `triton schema --command device --json` 使用快速路径，不触发设备发现或外部 host 进程。
3. `triton device doctor --platform harmony --json` 在 Harmony host-side discovery 变慢或卡住时，输出有界合法 JSON，而不是静默挂死。
4. timeout / failure 输出保持 machine-readable，包含 stable error code、message、recovery / nextAction 或等价恢复信息。
5. 行为用 focused Swift tests 覆盖，优先验证命令分发与 runtime helper，不依赖真实 DevEco Emulator。

### 非目标

1. 不新增 Web / Wails UI。
2. 不实现远端 agent、设备云或真机接管。
3. 不改变 Homebrew release 流程。
4. 不要求本轮启动真实 Harmony / DevEco Emulator。
5. 不修改主仓或其他 worktree。

## BDD 验收场景

### 场景一：version JSON 不触发设备 discovery

- Given agent 需要快速确认 Triton CLI 版本。
- When 执行 `triton version --json`。
- Then 命令在不访问 iOS / Android / Harmony host discovery 的情况下生成 JSON。
- And JSON 包含版本、commit、build date 等现有字段。
- And 即使设备 discovery runner 会阻塞，version 仍不受影响。

### 场景二：device schema JSON 不触发设备 discovery

- Given agent 需要读取 `device` 命令 schema。
- When 执行 `triton schema --command device --json`。
- Then schema 由静态 fact source 生成。
- And 不调用 Harmony HDC、Android ADB、iOS simctl 或其他 host discovery。
- And 输出是合法 JSON，包含 `device` command 的参数、示例、failure codes 和 next commands。

### 场景三：Harmony doctor discovery timeout 输出有界 JSON

- Given Harmony host-side discovery runner 在 `hdc list targets` 或后续 probe 上卡住。
- When 执行 `triton device doctor --platform harmony --json`。
- Then CLI 在有界 timeout 内返回。
- And stdout 至少输出一个合法 JSON doctor envelope。
- And JSON 可机器读取 `ok=false` 与具体 tool error。
- And 通用 host action 若遇到 Harmony discovery timeout，错误码可稳定识别为 `harmony_discovery_timeout`。

### 场景四：Harmony doctor 正常路径不被 timeout 包装破坏

- Given fake Harmony runner 快速返回 ready 或 no-target 结果。
- When 执行 `triton device doctor --platform harmony --json`。
- Then 继续输出原有 doctor JSON success / failure envelope。
- And source commands 与 recovery checks 保持可读。

## 测试计划

1. 先新增 focused tests，构造会阻塞或会计数的 fake discovery runner，确认 version/schema 不触发 discovery，Harmony doctor timeout 当前失败。
2. 最小实现 version/schema 快速路径隔离和 Harmony discovery 有界 timeout / JSON error envelope。
3. 运行 focused tests：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter DiscoveryTimeoutTests
swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests
swift test --filter TKHostAdapterModelsTests
```

4. 收尾运行：

```bash
git diff --check
docs-linhay/scripts/check-docs.sh
```

## 影响面

优先检查并最小修改：

- `CLI/Sources/TritonKitCLI/` 下 ArgumentParser command、version/schema/runtime、host device runtime。
- `CLI/Tests/TritonKitCLITests/` 下 schema / device focused tests。
- `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift` 中 host-side runner / parser 测试。

## 本轮实现记录

1. `TKHarmonyHDCCommand.version/listTargets/listTargetsPlain` 默认 timeout 从通用 30 秒收敛为 3 秒，覆盖 `device doctor --platform harmony` 的 HDC probe 和 Harmony target discovery 入口。
2. `failHostCommand` 的 timeout 映射新增 Harmony discovery 专用 `harmony_discovery_timeout`，用于 `hdc -v`、`hdc list targets -v`、`hdc list targets` 这类 discovery 命令卡住时的 JSON error envelope。
3. `triton schema --command device --json` 的 failure codes 同步暴露 `harmony_discovery_timeout`。
4. 新增 `DiscoveryTimeoutTests`，覆盖 version/schema 静态路径、Harmony discovery 命令 timeout 上限和 timeout JSON error code。

## 验证记录

已通过：

- `swift test --package-path CLI --scratch-path .build/cli --filter DiscoveryTimeoutTests`
- `swift test --package-path CLI --scratch-path .build/cli --filter FailureDiagnosticsTests`
- `swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests`
- `swift test --filter TKHostAdapterModelsTests`
- `.build/cli/arm64-apple-macosx/debug/triton version --json`
- `.build/cli/arm64-apple-macosx/debug/triton schema --command device --json`
- fake sleep HDC smoke：`.build/cli/arm64-apple-macosx/debug/triton device doctor --platform harmony --hdc <sleep-hdc> --json` 在 `real 3.08s` 返回 `ok=false` JSON doctor envelope。
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`
