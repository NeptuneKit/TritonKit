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

## 可选悬浮控件选择（SP-201，未发布）

阶段：当前为 SP-201 独立 worktree 内的 UIKit 首版实现，尚未集成或发布；本节说明源码候选的接入和验收方式，不表示测试或真实 App 验收已完成。普通外部接入继续使用已发布版本；验证本功能时必须使用同一候选的 SDK 与 CLI，先保存 `triton version --json`、`triton schema --json` 及源码版本。

### Debug 双重启用

悬浮入口默认关闭。将配置加入现有独立 Debug bootstrap，保留 App 原有 runtime 显式开关，不在 AppDelegate 或 SwiftUI 入口散落 SDK 符号。最小示例：

```swift
#if DEBUG
import Foundation
import TritonKit

enum TritonKitDebugBootstrap {
    static func startIfEnabled() {
        guard ProcessInfo.processInfo.environment["TRITON_ENABLED"] == "1" else { return }
        TritonKit.shared.start { config in
            config.features.insert(.inspector)
            config.picker = .init(enabled: true, ttlSeconds: 300)
        }
    }
}
#endif
```

App 启动入口仍只在 `#if DEBUG` 内调用 `TritonKitDebugBootstrap.startIfEnabled()`。若 App 自定义了较小的 `config.features` 集合，执行点击还需启用 `.input`；`.inspector` 不自动扩大其它业务动作权限。

- `TRITON_PICKER_ENABLED=1` 仅把默认环境配置中的 `picker.enabled` 设为 true，**不会**把 `.inspector` 加入 App 的 feature 集合。采用环境控制时保留 `config.features.insert(.inspector)`，不要再用显式 `config.picker = ...` 覆盖环境配置。runtime 的 `TRITON_ENABLED` 启动条件仍独立生效。
- `TRITON_PICKER_TTL_SECONDS` 设置环境配置中的标记有效期；当前范围为 1–300 秒，缺失、无法解析或越界时回退到 300 秒，显式初始化的非法值也回退到 300 秒。
- 测试 fixture 在 picker 环境开关启用时自动插入 `.inspector`，这是 fixture 的接入便利，不能推断普通业务 App 只设一个环境变量就能启用。
- Release public API 可编译，但 runtime 和浮层保持 no-op；未启用时不显示圆点。本功能不引入第三方依赖。

### 用户选择与 agent 动作

直接拖动圆球实时显示候选轮廓、类型与名称，提示“松手选中”，松手保留一个标记并恢复圆球停靠位置。拖动显示局部放大镜，密集区域停留后显示辅助框。长按 0.4 秒后拖动仅移动圆球并停留；有效松手自动展开罗盘，轻点圆球可收起/展开。罗盘上父级、下子级、左右同级，父子往返记住原节点，无遮挡时保持位置；中心收起保留标记，清除独立。重新选取替换原目标；选中不是点击，也不自动发起 agent 任务。切换父层级会改变目标和 revision；取消选取保留原来仍有效的标记。

先从 `triton list --json` 获取并核对目标 App 的 embedded runtime id。以下所有命令使用同一个 `--target`，占位符必须替换为当前响应中的真实值：

```bash
triton inspect capabilities --target '<runtime-target>' --json
triton inspect selection --target '<runtime-target>' --json
triton act tap --target '<runtime-target>' \
  --selection '<selection.id>' --selection-revision '<selection.revision>' \
  --runtime-instance-id '<runtimeInstanceID>' --json
triton inspect clear --target '<runtime-target>' \
  --runtime-instance-id '<runtimeInstanceID>' --json
```

读取必须检查 `ok`、`state`、`selection.validity` 和 `selection.supportedActions`；仅当当前目标有效且包含 `tap` 时才发起点击。`selection.id`、`selection.revision` 与顶层 `runtimeInstanceID` 作为同一份读取快照一并传入；CLI 不先把标记换成裸 OID。三项保护参数不能缺项，且不能混用文案、坐标、OID、WebView 或 host fallback 选择方式。`clear` 是显式清除操作，不应当作只读探测执行。

首版只允许满足身份与前台校验的 `UIButton` 执行点击。UILabel、cell 与其它缺少可信动作身份的目标为 `observeOnly`；“有标记 / OID”不代表可以点击。SwiftUI 虚拟节点、WKWebView DOM、Android 与 Harmony provider 后置，不能把 UIKit 验收当成多端覆盖。

读取后重选或切换父级应拒绝旧版本（`selection_revision_mismatch`）；目标消失、超时或进程实例改变应拒绝旧身份（`selection_stale`）；无标记为 `selection_missing`，只观察目标的动作可返回 `selection_identity_unverifiable`。不要改用历史坐标或普通 OID 自动重试；先重新观察，必要时请用户重选，再重新读取。浮层轮廓仅表达选取状态，独立于修改真实属性的 `triton highlight` 能力。

### 接入验收与证据

真实 App 验收至少分开记录：拖选按钮前后业务计数不变；读取标记后执行一次受保护点击，业务计数恰好增加一次；读取后重选、目标失效以及 cell 观察目标均拒绝旧动作且不增加计数。另检查浮层可见时普通 AX/hierarchy/截图和动作仍排除 inspector、显式关闭无浮层、Release 无连接和选择响应。UI/动作 ACK 不能代替业务后置条件；HTML 原型、macOS 上未执行的 UIKit 条件测试均不能代替 App-hosted UIKit 或真实宿主证据。

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
