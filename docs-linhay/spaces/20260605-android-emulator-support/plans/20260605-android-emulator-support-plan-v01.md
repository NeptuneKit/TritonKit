# 20260605 Android Emulator Support Plan v01

## 成功标准

1. Android Emulator 进入 `triton device --platform android` 的统一 host device contract。
2. Android Debug APK 可通过 `triton app --platform android` 完成安装、启动、终止和 deep link smoke。
3. 所有新能力都可被 `triton schema --json`、`triton capabilities --json`、`triton doctor --json` 发现。
4. fake adb 测试先红后绿，真实 emulator smoke 至少覆盖 list、wait-ready、screenshot、install、open-url、evidence。
5. 不新增 Web/Wails UI，不支持真机或远端 agent。

## M0. 契约设计和红灯测试

- 定义 `HostDevicePlatform.android`、`android:<serial>` target id、Android 附加字段和统一 error code。
- 新增 fake adb fixture，覆盖 `adb devices -l`、`getprop sys.boot_completed`、`screencap`、`install`、`am start`、`uiautomator dump`。
- 先补测试：
  - `DeviceCrossPlatformTests` 覆盖 `doctor/list/use/wait-ready/screenshot --platform android` schema。
  - `TKHostAdapterModelsTests` 覆盖 adb devices parser、boot completed parser、package / activity parser。
  - `AppOpenURLFlowTests` 覆盖 Android deep link source command 与 unverified warning。
- 红灯预期：schema 不认识 android、platform enum 不接受 android、fake adb parser 不存在。

## M1. Device P0

- 实现 `AndroidHostDeviceAdapter`：
  - `doctor`: 探测 `adb`、可选 `emulator`、Android SDK 路径提示。
  - `list`: 解析 `adb devices -l`，过滤/表达 `device/offline/unauthorized`。
  - `use/current/resolve`: 复用统一 selector resolver，支持 alias、`android:<serial>`、raw serial、`current`。
  - `wait-ready`: 轮询 `sys.boot_completed=1`，必要时验证 package manager 可响应。
  - `screenshot`: `adb exec-out screencap -p` 写本地 PNG。
- 输出统一 `HostDeviceTarget` / `HostDeviceArtifactOutput`，平台差异放进 Android-specific metadata。
- 错误码：`android_adb_not_found`、`android_target_offline`、`android_target_unauthorized`、`device_not_ready`、`android_screenshot_failed`、`host_command_timeout`。

## M2. App P1

- `triton app list/info/install/uninstall/launch/terminate/open-url --platform android`：
  - install: `adb install -r <apk>`
  - uninstall: `adb uninstall <package>`
  - launch: `monkey -p <package> 1` 或 schema 明确要求 package/activity 时用 `am start`
  - terminate: `am force-stop <package>`
  - open-url: `am start -a android.intent.action.VIEW -d <url> <package>`
  - info/list: `pm list packages`、`dumpsys package <package>` 的 bounded summary
- app action 返回 host action envelope，不能把 adb 成功当作业务 pass。
- 补 `triton plan open-url --platform android` 或在现有 open-url plan 中支持 `--device <android-alias>` 的推荐链路。

## M3. Observe / Action P1.5

- `triton ax --platform android --output <path.json>`：
  - 执行 `uiautomator dump /sdcard/window.xml`
  - `adb exec-out cat /sdcard/window.xml` 或 `adb pull`
  - 转为轻量 JSON artifact，不内联敏感完整 UI 到 stdout
- `triton wait --platform android --text <text>` 轮询 UIAutomator tree。
- `triton tap --platform android <text>` 从 bounds 取中心点后 `adb shell input tap x y`。
- `triton type/paste/press/swipe --platform android` 只接稳定 host input，所有输入动作标记 `runtimeScope=host-android`。

## M4. Smoke / Evidence P2

- 新增 `triton smoke android`：
  - device wait-ready
  - app install 可选
  - app open-url 或 launch
  - wait text
  - 可选 tap text
  - screenshot
  - evidence manifest
- evidence artifact taxonomy 新增或复用：
  - `android.screenshot`
  - `android.layout`
  - `android.logcat`
  - `host.android-action`
  - `host.android-device-list`
- `triton capture/evidence/replay` 读取 Android command ledger，保留 source command、elapsed、target、artifact path、redaction hint。

## M5. 真实 Emulator 验收

- 准备一个最小 Android Debug APK fixture 或使用现有可公开示例 APK。
- 真实命令链：

```bash
triton device doctor --platform android --json
triton device list --platform android --json
triton device alias set android-a --platform android --target <adb-serial> --json
triton device wait-ready --device android-a --timeout 60 --jsonl
triton device screenshot --device android-a --output /tmp/triton-android-smoke.png --json
triton app install --platform android --device android-a --apk <path.apk> --json
triton app open-url --platform android --device android-a "example://smoke" --bundle <package> --json
triton wait --platform android --device android-a --text "<expected-text>" --timeout 20 --json
triton smoke android --device android-a --bundle <package> --open-url "example://smoke" --wait-text "<expected-text>" --screenshot /tmp/triton-android-smoke.png --evidence /tmp/triton-android.tritonevidence --json
```

- 截图按规范归档到 `docs-linhay/spaces/20260605-android-emulator-support/screenshots/<YYYYMMDD>/android/`。

## M6. 文档、public skill 和门禁

- 更新：
  - `README.md`
  - `docs-linhay/dev/ai-cli-readable-control.md`
  - `docs-linhay/dev/20260520-simulator-takeover-architecture.md`
  - `TritonKit.skills/tritonkit-emulator-cli-takeover/SKILL.md`
  - `docs-linhay/memory/YYYY-MM-DD.md`
- 门禁：

```bash
swift test --package-path CLI --scratch-path .build/cli --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/cli --filter TKHostAdapterModelsTests
swift test --package-path CLI --scratch-path .build/cli --filter AppOpenURLFlowTests
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/verify.sh --local
```

## 拆分建议

1. 第一 PR：M0 + M1，只做 device P0 和 fake adb。
2. 第二 PR：M2，app lifecycle 与 deep link。
3. 第三 PR：M3 + M4，UIAutomator observe/action、smoke、evidence。
4. 第四 PR：真实 emulator fixture、README / public skill 对外使用口径、release 门禁补齐。

## 暂不沉淀为 AGENTS 规则

本计划是 Android adapter 的 feature-level 规划，不新增 repo-wide 长期规则。当前 AGENTS 已包含 emulator takeover 边界和 Android Emulator 范围，暂不需要修改。
