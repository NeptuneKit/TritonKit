# SP-212 — mobile-mcp Android 契约采用

## 边界与状态

- 2026-10-19 根据 mobile-next/mobile-mcp `c659f8ee34873a832adea7daca9c69172d887e70` 与 `1.0.12` 增量评估立项，状态：已实现并完成 focused 离线验收，待主控联合门禁与本地 main 集成；影响层为 macOS CLI/HTTP 的 Android host adapter 与 shared ADB command builder。
- 实际产品基线：`main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`。branch：`feat/SP-212-mobile-mcp-android-contracts`；worktree：`/Users/linhey/.codex/worktrees/mobile-mcp-android-contracts/TritonKit`。主目录另有用户 WIP，执行会话使用独立 worktree；不把主目录分支当作 main，不整分支回灌。
- 参考来源：[mobile-mcp commit](https://github.com/mobile-next/mobile-mcp/commit/c659f8ee34873a832adea7daca9c69172d887e70)、[Release 1.0.12](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.12)。许可证 Apache-2.0；完整官方证据在 `.build/reference-monitor/20261019/research/mobile-next__mobile-mcp/`。
- 用户已授权对评估可纳入项直接建立执行/主控会话、独立验证、必要本地提交和本地 main 合并；不包含 push/tag/release、安装升级依赖、运行第三方代码、签名、DDI 或设备动作。

## 采用机制与本地缺口

1. **Android 前台 activity 身份**：当前 `triton device foreground --platform android --json` 的 `observed` 仅返回 `bundleIdentifier`、`identityState` 和 `scope`，缺少 component/activity。采用 mobile-mcp 的 focused activity 可观测性，但保留 `resumed-activity` 来源、unknown/fail-closed 和现有单 envelope。
2. **ADB 文本 `#`/`~` 转义**：当前 `TKAndroidADBCommand.inputText` 直接将原文作为 `adb shell input text` 参数；Android legacy shell 的二次解析会让 `#`/`~` 等字符丢失或解释错误。只改命令构造与 fake-adb/argv 契约测试，不做真实设备验证。

本期不引入 mobilewright、不升级依赖、不复制上游 TypeScript、不开启远端 adb/真机范围；UI dump 缓冲、swipe 成对校验已由当前产品覆盖或另行观察。

## BDD 与验收

- Given `dumpsys activity activities` 含 `topResumedActivity` 或 `mResumedActivity`，When 执行 Android foreground 观察，Then JSON 同时给出包名与可信 activity/component；两种格式均可解析，未知时保持 `identityState=unknown` 且不得猜测。
- Given 输出只含 `mCurrentFocus` 或 malformed ActivityRecord，When 观察前台，Then 不把旧窗口当作当前 resumed activity，保留现有验证失败语义。
- Given 输入文本包含 `#`、`~`、空格、引号、反斜杠、Unicode 或换行，When 构造 `adb shell input text`，Then fake runner 收到可重复的安全 argv，legacy shell 不会把字符当作注释/展开；敏感文本仍不出现在 source command。
- Given Android 非 legacy shell 路径或其他平台，When 构造命令，Then 不扩大到设备动作或远端控制面，保持现有平台边界。

## 文件面与验证

执行会话只拥有：`Sources/TritonKitCLI/CLIDeviceEnvironmentRuntime.swift` 及其 Android foreground 测试；`Sources/TritonKitShared/TKAndroidADBSupport.swift` 及其 fake-adb/命令构造测试；必要的同模块模型/schema 文件。不得修改 Web/Wails、embedded SDK、真机/远端能力或依赖版本。

验证顺序：先失败测试，再 focused CLI/shared tests；随后 `swift test --package-path CLI --no-parallel`、根包 `swift test`（若受环境限制如实记录），`git diff --check` 与适用 docs 门禁。不得运行上游代码、安装依赖或操作设备。

## 分派记录

- 执行/主控新会话必须显式 `model="gpt-6.1-sol"`；模型不可用则记录失败并保留待重试，不回退、不伪造 thread ID。
- 执行 worktree：`/Users/linhey/.codex/worktrees/mobile-mcp-android-contracts/TritonKit`；主控只审查冻结候选、跑联合门禁并按用户授权合入本地 main。

## 2026-10-19 实现契约与离线证据

- Android foreground 的旧 `bundleIdentifier` / `identityState` / `scope` 字段保留；可信 resumed record 新增 `component`（保留原始 package/class）与 `activity`（仅对前导 `.` 展开包名，其余类名原样保留）。unknown 时不输出 activity/component，不从窗口或损坏记录猜测。
- 顶层 `topResumedActivity` 标记优先；其为 null/malformed 时不回退较旧 `mResumedActivity`。同优先级多个不同 component 也保持 unknown；必须存在闭合、合法的 ActivityRecord。
- 类名展开遵循 [AOSP ComponentName.unflattenFromString](https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/content/ComponentName.java)：仅前导 `.` 拼接 package；裸类名不猜测包名。
- `TKAndroidADBCommand.inputText` 保留本地独立 argv，将第 5 索引 payload 进行 POSIX 单引号编码（内部单引号安全拆分），并设置参数脱敏索引；CLI source command 不暴露原文或编码文本。
- 离线 `/bin/sh` fake-adb fixture 验证实际进程 argv，第二个 shell fixture模拟 adb 远端 argv 拼接，验证 `#`、`~`、空格、引号、反斜杠、Unicode、换行、命令替换/分隔符与空字符串均保留为一个字面参数。本期不改变 Android `input text` 的 `%s` 语义，也不宣称设备 IME、Unicode/换行实际输入成功。
- 红测：`.build/sp212-evidence/shared-red.log` 记录20项断言失败；`.build/sp212-evidence/cli-red.log` 记录14项断言失败。绿测：`shared-green.log` 44 tests；CLI foreground focused 最终候选13 tests通过，证据见 `cli-green.log`。命令使用独立 `.build/sp212-root` / `.build/sp212-cli` scratch，不触碰其他任务构建目录。
- 本切片未操作设备、安装依赖、调用上游代码或远端写入；全 CLI / 根包 / 联合门禁、公共索引与 memory 由主控整合验收。经验检查将 shell 二次解析与 component 展开边界沉淀于本节，无需提交锁文件/生成文件。

- `git diff --check` 通过；`check-docs.sh` 当前仅因独立基线缺少 SP-212 全局索引登记失败（`space index must contain exactly one link for SP-212-mobile-mcp-android-contracts`），主控合并space与索引后重跑；本切片未改公共索引。
