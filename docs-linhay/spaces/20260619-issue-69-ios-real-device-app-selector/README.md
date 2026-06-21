# Issue #69: iOS Real Device App Selector

## 背景

GitHub Issue #69 反馈：triton device list --platform ios --json 可以发现 iOS 真机并输出 ios-real:<hash> target，但随后执行 triton app list --device ios-real:<hash> --user-only --json 会返回 target_not_found。同一台设备使用 CoreDevice identifier 或 UDID 传给 --device 也无法被 host-side app 命令解析，导致 agent 被迫 fallback 到裸 xcrun devicectl device info apps。

问题根因在 selector 发现范围和别名匹配：

1. iOS app 命令未显式传 --scope real 时默认只发现 simulator，导致 ios-real:<hash> 永远不在候选集内。
2. devicectl parser 只保留 CoreDevice identifier 作为内部 raw target，未把 JSON 中可能出现的 UDID / unique device id / serial 作为只读 selector alias。

## 目标

1. triton app list --device ios-real:<hash> --user-only --json 不再因为默认 simulator scope 返回 target_not_found。
2. iOS real-device selector 可匹配 targets[].id / targets[].target 中的 ios-real:<hash>、devicectl CoreDevice identifier，以及 devicectl JSON 中可解析到的 UDID / unique device id / serial alias。
3. 敏感 identifier / UDID / serial 只用于本地匹配和传给 host tool，不进入 HostDeviceTarget 的 Encodable JSON 输出。
4. 保持 booted 语义指向 iOS Simulator，不因 real-device discovery 扩展而变成真机歧义。

## 非目标

1. 不新增真机系统级 HID / 截图能力。
2. 不修改签名、证书、Developer Mode、trust 或 provisioning。
3. 不把 raw devicectl 输出作为对外稳定 JSON；仍只通过 Triton normalized envelope / artifact 说明执行结果。
4. 不在本轮要求连接真实 iPhone 做 smoke；真实设备信息需脱敏，自动化测试覆盖 selector 和 parser contract。

## BDD 验收

### 场景一：app 命令接受 device list 返回的 real-device id

- Given triton device list --platform ios --json 返回 targets[].id = ios-real:<hash>
- When agent 执行 triton app list --device ios-real:<hash> --user-only --json
- Then iOS target discovery 应包含 real-device 候选
- And selector 匹配该真机 target
- And 后续 devicectl app list command 使用内部 raw CoreDevice identifier

### 场景二：app 命令接受 CoreDevice identifier / UDID selector

- Given devicectl JSON 中存在 CoreDevice identifier 与 UDID / unique device id / serial alias
- When agent 以任一 selector 调用 host-side app 命令
- Then resolver 应解析到同一个 ios-real:<hash> target
- And JSON 输出仍不暴露这些敏感 selector

### 场景三：booted 仍保持 simulator 语义

- Given agent 执行 triton app list --device booted --json
- When 未显式指定 --scope real
- Then discovery scope 仍为 simulator
- And 不把 ready iOS 真机纳入 booted 匹配。

## 实现摘要

1. TKDevicectlDeviceTarget 增加 alternateIdentifiers，提取 devicectl JSON 中的 UDID、unique device id 和 serial alias。
2. HostDeviceTarget 增加未编码的 rawTargetAliases，用于本地 selector 匹配，不进入 CodingKeys。
3. explicitHostDeviceMatch / selectHostDeviceTarget 支持 rawTargetAliases。
4. hostDeviceDiscoveryScope(for:) 对显式 iOS selector 默认扩展到 .all，但 booted 固定 .simulator，无显式 selector 时保留原默认。

## 验证

- swift test --package-path CLI --scratch-path .build/cli-issue69-green --filter 'DeviceCrossPlatformTests|TKHostAdapterModelsTests'
  - CLI package 实际运行 DeviceCrossPlatformTests：80 tests passed。
- swift test --scratch-path .build/issue69-shared --filter TKHostAdapterModelsTests
  - Root package TKHostAdapterModelsTests：36 tests passed。

## 剩余风险

1. 本轮未连接真实 iOS 设备跑 live smoke；修复通过 parser / resolver / planner 层测试验证。
2. triton app list 对 iOS real device 仍返回 host action / artifact 摘要，不在本轮扩展为解析完整 installed apps 列表。
