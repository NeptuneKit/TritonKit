# 20260608 iOS Real Device Takeover

> Note: 用户后续要求“三端一起规划”，三端真机总方案已落到 `docs-linhay/spaces/20260608-cross-platform-real-device-takeover/`。本 space 保留为 Apple / `devicectl` 细化材料，后续实现边界以三端总方案为准。

## 背景

TritonKit 当前 Apple 侧主线是本机 iOS Simulator + Xcode workflow 接管。真机曾在 `20260520-xcode-workflow-takeover` 中作为 P2/P3 能力占位，但全局边界明确禁止把真机悄悄并入 emulator takeover。因此本 space 单独定义 iOS 真机接入方案，重新确认产品边界、机器可读契约、安全策略和验收路径。

本方案面向本机 Mac + 本机连接或配对的 iOS/iPadOS 真机，不扩展到远端 agent、设备云、多租户、真机农场或 Web/Wails 控制台。

## 目标

1. 让 agent 能通过 `triton` 发现、选择、诊断、构建、安装、启动和验证 iOS 真机 App。
2. 将 Xcode signing / provisioning / Developer Mode / trust / pairing / DDI 等真机阻塞点变成机器可读诊断，而不是散落在人读日志中。
3. 复用现有 `triton device`、`triton app`、`triton xcode`、`triton logs`、`triton evidence` 信息架构，避免新增平行入口。
4. 保持业务控制能力优先落在 CLI/HTTP schema；Web/Wails 不进入首期。
5. 真机首期只承诺 App 安装、启动、App 内 embedded runtime 观察控制和证据，不承诺系统级 HID、SpringBoard 自动化、设备云或越权截图。

## 非目标

1. 不做远端真机、USB over network、设备云调度或 CI farm。
2. 不自动修改 Apple ID、证书、描述文件、Team、Bundle ID 或 Xcode signing 设置。
3. 不把 `devicectl` stdout 当成稳定解析接口；只消费 `--json-output <path>` 产物。
4. 不首期实现真机系统级 tap/type/home/app-switcher/隐私授权弹窗处理。
5. 不要求 Release App 连接 TritonKit；业务 App 仍必须使用 Debug bootstrap + `#if DEBUG`。
6. 不把真机引入现有 simulator takeover space；真机实现和验收独立推进。

## 用户故事

1. 作为 agent，我进入一个真实 iOS App 仓库后，可以知道这台 Mac 上有没有可用真机，以及不可用时的具体阻塞。
2. 作为 agent，我能选择一个稳定真机别名，并把它用于后续 build/install/launch/smoke。
3. 作为 agent，我能构建 Debug 真机包，若签名失败，拿到结构化错误和下一步建议，而不是解析整段 xcodebuild 文本。
4. 作为 agent，我能把 `.app` 安装到真机并启动指定 bundle id 或 URL。
5. 作为 agent，我能等待 embedded runtime 建连后继续执行 `status/wait/find/assert/evidence`。
6. 作为维护者，我能从 `.tritonevidence` 中看到真机、Xcode、devicectl、runtime 的最小必要证据，并默认脱敏私有标识。

## BDD 场景

### 场景一：真机工具诊断

- Given 本机安装 Xcode Command Line Tools
- When 执行 `triton device doctor --platform ios --scope real --json`
- Then 输出 `xcrun`、`devicectl`、`xcodebuild`、`xctrace`、`lldb` 可用性
- And 输出 CoreDevice JSON schema 版本、Xcode 版本摘要和建议下一步
- And 缺工具时返回稳定错误码与恢复命令

### 场景二：真机列表与状态归一

- Given Mac 上存在已连接、离线、未信任或不可用的 iOS 设备
- When 执行 `triton device list --platform ios --scope real --json`
- Then 输出 `targets[]`，每个 target 至少包含 `platform=ios`、`kind=real-device`、`id`、`name`、`runtime`、`state`、`ready`、`source=devicectl`
- And `ready=false` 的设备必须给出 `blockedReasons[]`
- And 默认不输出完整序列号、UDID、ECID 等私有标识，除非显式 `--include-sensitive`

### 场景三：选择真机别名

- Given 真机列表存在多个候选
- When 执行 `triton device use iphone-dev --json`
- Then `.triton/host-targets.json` 记录 alias 到真实设备 target
- And 后续 `triton app`、`triton xcode`、`triton logs` 可通过 `--device iphone-dev` 复用
- And alias 指向离线设备时返回 `target_offline`，不自动改选另一台设备

### 场景四：真机构建签名预检

- Given 已选择真机、workspace、scheme 和 Debug configuration
- When 执行 `triton xcode build --device iphone-dev --platform ios --jsonl`
- Then `xcodebuild` destination 使用真机目标或 generic iOS 目标
- And JSONL 输出 signing、provisioning、build progress 和 final summary
- And 签名失败返回 `xcode_signing_failed`、`provisioning_profile_missing`、`developer_mode_required` 或 `device_not_trusted` 等可恢复错误
- And 不自动修改 Xcode signing 资产

### 场景五：安装与启动 App

- Given 已获得 Debug `.app` 产物
- When 执行 `triton app install --device iphone-dev --app /tmp/Demo.app --json`
- Then 通过 `devicectl device install app --json-output <path>` 安装，并返回 normalized summary
- When 执行 `triton app launch --device iphone-dev --bundle-id com.example.demo --json`
- Then 通过 `devicectl device process launch --json-output <path>` 启动，并返回 pid、bundle id、device target 和 source artifact

### 场景六：启动后 runtime ready

- Given App 以 Debug bootstrap 启动 TritonKit embedded runtime
- When 执行 `triton app launch --device iphone-dev --bundle-id com.example.demo --wait-ready --json`
- Then host launch 成功后继续等待 runtime target 出现在 `triton status --json`
- And 成功时返回 runtime target binding
- And 失败时区分 `app_launch_failed`、`runtime_not_connected`、`network_unreachable`、`debug_runtime_disabled`

### 场景七：真机 smoke 验证

- Given App 已安装且 runtime 可用
- When 执行 `triton smoke ios --device iphone-dev --bundle-id com.example.demo --open-url example://debug --wait-text Ready --json`
- Then 依次完成 launch/open-url、runtime wait、assert、evidence
- And 产出 `.tritonevidence` manifest，包含 redacted device identity、Xcode summary、devicectl artifact 摘要和 runtime snapshot

### 场景八：真机日志采集

- Given App 已在真机运行
- When 执行 `triton logs collect --device iphone-dev --bundle-id com.example.demo --duration 10 --output /tmp/logs --json`
- Then 采集有界日志 artifact
- And summary 只返回路径、bytes、过滤条件和截断状态
- And 私有路径、账号、token 和设备标识默认脱敏

## 验收标准

1. `triton schema --command device --json` 暴露 iOS real-device scope、错误码、next commands 和 output contracts。
2. `triton schema --command app --json` 暴露真机 install/launch/terminate/open-url 的参数和失败码。
3. `triton schema --command xcode --json` 可描述 `--device <selector>` 的真机构建/测试/运行路径。
4. 无真机、离线真机、未信任真机、签名失败、runtime 未建连都能返回稳定 JSON 错误。
5. 真机成功路径能完成 `doctor -> list -> use -> xcode build -> app install -> app launch --wait-ready -> assert -> evidence`。
6. 自动化测试覆盖 adapter parser、command builder、schema、错误映射和证据脱敏；真实真机 smoke 作为可选本地验收，不阻塞普通 CI。

## 关联资料

- `docs-linhay/spaces/20260520-xcode-workflow-takeover/README.md`
- `docs-linhay/spaces/20260520-xcode-workflow-takeover/technical-design.md`
- `docs-linhay/dev/20260520-simulator-takeover-architecture.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`
- `docs-linhay/dev/agent-facing-cli-information-architecture.md`
