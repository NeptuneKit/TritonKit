# 20260623 Implementation Plan v01

## 目标

把 triton web 提升为零配置自动发现入口：默认发现 Simulator、USB 真机、LAN runtime，并用 triton serve 的统一 target registry 驱动 Web 显示。

## Phase 0：契约冻结

- 定义 WebAutoDiscovery 默认行为。
- 定义 target registry DTO：
  - host
  - runtime
  - mirror
  - transport
  - diagnosis
  - nextAction
- 定义错误码：
  - runtime_not_found
  - ios_usb_tunnel_unavailable
  - server_not_reachable_from_real_device
  - ambiguous_runtime_target
  - mirror_capability_unavailable
- 先补 schema / model tests。

## Phase 1：triton web 默认编排

- 默认扫描 real-device，不再需要 --real-device auto。
- 保留 --simulator-only、--no-usb、--no-lan 作为 escape hatch。
- triton web --json 输出内部启动计划与最终 registry endpoint。

## Phase 2：USB runtime tunnel

- 新增 iOS runtime local listener 设计与 Debug-only guard。
- 新增 CLI USB tunnel adapter protocol。
- 先实现 fake adapter + unsupported adapter，跑通 registry 状态。
- 再接入可用 backend：devicectl tunnel 能力优先，其次 usbmux / iproxy。

## Phase 3：Runtime registry merge

- triton serve 维护 host target 与 runtime session registry。
- 合并 devicectl target、USB probe runtime、Bonjour runtime。
- 多 runtime 无法唯一匹配时返回 ambiguous_runtime_target，不自动乱选。

## Phase 4：Bonjour fallback

- triton serve 发布 _tritonkit-server._tcp.local。
- iOS runtime 支持 Bonjour server discovery。
- Bonjour 只作为 USB 后的 fallback，不替代 USB 默认路径。

## Phase 5：Web 展示

- Web target list 只读 registry。
- 展示 transport：usb / bonjour / manual / simctl。
- 展示四态：host offline、runtime missing、mirror unavailable、ready。
- 真机截图请求只使用 registry resolved runtime，不 fallback simulator。

## Phase 6：真实设备验收

- USB 真机 Debug App 自动显示。
- App 未启动时显示 runtime_not_found。
- USB 不可用但 Bonjour 可用时可显示。
- 多真机 ambiguous 时不误连。
- Simulator 原路径保持可用。

## 风险与约束

- iOS USB tunnel backend 可用性需要先做 adapter capability detection，不把某个第三方命令写死进业务逻辑。
- iOS App 本地 listener 必须 Debug-only，Release no-op。
- Bonjour 需要 Local Network / NSBonjourServices 配置，不能作为唯一主路径。
- Web 只消费 registry；不要把发现逻辑散进 Web bridge。
