# iOS integration guide

## 背景

TritonKit 需要在仓库 README 和项目级 skill 中提供 iOS 侧接入指南，便于外部使用者和 AI agent 直接完成 SwiftPM / CocoaPods 接入、App 侧启动和 CLI 验证。

## 验收场景

### 场景 1：使用者从 README 完成 iOS 接入

- Given 使用者首次打开仓库
- When 阅读 `README.md`
- Then 能看到 SwiftPM 与 CocoaPods 的接入方式
- And 能看到 SwiftPM 支持 configuration-scoped build settings、但没有 CocoaPods-style Debug-only product dependency switch 的限制与替代策略
- And 能看到文件级 `#if DEBUG` 包裹的 `TritonKitDebugBootstrap.swift` 示例，并优先使用 `TritonKit.shared.start()` / `start { config in ... }` facade
- And AppDelegate / SwiftUI 入口只保留 `#if DEBUG` 调用点
- And 能看到 CLI server 启动与 `status/list/hierarchy/ax` 验证命令
- And 能看到真机本地网络与 ATS 注意事项

### 场景 2：AI agent 从 skill 帮用户接入

- Given AI agent 使用 `tritonkit-dev-feedback` skill 帮用户试用或接入 TritonKit
- When 用户需要 iOS 侧接入指导
- Then skill 提供同样的 package manager、App bootstrap、CLI verification 和 network notes
- And 若接入过程暴露需求、bug 或文档缺口，AI agent 继续负责提交 GitHub issue

## 接入口径

1. SwiftPM：添加 `https://github.com/NeptuneKit/TritonKit.git`，只选择 `TritonKit` product；用户不要手动选择或导入内部 TritonKit target。SwiftPM 支持 configuration-scoped build settings，TritonKit 通过 `TRITONKIT_RUNTIME_ENABLED` 在 Debug package build 启用 runtime；但 SwiftPM / Xcode package product dependency 没有 CocoaPods 这种 `:configurations => ['Debug']` 开关，因此业务 App 源码中所有 `import TritonKit` 与启动代码仍必须由 `#if DEBUG` 显式包住。若生产 Release target 必须完全不链接 TritonKit，则使用独立 Debug-only app target / scheme，并只在那里挂 `TritonKit` product。
2. CocoaPods：开发阶段用户 Podfile 只显式添加 `TritonKit` pod，并指向 `main` 分支；Podfile 示例必须加 `:configurations => ['Debug']`，不得手写 sibling TritonKit pod。`TritonKit.podspec` 会为 pod target 的 Debug 配置定义 `TRITONKIT_RUNTIME_ENABLED`，业务 App target 不需要另写 `OTHER_SWIFT_FLAGS`。
3. App 侧：优先新建独立 `TritonKitDebugBootstrap.swift`，整个文件从 `import TritonKit` 到 `TritonKit.shared.start()` / `start { config in ... }` 都包在文件级 `#if DEBUG` 内；`start` 会内部强持有默认 `TritonKitRequestHandler`，业务侧不需要自己保存 handler。
4. 启动入口：AppDelegate、SceneDelegate 或 SwiftUI `onAppear` 只保留 `#if DEBUG` 调用点，例如 `TritonKitDebugBootstrap.start()`；不要把 TritonKit 符号散落在生产入口文件里。
5. CLI 侧：模拟器优先 `triton serve --host 127.0.0.1 --port 19421`；真机使用 `0.0.0.0` 监听并把 `TRITON_HOST` 设为 Mac LAN IP。
6. 验证：使用 `triton status --json`、`triton list --json`、`triton debug hierarchy --json`、`triton debug ax --json`。
7. Release：public API 保持可编译，但 Release package build 和 CocoaPods Release 配置都不定义 `TRITONKIT_RUNTIME_ENABLED`，因此 `TritonKit.isRuntimeEnabled == false`，runtime 不连接、不采集、不上传、不响应控制；接入示例仍必须显式 `#if DEBUG`，不能只依赖 no-op。

## 真机 host launch 成功但 runtime 未连接（#213）

`app install/launch` 成功只证明 host 命令提交成功；USB 已连接、Developer Mode ready 不等于 embedded runtime 已连接。`smoke ios` 的 host step 保持 `businessReady=false`，只有 runtime wait/assert 才能证明业务就绪。`runtime.connect/runtime_not_connected` 时停止，不把缺失 evidence 当成通过。

1. App 必须使用 Debug 构建，并通过文件级 `#if DEBUG` bootstrap 启动 TritonKit。若 bootstrap 使用 `startIfEnabled`，需同时设置 `TRITON_ENABLED=1`；Release no-op 不可用于 smoke。
2. 在可信开发网络中，由操作者显式启动 `triton serve --host 0.0.0.0 --port 19421`，或绑定指定 Mac LAN 地址。`0.0.0.0` 是监听地址，不是 App endpoint；设备上的 `127.0.0.1` 指向设备自身。禁止自动扩展监听面，不把未认证开发服务暴露到公网。已有 server 占端口时先确认其归属，不擅自停止其它会话的服务。
3. 允许 Debug App 的本地网络访问，确认 Mac 防火墙和 Wi-Fi/VPN 路由可达。按需配置 `NSLocalNetworkUsageDescription` 与 Debug-only ATS；不要给生产 Release 添加宽泛例外。
4. 环境变量必须进入 **App 进程**，仅在 Mac shell `export TRITON_HOST=...` 不会自动传给真机 App。将下例占位符替换为本机真实值，使用现有 host launch 注入（如 App 已运行，先由操作者安排终止/重新启动，以使环境生效）：

```bash
triton app launch --platform ios --scope real --device '<ios-real-selector>' \
  --bundle-id '<bundle-id>' --env TRITON_ENABLED=1 \
  --env 'TRITON_HOST=<mac-lan-ip>' --env TRITON_PORT=19421 --json
triton status --json
triton list --json
```

也可在 Xcode Debug scheme 设置上述环境，或通过 `config.endpoint = .device(...)` / Debug 配置的 `TritonKitDefaultHost`、`TritonKitDefaultPort` 固定 endpoint；固定 bootstrap endpoint 不会被环境自动覆盖。Bonjour 是可选发现路径，不保证 USB 自动转发或跨网段发现，诊断优先显式 LAN endpoint。

5. 从 `triton list --json` 确认目标 App 的 runtime 已连接，核对设备与 bundle identity 后使用返回的 runtime id。`--device` 选择 host 真机，`--target` 选择 embedded runtime；它们不是同一 id。不要依赖默认 local target 证明选中真机的业务状态。然后运行：

```bash
triton smoke ios --scope real --device '<ios-real-selector>' \
  --target '<runtime-id-from-list>' --bundle-id '<bundle-id>' \
  --open-url '<app-route>' --wait-text '<expected-text>' \
  --timeout 20 --interval 0.5 --evidence '<evidence-dir>' --format json
```

Mac CLI 的 `--host` 是 CLI 到 server 的地址，默认仍可用 `127.0.0.1`；它不会注入 App endpoint。server 使用非默认端口时，App `TRITON_PORT` 及 `status/list/smoke --port` 必须一致。若启动后 runtime 尚未注册，先复查 list 再重试；当前 smoke 不承诺自动等待连接或自动绑定 host/runtime。消费 smoke 必须检查 summary 的 `ok/status/failure`，host step 的 `pass` 不是整体 pass。

## 变更位置

- `README.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`
- `Examples/TritonKitDemo/TritonKitDemo/TritonKitDebugBootstrap.swift`
