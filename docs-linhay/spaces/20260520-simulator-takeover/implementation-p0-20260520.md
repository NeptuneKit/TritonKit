# P0 Implementation Start - 2026-05-20

## 已实现

- 新增 `TKHostAdapterModels` shared 模型：
  - `TKSimctlCommand`：生成 P0/P1 `simctl` argv。
  - `TKHostSimulatorTarget` 与 `TKSimctlDeviceListParser`：解析 `simctl list devices available --json`。
  - `TKHostInstalledApp` 与 `TKSimctlAppInfoParser`：解析 `simctl listapps/appinfo` 的 OpenStep plist 输出，统一为结构化 App metadata。
  - `TKHostWorkspaceDefaults`：定义 workspace 默认 simulator 的 repo-local 状态文件路径。
  - `TKHostPreferencesSnapshot`：解析 App preferences plist，支持 string、bool、int、double、array、dictionary、data。
  - destructive command metadata：`erase`、`uninstall`、`install_app_data` 需要确认。
- 新增 CLI：
  - `triton sim list --json`
  - `triton sim use <udid> --json`
  - `triton sim boot <udid> --json`
  - `triton sim boot <udid> --wait --jsonl`
  - `triton sim shutdown <udid|booted> --json`
  - `triton sim screenshot --simulator <udid|booted> --output <path> --json`
  - `triton app list --simulator <udid|booted> --user-only --json`
  - `triton app info --bundle-id <id> --simulator <udid|booted> --json`
  - `triton app install --app <path.app> --simulator <udid|booted> --json`
  - `triton app launch --bundle-id <id> --simulator <udid|booted> --json`
  - `triton app terminate --bundle-id <id> --simulator <udid|booted> --json`
  - `triton app open-url <url> --simulator <udid|booted> --json`
  - `triton app container --bundle-id <id> --kind data --simulator <udid|booted> --json`
  - `triton app prefs get <key> --bundle-id <id> --simulator <udid|booted> --json`
  - `triton app prefs dump --bundle-id <id> --simulator <udid|booted> --json`
- `triton schema --command sim --json` 与 `triton schema --command app --json` 已暴露 host-side 命令。
- 新增内部实现 skill：`.agents/tritonkit-skills/internal/tritonkit-host-simulator-takeover/SKILL.md`，后续设计、实现、扩展或验证 host-side Apple Simulator 接管能力时优先使用。

## 验证

- 先补测试并确认红灯：`swift test --filter TKHostAdapterModelsTests` 因缺少 `TKSimctlCommand` / parser / preferences snapshot 编译失败。
- 实现后验证：
  - `swift test --filter TKHostAdapterModelsTests` 通过 14 个测试。
  - `swift test` 通过 59 个测试。
  - `swift build --product triton` 通过。
  - `.build/debug/triton schema --command sim --json` 输出 host-simulator schema。
  - `.build/debug/triton schema --command app --json` 输出 host-app / host-preferences schema。
  - `.build/debug/triton sim list --json` 在本机返回 simulator 列表。
  - `.build/debug/triton sim boot 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --wait --jsonl` 对已 booted simulator 返回单行 ready event。
  - 在 `/tmp/triton-sim-use-smoke` 执行 `.build/debug/triton sim use 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --json`，写入 `/private/tmp/triton-sim-use-smoke/.triton/host-defaults.json`。
  - `.build/debug/triton app list --simulator booted --user-only --json` 在本机返回 User app 列表。
  - `.build/debug/triton app info --bundle-id com.neptunekit.tritonkit.demo --simulator booted --json` 返回结构化 App metadata。
  - `.build/debug/triton app launch --bundle-id com.neptunekit.tritonkit.demo --simulator booted --json` 返回 host action envelope 和 pid stdout。
  - `.build/debug/triton app terminate --bundle-id com.neptunekit.tritonkit.demo --simulator booted --json` 返回 host action envelope。
  - `.build/debug/triton app container --bundle-id com.example.missing --simulator booted --json` 返回稳定 `app_container_not_found` error code。
  - `.build/debug/triton app info --bundle-id com.example.missing --simulator booted --json` 返回稳定 `app_info_not_available` error code。

## 下一步

- P0 继续补 `app uninstall --confirm`、`sim privacy/location/ui` 与 host screenshot/video/media/contact 等环境准备能力。
- 将 host-side action 纳入 `.tritonplan` schema v2。
- 将 `capture/evidence --include host` 接入 host artifacts。
