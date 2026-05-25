# 20260525 Cross-Platform CLI Simplification - Implementation Plan v01

## 目标

把 `triton device` 固化为 agent 的默认 host device 入口，继续保留 `triton sim` 作为 iOS 高级维护入口，但不让 agent 再默认记住多个平台专属入口。

## 当前状态

第一轮统一入口已经落地，`device list / use / wait-ready / screenshot` 的基础闭环已能覆盖 iOS Simulator 与 Harmony Emulator。

## 本轮成功标准

1. `device` 的统一契约保持稳定，schema、测试和真实 smoke 一致。
2. iOS 与 Harmony 的设备发现、选择、等待和截图都走统一入口。
3. `sim` 继续保留，不做破坏性迁移。
4. 文档、memory、qmd 同步完成。

## 里程碑

### M1. 契约收口

- 复核 `device` 的参数、输出 envelope 和错误码。
- 明确 iOS / Harmony 的共性字段与平台附加字段。
- 通过测试锁住命令解析与 schema 示例。

进展：

- 已发现并修复 `device use --platform ios --ready` / `device use --platform harmony --ready` 这类过滤式选择的 current 写回问题：无显式 selector 时，current 现在写入稳定 target id（如 `sim:<udid>` / `harmony:<target>`），避免写入 `ios` / `ready` 这种后续不可复用的过滤词。
- 已新增测试锁住 current selector 写回策略和跨平台唯一 ready target 自动解析。
- 已将 Harmony embedded runtime URL 准备动作接入统一 selector：`triton device runtime-url --device harmony-a --probe-manifest --json` 现在可复用 alias / raw id / `current`，旧 `--platform harmony --target <target>` 仍为兼容路径。

### M2. 实现与测试

- 补齐或调整 `device` 的共享 resolver 和 action 实现。
- 维护 `list / use / wait-ready / screenshot` 的统一行为。
- 新增或更新最小测试集，先红后绿。

### M3. 真实 smoke

- 用本机 iOS Simulator 和 Harmony Emulator 做真实验证。
- 记录成功输出、失败输出和 ready 判定差异。
- 生成或更新截图证据。

### M4. 文档收尾

- 更新 `README.md`、`docs-linhay/dev/`、`docs-linhay/memory/`。
- 执行 `docs-linhay/scripts/check-docs.sh`。
- 执行 `qmd update` 与 `qmd embed`。

## 交付物

- 统一入口的代码变更
- 对应测试
- 真实 smoke 证据
- 结构化文档与 memory 记录

## 验证记录

- `swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests`：通过，覆盖 14 个 `device` / selector / schema 测试。
- `swift test --package-path CLI --scratch-path .build/cli`：通过，覆盖 54 个 CLI 测试。
- `docs-linhay/scripts/verify-harmony-runtime-base-url-smoke.sh`：通过，覆盖 `runtime-url --device` schema、selector 默认端口、旧 `--platform harmony --target` 兼容路径和 direct runtime mock endpoint。
- `docs-linhay/scripts/verify.sh --local`：通过，覆盖 SwiftPM dependency boundary、根 Swift tests、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs structure 与 whitespace check。

## 约束

1. 不删除旧入口。
2. 不把 Web/Wails UI 拉进本轮。
3. 不扩到 Android。
4. 不改 Release / Homebrew 契约。
