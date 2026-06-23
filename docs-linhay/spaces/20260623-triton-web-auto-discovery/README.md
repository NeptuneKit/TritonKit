# 20260623 Triton Web Auto Discovery

## 背景

当前 triton web / Web mock 可以展示 iOS Simulator 画面，但真机链路仍暴露过多手动配置：

- 用户需要知道 triton serve --host 0.0.0.0 --port 19421 与 TRITON_HOST=<Mac LAN IP> 的关系。
- Web 当前 URL 可能仍停留在 sim:<UDID>，即使 Mac 已通过 devicectl 发现 ready 真机。
- 真机 host target 与 embedded App runtime target 没有统一 registry；Web 请求真机截图时可能得到 app_runtime_unavailable。
- 对标 Lookin，真机发现和传输应默认自动完成，并优先支持 USB，而不是要求用户手动传 --real-device auto 或配置 host / port。

本 space 重新定义 triton web 的默认体验：用户只运行 triton web，TritonKit 自动发现 Simulator、USB 真机、LAN runtime，并把可镜像状态以机器可读 target registry 暴露给 Web。

## 用户目标

用户期望只运行：

    triton web

默认完成：

1. 启动或复用 triton serve 与 Web。
2. 自动发现本机 iOS Simulator。
3. 自动发现通过 USB / localNetwork 连接的 iOS 真机。
4. 对真机优先建立 USB runtime tunnel。
5. USB 不可用时自动尝试 LAN / Bonjour runtime discovery。
6. App runtime 连接后自动合并 host target 与 runtime target。
7. Web 自动显示可镜像真机；不可镜像时展示明确原因和 next action。

用户不应为了常规真机镜像手动理解或配置：

- --real-device auto
- --host 0.0.0.0
- TRITON_HOST
- TRITON_PORT
- USB / Bonjour / LAN 选择
- host target 与 runtime target 关联

这些只能作为调试或 fallback 细节。

## 产品边界

### Scope

- triton web 默认自动发现本机可用 target：Simulator、USB 真机、LAN runtime。
- iOS 真机 transport 优先级固定为：USB tunnel > LAN / Bonjour > manual fallback。
- triton serve 维护统一 target registry，Web 只读消费 registry。
- 真机 target 不允许 fallback 到 Simulator screenshot。
- 所有状态、错误、next action 必须是机器可读 JSON，可被 AI agent 审计。
- embedded runtime 仍保持 Debug-only；Release package build 可编译但 runtime no-op。

### Out of scope

- 不新增远端 agent、设备云、多租户或对外 HTTP 产品面。
- Web 不承载 create / update / delete / execute / approve / deny 业务控制闭环。
- 不把 Web 作为业务控制事实入口；CLI / HTTP registry 仍是事实源。
- 不要求本期同时完成 Android / Harmony 真机 USB 传输；但 schema 设计应保留 platform-neutral transport 字段。

## 核心方案

### 1. 默认入口

主入口只保留：

    triton web

可选参数仅作为 escape hatch：

    triton web --simulator-only
    triton web --no-usb
    triton web --no-lan
    triton web --port 34127
    triton web --json

默认策略等价于内部配置：

    {
      "realDevice": "auto",
      "simulator": "auto",
      "transportPriority": ["usb", "bonjour", "manual"],
      "registry": "serve-owned"
    }

### 2. Transport 优先级

#### USB tunnel，默认首选

iOS Debug runtime 在 App 内开启本地 runtime listener，例如：

    127.0.0.1:19422

Mac 侧通过 Triton-managed USB tunnel 建立：

    127.0.0.1:<localPort> -> device:127.0.0.1:19422

然后 triton serve 通过本地 tunnel probe runtime：

    GET http://127.0.0.1:<localPort>/status

成功后 registry 标记：

    {
      "runtime": {
        "connected": true,
        "transport": "usb",
        "baseURL": "http://127.0.0.1:<localPort>"
      }
    }

USB tunnel adapter 应隐藏平台细节：

- 优先使用稳定可用的 Apple / Xcode / devicectl 能力。
- 不可用时可通过 Triton adapter 调用 usbmux / iproxy。
- 如果本机缺少可用 adapter，返回 ios_usb_tunnel_unavailable，再尝试 LAN / Bonjour。

#### LAN / Bonjour，第二优先级

triton serve 发布：

    _tritonkit-server._tcp.local

iOS Debug runtime 用 NWBrowser / NetServiceBrowser 自动发现 server 并连接。

必要 Info.plist 配置仍由接入文档明确，但不应作为用户日常命令参数：

    NSLocalNetworkUsageDescription = TritonKit uses local network discovery to connect the Debug app to the local Triton server.
    NSBonjourServices = _tritonkit-server._tcp

#### Manual fallback，最后兜底

只有 USB 和 Bonjour 都不可用时才提示：

    TRITON_HOST=<Mac LAN IP>
    TRITON_PORT=19421

### 3. Target Registry

triton serve 输出统一 target registry，合并 host target 与 runtime target：

    {
      "id": "ios-real:73f725dfa795",
      "platform": "ios",
      "kind": "real-device",
      "host": {
        "source": "devicectl",
        "state": "connected",
        "ready": true,
        "transport": "wired"
      },
      "runtime": {
        "id": "triton:ios-real:session-abc",
        "state": "connected",
        "transport": "usb",
        "baseURL": "http://127.0.0.1:19432",
        "appBundleId": "cn.dxy...",
        "capabilities": ["screenshot", "hierarchy", "input"]
      },
      "mirror": {
        "state": "ready"
      }
    }

Web 显示四态：

1. host_offline：真机 host 未连接。
2. runtime_not_found：host ready，但 Debug App runtime 未启动或未探测到。
3. mirror_unavailable：runtime connected，但 screenshot / hierarchy capability 不可用。
4. ready：可以显示真机画面。

## BDD 场景

### 场景 1：默认命令自动发现 USB 真机

Given iPhone 通过 USB 连接 Mac
And Debug App 已集成并启动 TritonKit runtime
When 用户运行 triton web
Then Triton 自动建立 USB tunnel
And target registry 显示 runtime.transport = usb
And Web 显示真机截图
And 用户不需要传 --real-device auto、TRITON_HOST 或 --host 0.0.0.0

### 场景 2：USB 真机存在但 App 未启动

Given iPhone 通过 USB 连接 Mac
And Debug App 未启动
When 用户运行 triton web
Then target registry 显示 host connected
And runtime 状态为 runtime_not_found
And Web 显示 next action：启动 Debug App
And Web 不 fallback 到 Simulator screenshot

### 场景 3：USB adapter 不可用但 Bonjour 可用

Given iPhone 与 Mac 在同一局域网
And USB tunnel adapter 不可用
And Debug App runtime 可通过 Bonjour 发现 triton serve
When 用户运行 triton web
Then target registry 显示 runtime.transport = bonjour
And Web 显示真机截图

### 场景 4：多台真机 runtime 关联不唯一

Given 多台 iOS 真机 ready
And 多个 runtime 同时连接
When registry 无法唯一关联 host target 与 runtime target
Then target registry 返回 ambiguous_runtime_target
And Web 展示候选与手动选择入口
And 不自动选择错误设备

### 场景 5：Simulator 路径不受影响

Given iOS Simulator 已 booted
When 用户运行 triton web
Then Web 仍能显示 Simulator target
And Simulator target 使用本机 host-side screenshot 路径
And 真机失败不会影响 Simulator 可用性

## 初始实现切片

1. Contract first
   - 新增 / 更新 target registry DTO。
   - 为 host、runtime、mirror、transport、diagnosis 建立机器可读 schema。
   - 补 schema / model tests，先红灯。

2. triton web 默认编排
   - 移除常规路径对 --real-device auto 的需要。
   - 默认扫描 Simulator 与 iOS real devices。
   - 保留 escape hatch 参数。

3. iOS runtime local listener
   - Debug-only listener 暴露 /status、/screenshot、/hierarchy、/input 或等价 WS 能力。
   - Release no-op。

4. USB tunnel adapter
   - 建立 adapter protocol。
   - 先实现 capability detection 与 structured unsupported。
   - 再接入可用 tunnel backend。

5. Registry merge
   - 合并 devicectl host target 与 runtime probe target。
   - 返回 runtime_not_found / ambiguous_runtime_target / ready。

6. Bonjour fallback
   - triton serve 自动发布 _tritonkit-server._tcp.local。
   - runtime 自动浏览并连接。

7. Web consumption
   - Web 改为只读 target registry。
   - 展示 transport 与四态诊断。
   - 禁止真机 fallback 到 simulator screenshot。

## 验收门禁

- CLI / schema focused tests 覆盖 target registry 与 triton web 默认策略。
- HTTP handler / runtime registry 用可控 fake runtime 覆盖。
- iOS runtime discovery 使用可替代 fake advertiser / fake tunnel adapter 测试。
- Web tests 覆盖：
  - ready USB target 显示。
  - runtime_not_found 状态。
  - ambiguous_runtime_target 状态。

## 2026-06-23 实现记录

- 新增 Shared target registry DTO 与 `/web/target-registry`，Web 优先消费 registry，旧 `/web/host-targets` 仅作为 dev fallback。
- `triton web --json` 默认输出 simulator=auto、realDevice=auto、transportPriority=usb/bonjour/manual、registry=serve-owned；`--simulator-only`、`--no-usb`、`--no-lan` 保留为 escape hatch。
- registry 合并 host target 与 runtime target：
  - booted simulator 可独立标记 `mirror.state=ready`；
  - ready real-device 无 runtime 时返回 `runtime_not_found + start_debug_app`；
  - 多 ready real-device 无法唯一关联 runtime 时返回 `ambiguous_runtime_target + select_runtime_target`；
  - 本机缺少 `iproxy` 时补充 `transportDiagnostics[].code=ios_usb_tunnel_unavailable`。
- `triton serve` 发布 `_tritonkit-server._tcp.local`；embedded runtime 支持 `TRITON_HOST/TRITON_PORT`、Info.plist build setting、Bonjour、localhost 默认四级 endpoint 解析。
- Demo App 改为启动时用 `TritonKitStartPayload.environment()` 自动解析 endpoint，并补充：
  - `NSBonjourServices = _tritonkit-server._tcp`
  - `NSLocalNetworkUsageDescription`
  - `NSAppTransportSecurity.NSAllowsLocalNetworking = true`
- `triton xcode run --device` 修复 iOS real-device launch env/args：使用 `DEVICECTL_CHILD_*` 传给 `devicectl`，sourceCommand 中自动脱敏，便于真实 Debug App 直连当前 Mac host/port。

## 2026-06-23 真机 smoke 记录

- 源码版 `.build/cli-autodiscovery/debug/triton` 在 `0.0.0.0:19431` 启动 serve，确认 Bonjour 发布日志为 `_tritonkit-server._tcp.local:19431`。
- `triton device list --platform ios --scope real --json` 曾发现 ready 真机 `ios-real:73f725dfa795`，并通过 `triton xcode run --device ios-real:73f725dfa795 --env TRITON_HOST=<Mac LAN IP> --env TRITON_PORT=19431 --jsonl` 完成 build、install、launch。
- `xcode.run.launch.invocation` 中 sourceCommand 显示 `DEVICECTL_CHILD_TRITON_HOST=<redacted> DEVICECTL_CHILD_TRITON_PORT=<redacted>`，证明 env 已通过 Triton 入口传递且脱敏。
- 当前环境仍未完成 runtime ready：`GET /status` 返回 `connected=false`，registry 对 ready 真机返回 `mirror.state=runtime_not_found`，未 fallback 到 simulator。
- 随后真机状态变为 `offline + ddi-missing`，`triton xcode run` 返回 `target_not_found`；本轮无法继续验证 `runtime.transport=bonjour/usb` 与真机 screenshot/hierarchy。
- 自动化验证已覆盖 Shared registry model、CLI web/registry/xcode/app launch 契约、Web registry 映射、Web build、Web 全量 test、`git diff --check` 与 `check-docs.sh`。

后续若继续真机闭环，需要用户保持设备解锁、信任、Developer Mode/DDI 可用，并接受 iOS 本地网络权限弹窗；然后复跑同一条 `triton xcode run --device ... --env TRITON_HOST=<Mac LAN IP> --env TRITON_PORT=<serve-port> --jsonl`。
  - 真机不 fallback 到 simulator screenshot。
- 本地最终门禁按变更范围运行：
  - Swift focused tests。
  - npm --prefix Web run test / npm --prefix Web run build。
  - docs-linhay/scripts/check-docs.sh。

## 交付原则

- 先 BDD / schema，再实现。
- 每个切片都必须保留机器可读错误码和 next action。
- Web 不是控制事实源；Web 只展示 CLI / HTTP registry。
- 真机自动发现默认启用，参数只用于禁用、限制或诊断。

## 2026-06-23 实现记录：Phase 0 / Phase 1 最小切片

- 已新增 Shared target registry DTO：host、runtime、mirror、diagnosis、nextAction，覆盖 runtime_not_found、ios_usb_tunnel_unavailable、server_not_reachable_from_real_device、ambiguous_runtime_target、mirror_capability_unavailable。
- triton web launch plan 已新增 discovery 字段；默认策略为 simulator auto、realDevice auto、transportPriority usb > bonjour > manual、registry serve-owned。
- triton web --json 现在输出 launch plan，不启动长运行 Web 进程，便于 agent 读取 discovery.targetRegistryEndpoint。
- 新增 escape hatch 参数：--simulator-only、--no-usb、--no-lan。
- triton serve 新增只读 endpoint：GET /web/target-registry，由现有 host targets 与 runtime targets 合并生成。
- iOS real-device host target 在 runtime 未连接时返回 mirror.state=runtime_not_found 与 nextAction.code=start_debug_app，且不会 fallback 到 simulator runtime。
- USB tunnel backend 仍未实现；Bonjour server discovery 与 Web registry consumption 已在后续切片接入。

## 2026-06-23 真机验证记录

- 使用源码版 .build/cli-autodiscovery/debug/triton 验证；PATH 上的 /Users/linhey/.local/bin/triton 仍是旧版本，schema 中尚无 discovery 字段。
- triton device list --platform ios --scope all --json 已发现两台 ready USB 真机：ios-real:7a9d976cc4d4、ios-real:73f725dfa795，transport 均为 wired。
- 启动本地 triton serve 后，GET /web/target-registry 返回：
  - booted simulator host:ios:EBE0BF36-9E38-4414-BC8C-D58230B6A753 为 ready，runtime 为 triton:ios-simulator:EBE0BF36-9E38-4414-BC8C-D58230B6A753。
  - ios-real:7a9d976cc4d4 与 ios-real:73f725dfa795 均进入 registry，host.ready=true、host.transport=wired、mirror.state=runtime_not_found、nextAction.code=start_debug_app。
- 验证结论：本切片满足“真机 host target 自动进入 registry 且不 fallback simulator”；尚未满足“真机截图 ready”，原因是 real-device Debug App runtime 未连接，后续需要 USB tunnel / real-device runtime listener 切片。

### 多真机 runtime 防误绑修复

- 真实环境当前有两台 ready wired 真机，因此 registry merge 不能在只有一个 real-device runtime 时默认绑定到任一 host。
- 已补 BDD：多台 ready iOS real-device host + 无法唯一关联的 connected real runtime 时，host entries 返回 diagnosis.code=ambiguous_runtime_target、nextAction.code=select_runtime_target，runtime 保留为独立 embedded-runtime entry。
- 若只有一台 ready real-device host 且只有一个 connected real runtime，仍允许自动关联；若 runtime id 可直接匹配 host id/target，也允许精确关联。

## 2026-06-23 实现记录：Phase 2 Web registry consumption

- Web 数据层已改为优先请求 GET /web/target-registry；registry 不可用或返回非 targets payload 时，回退旧 /web/host-targets，保持现有 dev bridge 与旧版服务兼容。
- target registry host DTO 补充 target、name、runtime、scope、kind，避免 Web 为了展示名称、系统版本或 target selector 再依赖旧 host-targets shape。
- Web 已映射 registry 四态：
  - ready -> DeviceTarget.status=ready，可按 simulator host screenshot 或 real-device runtime mirror 路径展示。
  - host_offline -> busy。
  - runtime_not_found / mirror_unavailable -> limited，并展示 diagnosis / nextAction。
- runtime_not_found 真机仍在设备列表可见，但 canScreenshot=false、screenshotSource=runtime，因此不会触发 simulator screenshot fallback。
- Vite dev bridge 新增 /web/target-registry 代理；本地 triton serve 未启动或旧版不支持时返回 502，前端自动回退 /web/host-targets。
- wired iOS real-device entry 增加 transportDiagnostics；当 PATH 未找到支持的 USB tunnel adapter 时，返回 code=ios_usb_tunnel_unavailable，供 Web 和 agent 明确区分“App runtime 未启动”和“USB tunnel backend 缺失”。

### Phase 2 验证

- node --test dev/targetRegistryClient.test.mjs：覆盖 ready simulator + runtime_not_found real device、registry 不可用时回退 host-targets。
- npm --prefix Web run build：TypeScript 与 Vite build 通过。
- npm --prefix Web test：76 个 Web 测试，72 pass、4 skip。
- swift test --filter TKWebTargetRegistryModelsTests：通过。
- swift test --package-path CLI --scratch-path .build/cli-autodiscovery --filter SingleDeviceWebPageTests：22 个测试通过。

## 2026-06-23 真机 smoke：Phase 2 后复验

- 使用源码版 .build/cli-autodiscovery/debug/triton serve --host 127.0.0.1 --port 19431 复验 /web/target-registry；19421 当前已有旧服务占用且不含新 endpoint，因此本次未复用 19421。
- 复验结果：
  - host:ios:60667794-96F8-40E6-8664-85538EC4663E 与 host:ios:EBE0BF36-9E38-4414-BC8C-D58230B6A753 为 booted simulator，mirror.state=ready，diagnosis=null。
  - ios-real:7a9d976cc4d4 与 ios-real:73f725dfa795 为 ready wired 真机，host.name / host.runtime / host.target 已进入 registry，mirror.state=runtime_not_found，nextAction.code=start_debug_app。
  - 本机未发现 iproxy，因此两台真机都返回 transportDiagnostics[0].code=ios_usb_tunnel_unavailable。
- 复验过程中修复缺口：Simulator host screenshot 不依赖 App runtime；ready simulator 现在不再被错误标记为 runtime_not_found。
- 复验后已停止临时 19431 serve。

## 2026-06-23 实现记录：Manual fallback 降低手动 env 依赖

- embedded runtime 的 `TritonKitStartPayload.environment()` 现在按优先级读取：
  1. `TRITON_HOST` / `TRITON_PORT`
  2. Info.plist / build setting：`TritonKitDefaultHost` / `TritonKitDefaultPort`
  3. Bonjour `_tritonkit-server._tcp.local`
  4. 默认 `127.0.0.1:19421`
- `triton serve` 在启动后发布 `_tritonkit-server._tcp.local`，让同网段 Debug App 可在无 env / build setting 时发现本机 server。
- 这不是 USB tunnel backend；它覆盖 USB 不可用时的 Bonjour fallback。
- 验证：`swift test --filter TKPlatformFallbackTests/startPayloadReadsEnvironment` 通过。
- 验证：源码版 `triton serve --host 127.0.0.1 --port 19431` 启动后，`dns-sd -B _tritonkit-server._tcp local` 可发现 `TritonKit` 服务；复验后已停止临时 19431 serve。

## 2026-06-23 继续实现记录：未展开 build setting 与当前真机状态

- 修复 `TritonKitStartPayload.environment()`：当 `Info.plist` 中 `TritonKitDefaultHost` / `TritonKitDefaultPort` 仍是 `$(...)` 未展开 build setting 时，将其视为空值，继续走 Bonjour 或默认 localhost fallback，避免真机 Debug App 把占位符当成真实 host。
- 当前 `.build/cli-autodiscovery/debug/triton device list --platform ios --scope real --json` 显示所有 iOS real-device 均为 `offline + ddi-missing`，ready 真机数为 0；因此本轮无法继续验证 runtime ready、`runtime.transport=bonjour/usb`、真机 screenshot/hierarchy。
- 临时启动源码版 `triton serve --host 0.0.0.0 --port 19431` 复验：
  - `GET /status` 返回 `connected=false`；
  - `GET /web/target-registry` 返回合法 `web.target-registry` envelope；
  - 当前 targets 为空，与 ready 真机数为 0 的 host 事实一致；
  - 复验后已停止临时 19431 serve。
- `triton web --json` 复验默认 discovery plan：`simulator=auto`、`realDevice=auto`、`transportPriority=[usb, bonjour, manual]`、`targetRegistryEndpoint=http://127.0.0.1:19421/web/target-registry`。

## 2026-06-23 继续实现记录：managed serve 显式契约

- Web dev bridge 已有 managed `triton serve` 自动启动逻辑，并默认绑定 `0.0.0.0`，让 iOS 真机 Debug runtime 能访问 Mac 上的 server。
- 本轮补齐 CLI 机器可读契约：`triton web --json` 的 `discovery.managedServeHost` 现在显式返回 `0.0.0.0`，并在 launch `environment` 中注入 `TRITONKIT_WEB_MANAGED_SERVE_HOST=0.0.0.0`。
- 同步更新 `web.launch-plan` output contract 与 `triton schema --command web --json` success shape，方便 agent 审计 `triton web` 是否具备真机可达的 serve 绑定策略。
- 验证：先补 WebCommandTests 红灯，再实现；`swift test --package-path CLI --scratch-path .build/cli-autodiscovery --filter WebCommandTests` 通过；源码版 `.build/cli-autodiscovery/debug/triton web --json` 已输出 `managedServeHost` 与环境变量。

## 2026-06-23 继续实现记录：target registry 自动复用 managed serve

- 修复 Web dev bridge：`GET /web/target-registry` 在 proxy 到 `triton serve` 前先调用现有 `ensureTritonServe`，与 host input 路径共用同一个 managed serve 机制。
- 这样 `triton web` 打开的 Web 页面首次读取 registry 时，会先复用或自动启动绑定 `0.0.0.0` 的 `triton serve`，而不是直接 502 后退回旧 `/web/host-targets`。
- 验证：新增 bridge route 测试覆盖 registry 路径先探测 `/health` 再 proxy `/web/target-registry`；`node --test dev/iosSimulatorBridge.test.mjs` 通过。

## 2026-06-23 继续实现记录：packaged Web registry endpoint

- 修复 packaged `triton web` server：新增 `GET /web/target-registry`，直接返回统一 `web.target-registry` DTO。
- packaged 路径复用 `makeWebTargetRegistry(...)`，用当前 host targets 和可用 runtime targets 合并，不再只能依赖旧 `/web/host-targets` fallback。
- 验证：新增 WebCommandTests 覆盖 packaged registry bridge 返回统一 DTO；`swift test --package-path CLI --scratch-path .build/cli-autodiscovery --filter WebCommandTests` 通过。

## 2026-06-23 真机复验：ready 恢复但设备锁屏阻止 launch

- `triton device list --platform ios --scope real --json` 当前发现 ready 真机 `ios-real:73f725dfa795`，transport 为 `localNetwork`。
- 临时启动源码版 `triton serve --host 0.0.0.0 --port 19431`，并确认 Mac LAN 地址 `192.168.228.128:19431/status` 可访问，Bonjour 发布正常。
- `triton xcode run --device ios-real:73f725dfa795 --env TRITON_HOST=192.168.228.128 --env TRITON_PORT=19431 --jsonl` 完成 build 和 install；launch sourceCommand 继续脱敏 `DEVICECTL_CHILD_TRITON_HOST` / `DEVICECTL_CHILD_TRITON_PORT`。
- launch 失败为机器可读 `device_locked`：`Unable to launch ... because the device was not, or could not be, unlocked`。这是外部设备状态，不是 registry 或 env 传递失败。
- 复验 `GET /web/target-registry`：`ios-real:73f725dfa795` 保持 `host.ready=true`、`transport=localNetwork`、`mirror.state=runtime_not_found`、`nextAction=start_debug_app`，且未 fallback 到 simulator。
- 复验后已停止临时 19431 serve。下一次只需保持设备解锁并重跑同一 `triton xcode run` 命令，即可继续验证 runtime ready 与 screenshot/hierarchy。
