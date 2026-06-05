# 20260605 Android Emulator Execution Breakdown v01

## 使用方式

这份文档是 Android Emulator 支持的逐步执行清单。每个步骤都应按 BDD/TDD 执行：先补场景和失败测试，再实现，再验证，再写回文档与 memory。

默认 feature 映射：

| 项 | 值 |
| --- | --- |
| space | `docs-linhay/spaces/20260605-android-emulator-support/` |
| branch | `feat/20260605-android-emulator-support` |
| worktree | `../TritonKit-worktrees/20260605-android-emulator-support/` |
| product boundary | 本机 CLI + 本机 Android Emulator |
| default target selector | `--device <selector>` |
| platform id | `android:<adb-serial>` |

若只做短期规划或单个小补丁，可以在主工作区短分支完成；若进入多日实现，必须使用上表 worktree。

项目级 Codex subagent 配置位于 `.codex/agents/`，编排 skill 为 `.agents/skills/tritonkit-android-subagent-orchestration/SKILL.md`。真正开始执行时，主控 agent 应先使用该 skill 再分批调用 subagents。

## 全局验收

| 验收项 | 完成条件 |
| --- | --- |
| CLI 契约 | `triton schema --command device|app|ax|wait|tap|screenshot --json` 暴露 Android 相关参数、输出和 failure codes |
| capability matrix | `triton capabilities --json` 暴露 Android device/app/observe/action/smoke/evidence 能力，且 group/requiredBy/evidence 不落 `misc` |
| doctor | `triton device doctor --platform android --json` 能报告 adb/emulator/SDK 路径与恢复建议 |
| fake adb | 无真实 emulator 也能跑完 parser、command builder、schema 和错误码测试 |
| real emulator | 真机具备时完成 list、wait-ready、screenshot、install、open-url、wait/assert、smoke/evidence |
| 文档 | README、dev docs、public skill、memory 同步 |
| 门禁 | `docs-linhay/scripts/verify.sh --local` 通过，或明确说明阻塞与风险 |

## Step 0. 开工准备

| Step | 动作 | 产出 | 验证 |
| --- | --- | --- | --- |
| 0.1 | 确认当前工作区状态：`git status --short --branch` | 记录是否干净 | 不改动用户未提交文件 |
| 0.2 | 若多日开发，创建 worktree：`git worktree add ../TritonKit-worktrees/20260605-android-emulator-support -b feat/20260605-android-emulator-support main` | 独立执行目录 | worktree 路径不在主仓内部 |
| 0.3 | 读取现有 iOS/Harmony host adapter、device tests、schema tests | 文件影响面清单 | 不凭记忆改代码 |
| 0.4 | 运行当前基线：`docs-linhay/scripts/verify.sh --ci-docs` 与定向 Swift tests | 基线结果 | 若基线失败，先记录与本需求无关的既有失败 |

建议优先阅读：

```text
Sources/TritonKitCLI/CLIHostCommands.swift
Sources/TritonKitCLI/CLIHostRuntime.swift
Sources/TritonKitCLI/CLIHostModels.swift
Sources/TritonKitCLI/CLISchemaHostCommands.swift
Sources/TritonKitCLI/CLIObservationCommands.swift
Sources/TritonKitCLI/CLIObservationRuntime.swift
CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift
CLI/Tests/TritonKitCLITests/AppOpenURLFlowTests.swift
Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift
```

## Step 1. 契约先行

| Step | 先写的测试 | 预期红灯 |
| --- | --- | --- |
| 1.1 | `DeviceCrossPlatformTests` 断言 `device` schema usage forms 包含 `ios|harmony|android` | schema 仍只有 iOS/Harmony |
| 1.2 | `DeviceCrossPlatformTests` 断言 `providedCapabilities` 包含 `android-device-doctor/list/wait-ready/screenshot` | capabilities 缺失 |
| 1.3 | `TKHostAdapterModelsTests` 断言 `HostDevicePlatform` 可 decode/encode `android` | enum 不支持 |
| 1.4 | `TKHostAdapterModelsTests` 断言 Android target id 生成 `android:emulator-5554` | helper 不存在 |
| 1.5 | `FailureDiagnosticsTests` 断言 Android failure codes 有 recovery category | failure code 未注册 |

实现要求：

- `HostDevicePlatform` 新增 `android`，但保持 iOS/Harmony 兼容。
- target id 统一为 `android:<serial>`，raw target 保留为 `<serial>`。
- error code 使用 lower snake case。
- schema examples 必须是单条 `triton ...` 命令，不能使用管道或重定向。

完成验证：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/cli --filter TKHostAdapterModelsTests
swift test --package-path CLI --scratch-path .build/cli --filter FailureDiagnosticsTests
```

## Step 2. fake adb fixture

| Step | 动作 | 产出 |
| --- | --- | --- |
| 2.1 | 新增 fake adb 脚本或测试内 runner stub | 可模拟 adb stdout/stderr/exit code |
| 2.2 | fixture 覆盖 `adb version` | doctor parser 输入 |
| 2.3 | fixture 覆盖 `adb devices -l` 空列表、单 emulator、多 emulator、offline、unauthorized | list parser 输入 |
| 2.4 | fixture 覆盖 `shell getprop sys.boot_completed` 的 `0/1/timeout/error` | wait-ready 输入 |
| 2.5 | fixture 覆盖 `exec-out screencap -p` PNG bytes 和失败输出 | screenshot 输入 |
| 2.6 | fixture 覆盖 `install -r`、`uninstall`、`am start`、`am force-stop` | app lifecycle 输入 |
| 2.7 | fixture 覆盖 `uiautomator dump` 与 XML 输出 | observe/action 输入 |

建议 fixture 场景名：

```text
android-adb-devices-empty
android-adb-devices-single-ready
android-adb-devices-multiple-ready
android-adb-devices-offline
android-adb-devices-unauthorized
android-boot-completed-false
android-boot-completed-true
android-screencap-success
android-uiautomator-layout-basic
```

完成验证：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter TKHostAdapterModelsTests
```

## Step 3. Android device doctor

| Step | 动作 | 输出要求 |
| --- | --- | --- |
| 3.1 | 实现 `device doctor --platform android` 参数解析，支持 `--adb <path>` 和可选 `--emulator <path>` | CLI 可解析 |
| 3.2 | 调用 `adb version`，提取版本摘要 | `checks[].id=android-adb` |
| 3.3 | 尝试定位 Android SDK：显式参数、`ANDROID_HOME`、`ANDROID_SDK_ROOT`、PATH | `environment` 摘要 |
| 3.4 | 可选调用 `emulator -version`，失败不阻断 adb P0 | warn 而非 fail |
| 3.5 | 缺 adb 时返回 `android_adb_not_found` | `nextAction.category=diagnose` |

验收命令：

```bash
triton device doctor --platform android --json
triton device doctor --platform android --adb /bad/adb --json
triton schema --command device --json
triton capabilities --json
```

## Step 4. Android device list

| Step | 动作 | 输出要求 |
| --- | --- | --- |
| 4.1 | 解析 `adb devices -l` header 与 target 行 | 跳过 header |
| 4.2 | 将 `emulator-5554 device product:... model:... device:... transport_id:...` 转成 `HostDeviceTarget` | `ready=true` |
| 4.3 | 将 `offline` 转成 target，但 `ready=false` | 不作为 defaultTarget |
| 4.4 | 将 `unauthorized` 转成 target，但 `ready=false` | 错误恢复指向 doctor |
| 4.5 | 唯一 ready target 时给出 `defaultTarget` | selector 可复用 |
| 4.6 | 多 ready target 时不默认选择 | 防止误控 |

关键 DTO：

```json
{
  "platform": "android",
  "id": "android:emulator-5554",
  "target": "emulator-5554",
  "state": "device",
  "ready": true,
  "source": "adb",
  "metadata": {
    "model": "Pixel_8",
    "transportId": "1"
  }
}
```

验收命令：

```bash
triton device list --platform android --json
triton device resolve --platform android --ready --json
triton device alias set android-a --platform android --target emulator-5554 --json
```

## Step 5. Selector / alias / current

| Step | 动作 | 验收 |
| --- | --- | --- |
| 5.1 | 让 `device alias set` 接受 `--platform android` | alias 文件写 `android:<serial>` |
| 5.2 | 让 `device use android-a` 解析 alias | `current` 指向 Android target |
| 5.3 | 让 `device resolve android:<serial>` 直通 | 输出目标 |
| 5.4 | 让 raw serial `emulator-5554` 在 platform 唯一时可解析 | 兼容 adb 原生 id |
| 5.5 | 多平台 raw id 冲突时返回 `ambiguous_target` | 不隐式选平台 |

回归点：

- iOS `sim:<udid>` 不受影响。
- Harmony `harmony:<target>` 不受影响。
- `current` 只保存稳定 selector，不保存过滤词。

## Step 6. wait-ready

| Step | 动作 | 输出要求 |
| --- | --- | --- |
| 6.1 | 解析 `--device` / `--platform --target` | 兼容统一入口 |
| 6.2 | 每轮执行 `adb -s <serial> shell getprop sys.boot_completed` | JSONL progress |
| 6.3 | ready 后可补查 `adb -s <serial> shell pm path android` | 确认 package manager 响应 |
| 6.4 | offline/unauthorized 立即返回可分类错误 | 不等待到 timeout |
| 6.5 | timeout 返回 `device_not_ready` | 带 elapsed、attempts |

JSONL 事件建议：

```text
device.wait.started
device.wait.poll
device.wait.ready
device.wait.timeout
```

验收命令：

```bash
triton device wait-ready --device android-a --timeout 60 --interval 1 --jsonl
triton device wait-ready --platform android --target emulator-5554 --timeout 5 --json
```

## Step 7. screenshot

| Step | 动作 | 输出要求 |
| --- | --- | --- |
| 7.1 | 执行前复用 target resolve 与 ready check | 未 ready 快速失败 |
| 7.2 | 执行 `adb -s <serial> exec-out screencap -p` | 本地写 PNG |
| 7.3 | 输出 `HostDeviceArtifactOutput` | `artifact.format=png` |
| 7.4 | 写文件失败返回 archive 类 recovery | `artifact_write_failed` |
| 7.5 | adb 截图失败返回 Android 专属 code | `android_screenshot_failed` |

验收命令：

```bash
triton device screenshot --device android-a --output /tmp/triton-android-smoke.png --json
file /tmp/triton-android-smoke.png
```

截图归档：

```text
docs-linhay/spaces/20260605-android-emulator-support/screenshots/20260605/android/20260605-android-device-screenshot-after-v01.png
```

## Step 8. App lifecycle

| Step | 命令 | 底层 adb |
| --- | --- | --- |
| 8.1 | `app install --platform android --apk <path.apk>` | `adb -s <serial> install -r <path.apk>` |
| 8.2 | `app uninstall --platform android --bundle <package>` | `adb -s <serial> uninstall <package>` |
| 8.3 | `app launch --platform android --bundle <package>` | `adb -s <serial> shell monkey -p <package> 1` |
| 8.4 | `app launch --platform android --bundle <package> --activity <activity>` | `adb -s <serial> shell am start -n <package>/<activity>` |
| 8.5 | `app terminate --platform android --bundle <package>` | `adb -s <serial> shell am force-stop <package>` |
| 8.6 | `app open-url --platform android <url> --bundle <package>` | `adb -s <serial> shell am start -a android.intent.action.VIEW -d <url> <package>` |
| 8.7 | `app list/info --platform android` | bounded `pm list packages` / `dumpsys package` |

测试顺序：

1. command builder 单元测试。
2. fake adb success/failure runtime 测试。
3. `AppOpenURLFlowTests` 断言 host action warning：`unverified_host_action`。
4. schema output contract 测试。

完成标准：

- app action 输出 `runtimeScope=host-android`。
- `sourceCommands[]` 保留脱敏后的 adb 命令。
- install/open-url 成功后 `nextAction` 指向 wait/assert/screenshot/evidence。

## Step 9. Android UIAutomator observe

| Step | 动作 | 输出 |
| --- | --- | --- |
| 9.1 | `triton ax --platform android --output <path.json>` | host layout artifact |
| 9.2 | 执行 `adb shell uiautomator dump /sdcard/window.xml` | 远端 XML |
| 9.3 | 执行 `adb exec-out cat /sdcard/window.xml` 或 `adb pull` | 本地输入 |
| 9.4 | 解析 XML `node` 的 `text/resource-id/content-desc/bounds/class/clickable/enabled` | 轻量 JSON |
| 9.5 | stdout 只输出 artifact path 和摘要 | 不内联完整敏感 UI |

布局 JSON 建议字段：

```json
{
  "platform": "android",
  "target": "android:emulator-5554",
  "artifact": "/tmp/layout.json",
  "nodes": [
    {
      "text": "Login",
      "resourceId": "com.example:id/login",
      "bounds": [120, 880, 960, 980],
      "clickable": true
    }
  ]
}
```

## Step 10. wait / tap / input

| Step | 命令 | 行为 |
| --- | --- | --- |
| 10.1 | `wait --platform android --text <text>` | 轮询 UIAutomator layout |
| 10.2 | `wait --platform android --gone <text>` | 直到文本不存在 |
| 10.3 | `tap <text> --platform android` | 找第一个匹配节点 bounds 中心点 |
| 10.4 | `tap --platform android --at x,y` | 直接坐标点击 |
| 10.5 | `swipe --platform android --start-x ...` | `adb shell input swipe` |
| 10.6 | `type <text> --platform android` | `adb shell input text`，先处理空格/特殊字符策略 |
| 10.7 | `press back|home|enter --platform android` | `adb shell input keyevent` |

失败策略：

- 文本不存在：`text_not_found`，recovery category 为 `verify`。
- 多候选：默认第一个，但 `--index` / `--within` 后续可补；首期至少输出 candidates 摘要。
- input 不支持字符：返回 `android_input_text_unsupported`，不要静默替换。

## Step 11. smoke android

| Step | 子步骤 | 停止条件 |
| --- | --- | --- |
| 11.1 | resolve device | target 缺失停止 |
| 11.2 | wait-ready | not ready 停止 |
| 11.3 | optional install | install failed 停止 |
| 11.4 | launch/open-url | host action failed 停止 |
| 11.5 | wait text | assertion failed 停止 |
| 11.6 | optional tap text | tap failed 停止 |
| 11.7 | optional post-tap wait | assertion failed 停止 |
| 11.8 | screenshot | artifact failed 时 smoke 可失败但仍写已有 evidence |
| 11.9 | evidence manifest | archive failed 单独返回 archive error |

命令目标：

```bash
triton smoke android \
  --device android-a \
  --apk <path.apk> \
  --bundle <package> \
  --open-url "example://smoke" \
  --wait-text "<expected-text>" \
  --screenshot /tmp/triton-android-smoke.png \
  --evidence /tmp/triton-android.tritonevidence \
  --json
```

## Step 12. Evidence / capture / replay 对齐

| Step | 动作 | 输出 |
| --- | --- | --- |
| 12.1 | artifact taxonomy 增加 Android 项 | `android.screenshot`、`android.layout`、`android.logcat` |
| 12.2 | command ledger 写 Android host actions | `host.android-action` |
| 12.3 | evidence manifest 标记敏感 artifact | redaction hint |
| 12.4 | `evidence inspect` 可展示 Android artifact 摘要 | 不暴露隐私内容 |
| 12.5 | `.tritonplan` 支持 Android smoke steps | `argv/category/requires/expectedArtifacts/stopConditions` |
| 12.6 | `replay --dry-run` 静态校验 Android step | 不触碰 emulator |

## Step 13. schema / capabilities / doctor 收口

| Step | 检查项 | 要求 |
| --- | --- | --- |
| 13.1 | `providedCapabilities[]` | 每个 Android 命令有能力名 |
| 13.2 | `outputContracts[]` | selector/model/fields 完整 |
| 13.3 | `failureCodes[]` | command/subcommand 覆盖一致 |
| 13.4 | `recoveryCommands[]` | category 属于固定 taxonomy |
| 13.5 | `capabilities --json` | group/requiredBy/evidence 非空且唯一 |
| 13.6 | `doctor --json` | top-level primary next action 能指向 Android 恢复入口 |
| 13.7 | examples | 每个 example 只有一条 `triton` invocation |

定向验证：

```bash
triton schema --command device --json
triton schema --command app --json
triton schema --command ax --json
triton schema --command wait --json
triton schema --command tap --json
triton capabilities --json
triton device doctor --platform android --json
```

## Step 14. 真实 Android Emulator smoke

前置：

| Step | 动作 | 说明 |
| --- | --- | --- |
| 14.1 | 定位 adb：`which adb` 或 Android Studio SDK path | 记录版本 |
| 14.2 | 启动 Android Emulator | 可手动或通过 Android Studio |
| 14.3 | 确认 `adb devices -l` 可见 `emulator-* device` | 不使用真机 target |
| 14.4 | 准备 Debug APK | 可用公开 fixture |

执行：

```bash
triton device doctor --platform android --json
triton device list --platform android --json
triton device alias set android-a --platform android --target <adb-serial> --json
triton device wait-ready --device android-a --timeout 60 --jsonl
triton device screenshot --device android-a --output /tmp/triton-android-before.png --json
triton app install --platform android --device android-a --apk <path.apk> --json
triton app open-url --platform android --device android-a "example://smoke" --bundle <package> --json
triton wait --platform android --device android-a --text "<expected-text>" --timeout 20 --json
triton device screenshot --device android-a --output /tmp/triton-android-after.png --json
triton smoke android --device android-a --bundle <package> --open-url "example://smoke" --wait-text "<expected-text>" --screenshot /tmp/triton-android-smoke.png --evidence /tmp/triton-android.tritonevidence --json
```

归档：

- before/after PNG 放入对应 space screenshots。
- 关键 JSON 输出脱敏后放入 plan 验证记录。
- `.tritonevidence` 若含截图或业务信息，不进入公开 issue；只记录路径和 manifest 摘要。

## Step 15. 文档与 public skill

| Step | 文件 | 更新内容 |
| --- | --- | --- |
| 15.1 | `README.md` | Android CLI install/run quickstart |
| 15.2 | `docs-linhay/dev/ai-cli-readable-control.md` | Android agent-facing commands、output contract、failure codes |
| 15.3 | `docs-linhay/dev/20260520-simulator-takeover-architecture.md` | Android P0/P1 状态 |
| 15.4 | `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md` | Android 当前实现 surface 与示例 |
| 15.5 | `docs-linhay/memory/YYYY-MM-DD.md` | 决策、验证、残留风险 |
| 15.6 | `docs-linhay/scripts/check-docs.sh` | 结构自检，如需新增规则再补 |

如本次产生通用、重复使用的 Android fake-adb 或 host-adapter 流程，再考虑更新 public skill；若只是本 feature 的实现细节，不写入 `AGENTS.md`。

## Step 16. PR 拆分

| PR | 包含步骤 | 通过条件 |
| --- | --- | --- |
| PR 1 | Step 1-7 | Android device doctor/list/use/wait-ready/screenshot fake 测试通过，schema/capabilities 对齐 |
| PR 2 | Step 8 | app lifecycle fake 测试通过，open-url 返回 unverified host action |
| PR 3 | Step 9-10 | UIAutomator ax/wait/tap/type/press 基础能力 fake 测试通过 |
| PR 4 | Step 11-12 | smoke/evidence/replay dry-run 对齐 |
| PR 5 | Step 13-15 | 真实 emulator smoke、docs、public skill、memory、完整 local gate |

每个 PR 都必须独立可回归，不能把前一 PR 的失败留给后一 PR 修。

## Step 16A. Subagent 编排

| Agent | Codex config | 负责步骤 | 并行批次 |
| --- | --- | --- | --- |
| Contract | `.codex/agents/tritonkit_android_contract_agent.toml` | Step 1, Step 13 | Batch 1 |
| Fake ADB | `.codex/agents/tritonkit_android_fake_adb_agent.toml` | Step 2 | Batch 1 |
| Device | `.codex/agents/tritonkit_android_device_agent.toml` | Step 3-7 | Batch 2 |
| App | `.codex/agents/tritonkit_android_app_agent.toml` | Step 8 | Batch 2 |
| Observe Smoke | `.codex/agents/tritonkit_android_observe_smoke_agent.toml` | Step 9-12, Step 14 | Batch 3 |

主控 agent 保留 Step 0、Step 15、Step 16、Step 17，并负责合并结果、跑门禁、真实 emulator 验收、docs/memory/qmd 收口和最终完成判断。

启动 subagents 前先使用 `tritonkit-android-subagent-orchestration`，避免职责漂移或多个 subagent 同时写同一批文件。

## Step 17. 最终门禁

最小定向门禁：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/cli --filter TKHostAdapterModelsTests
swift test --package-path CLI --scratch-path .build/cli --filter AppOpenURLFlowTests
swift test --package-path CLI --scratch-path .build/cli --filter FailureDiagnosticsTests
docs-linhay/scripts/check-docs.sh
```

完整本地门禁：

```bash
docs-linhay/scripts/verify.sh --local
```

完成定义：

1. BDD 场景全部满足。
2. fake adb 和真实 emulator smoke 都有记录。
3. 所有 Android CLI 输出都是 JSON / JSONL / artifact，不依赖裸 adb 人读输出。
4. 失败路径有稳定 error code 和 recovery nextAction。
5. 文档、memory、qmd 同步完成。
