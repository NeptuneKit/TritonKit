# #178–#195 验证矩阵

## 结论口径

本矩阵对应 2026-08-09 通过 `gh issue list --repo NeptuneKit/TritonKit --state open --limit 100` 固定的 18 条线上未关闭 issue。收口前再次执行同一查询，仍返回 #178–#195 这 18 条，没有新增或消失的 open issue。`已修复（本地）` 表示修复和测试在本 worktree 已完成，尚未 push、开 PR 或发布；`安全收口` 表示已补充 fail-closed 或结构化恢复，但没有把未实现的自动化能力伪装成完成；`已有覆盖` 表示源码已有相关行为，本轮未发现新的静态缺口；`环境/产品阻塞` 表示需要真实设备、服务或产品决策才能继续。

本轮没有关闭 issue、评论 issue、push、开 PR 或 merge；线上复查只读，且结果与初始快照一致。

## 逐条状态

| Issue | 状态 | 处理与证据 | 剩余风险 / 下一步 |
| --- | --- | --- | --- |
| [#178](https://github.com/NeptuneKit/TritonKit/issues/178) | 安全收口 | embedded runtime 对 gesture-recognizer-only tap 继续拒绝业务动作，并返回 `unsupported_capability`、`triton sim tap --simulator booted --x … --y … --json` 恢复建议；`TKRuntimeInputActions` 相关断言已补。 | 当前没有自动从 embedded tap 转发到 Simulator HID 的 orchestrator；UIKit 真实测试需 iOS 目标，当前 macOS 运行目标不执行 UIKit case。 |
| [#179](https://github.com/NeptuneKit/TritonKit/issues/179) | 已修复（本地） | `triton sim tap` 现在按 iOS Simulator scope 解析目标，并复用现有 Baguette host HID；参数解析、schema 与 `SingleDeviceWebPageTests` 28 项通过。 | 没有可用的 live server / Baguette / 专用 Simulator，未做真实坐标点击；发布前需 dedicated Simulator smoke。 |
| [#180](https://github.com/NeptuneKit/TritonKit/issues/180) | 已有覆盖，现场阻塞 | 静态审计确认 serve WebSocket、target registry、status/list 使用同一事实链，没有发现明显的 registry convergence 缺口。`triton status/doctor --json` 已执行。 | 当前 `127.0.0.1:19421` server unavailable，缺少 WS→HTTP 集成复现；需启动受控 server 后补一次 live convergence smoke。 |
| [#181](https://github.com/NeptuneKit/TritonKit/issues/181) | 已修复（本地） | Xcode setting validator 接受 `EXCLUDED_ARCHS[sdk=iphonesimulator*]=x86_64`，仍拒绝缺失或嵌套括号；`XcodeCommandTests` 与 schema contract 通过。 | 未在真实用户 workspace 执行构建；需后续 Xcode workspace smoke。 |
| [#182](https://github.com/NeptuneKit/TritonKit/issues/182) | 已修复（本地） | `simctl` parser 保留并检查 `dataPath`；data path 不存在时 target 不可用、不可 ready，并返回 `simulator_data_missing`；`DeviceCrossPlatformTests` 覆盖。 | 当前没有把损坏 Simulator 自动删除或修复，避免破坏性动作；恢复仍由用户选择。 |
| [#183](https://github.com/NeptuneKit/TritonKit/issues/183) | 安全收口 | `targetOID` 解析拒绝 detached view 或不再属于 key window 的旧节点，返回 `stale_runtime_hierarchy`，避免旧节点执行动作；补充 fail-closed 测试。 | 尚未实现跨导航的 generation/token 模型；UIKit 测试和真实导航回归需 iOS app/runtime。 |
| [#184](https://github.com/NeptuneKit/TritonKit/issues/184) | 已有覆盖 | 现有 #171 收口已将 UICollectionViewCell ancestor 误命中业务选择改为安全 `unsupported`；本轮核查未重复引入回归。 | UIKit 真实 cell selection 仍需 iOS runtime smoke；本轮未重复改实现。 |
| [#185](https://github.com/NeptuneKit/TritonKit/issues/185) | 已修复（本地） | iOS Simulator proxy 不再执行 host `networksetup` 伪装成 target mutation，返回 `ok:false`、`proxy_platform_not_supported`、`targetTrafficVerified:false`；跨平台 proxy 回归 100 项通过。 | 尚未实现 Simulator 级代理注入；当前契约明确为 host-only 不可验证。 |
| [#186](https://github.com/NeptuneKit/TritonKit/issues/186) | 安全收口 | UIAlertController 非 activatable action 仍 fail-closed，不会落到 underlying content；错误中附带 Simulator host tap 建议，modal boundary 断言已补。 | 没有自动确认弹窗坐标的 host fallback；UIKit 真实 modal 测试需 iOS 目标。 |
| [#187](https://github.com/NeptuneKit/TritonKit/issues/187) | 已修复（本地） | Harmony `bm dump` 即使 exit 0，只要 stdout/stderr 含错误语义也映射为 `harmony_app_inspect_failed`；fake HDC fixture 通过 `SimulatorAdvancedControlsTests`。 | 没有真实 HDC/DevEco target，未做 live bundle inspect。 |
| [#188](https://github.com/NeptuneKit/TritonKit/issues/188) | 已修复（契约） | `wait --idle` help/schema 明确为 embedded-only；Harmony 对 idle、hierarchy-change、predicate 返回结构化 `unsupported_capability`，`HarmonyWaitRuntimeTests` 4 项通过。 | 未把 Harmony 扩展到 idle 语义；若产品需要，应另立能力设计。 |
| [#189](https://github.com/NeptuneKit/TritonKit/issues/189) | 已修复（本地） | Harmony 远端 JPEG 先落临时文件；请求 `.png` 时原子转换为 PNG，非 PNG 保留 JPEG，并让 evidence metadata 使用实际格式；`EvidenceBundleTests` 25 项通过。 | 没有真实 Harmony screenshot；需 live HDC smoke 验证 DevEco 输出格式。 |
| [#190](https://github.com/NeptuneKit/TritonKit/issues/190) | 已修复（本地） | detached Harmony emulator 启动时自动保存 stdout/stderr；EULA 或进程提前退出在报告成功前映射为 `emulator_license_agreement_required` / `emulator_exited_early`；`DeviceCrossPlatformTests` 覆盖早退 fixture。 | 没有 DevEco Emulator，未验证具体版本的 EULA 文案和进程生命周期。 |
| [#191](https://github.com/NeptuneKit/TritonKit/issues/191) | 已修复（本地） | Harmony `open-url` 对远端 shell 参数做单引号安全转义，保留 `a=1&b=2`；`AppOpenURLFlowTests` 7 项与 shared adapter 测试通过。 | 没有真实 HDC shell，需 live URL 路由 smoke。 |
| [#192](https://github.com/NeptuneKit/TritonKit/issues/192) | 已修复（本地） | Harmony stop 对缺失 launchd job 视为幂等 warning，跳过后续 bootout 并继续 DevEco `-stop`；不吞掉权限等其他错误；`DeviceCrossPlatformTests` 100 项通过。 | 没有 DevEco Emulator/launchd fixture 执行完整 stop；当前证据覆盖计划和错误分类路径。 |
| [#193](https://github.com/NeptuneKit/TritonKit/issues/193) | 已修复（本地） | `--device current` 在没有持久 alias 时按 Harmony foreground `current:true` 唯一候选解析，保持歧义和不存在时 fail-closed；跨平台选择测试通过。 | 没有真实 Harmony foreground identity live probe。 |
| [#194](https://github.com/NeptuneKit/TritonKit/issues/194) | 已修复（本地） | Harmony `app open-url` 增加可选 `--action`，生成 `-A ohos.want.action.viewData`，保留默认行为；schema、shared builder、流程测试通过。 | 没有真实 Harmony Want 路由 smoke。 |
| [#195](https://github.com/NeptuneKit/TritonKit/issues/195) | 环境/产品阻塞 | 已核查 paired/available CoreDevice fixture 可被 readiness 和 install plan 共享；现有 `wait-ready` 会持续读取 `devicectl`，并对离线、DDI、trust 等返回结构化状态。 | 当前没有物理 iOS 设备，无法验证 tunnel/DDI lazy preparation；代码仍不会在 `wait-ready` 阶段主动安装 DDI 或启动 tunnel。需明确 CoreDevice preparation 授权和真实设备后再实现，不能宣称已修复。 |

## 统一验证证据

- `swift test --package-path CLI --filter DeviceCrossPlatformTests`：100 项通过。
- `swift test --package-path CLI --filter SimulatorAdvancedControlsTests`：33 项通过。
- `swift test --package-path CLI --filter SingleDeviceWebPageTests`：28 项通过。
- `swift test --package-path CLI --filter SchemaFactSourceContractTests`：52 项通过。
- `swift test --package-path CLI --filter HarmonyWaitRuntimeTests`：4 项通过。
- `swift test --package-path CLI --filter EvidenceBundleTests`：25 项通过。
- `swift test --package-path CLI --filter AppOpenURLFlowTests`：7 项通过。
- `swift test --package-path CLI --filter XcodeCommandTests/streamingXcodeRunnerHonorsWorkingDirectory`：1 项通过；此前一次 30 秒超时为测试环境波动，单项重跑通过。
- 根包 UIKit 相关测试在 macOS 目标下完成编译，但因 `canImport(UIKit)` 不成立没有可执行 case；这不是 iOS runtime 通过证据。
- 本机没有 Android、Harmony 或物理 iOS target；`triton status/doctor --json` 显示 HTTP server unavailable，真实设备复现均记录为 blocker。
