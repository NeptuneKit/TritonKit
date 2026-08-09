# #178–#195 验证矩阵

## 结论口径

本矩阵对应 2026-08-09 首次通过 `gh issue list --repo NeptuneKit/TritonKit --state open --limit 100` 固定的 18 条线上未关闭 issue。后续线上复查发现 #196 与 #197，分别转入 SP-158、SP-160；最终主线复查返回空数组。`已修复（本地）`、`安全收口` 与 `已有覆盖` 保留本轮实现判断；最终远端收口以主线 commit、CI 与逐条 issue 评论/关闭记录为准。

最终结果：#178–#197 共 20 条 issue 已在主线 `e77c72b7` 验证后评论并关闭；CI 为 [31301092517](https://github.com/NeptuneKit/TritonKit/actions/runs/31301092517)。

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
| [#195](https://github.com/NeptuneKit/TritonKit/issues/195) | 已修复（契约） | SP-159 已让 `ddi_missing` 保持稳定错误码，并提供 `app install --platform ios --scope real --device <selector> --app <app-path> --json` recovery；trust、Developer Mode、locked、offline 和 devicectl 缺失保持独立诊断。 | 当前没有物理 iOS 设备，无法验证 tunnel/DDI lazy preparation；不自动修改 signing/DDI 资产，不把 fixture 当真实 readiness。 |

## 统一验证证据

- `swift test --package-path CLI --filter DeviceCrossPlatformTests`：SP-157 基线 100 项，合入 SP-159 后 101 项通过。
- `swift test --package-path CLI --filter SimulatorAdvancedControlsTests`：33 项通过。
- `swift test --package-path CLI --filter SingleDeviceWebPageTests`：28 项通过。
- `swift test --package-path CLI --filter SchemaFactSourceContractTests`：52 项通过。
- `swift test --package-path CLI --filter HarmonyWaitRuntimeTests`：SP-157 基线 4 项，SP-160 后 5 项通过。
- `swift test --package-path CLI --filter EvidenceBundleTests`：25 项通过。
- `swift test --package-path CLI --filter AppOpenURLFlowTests`：7 项通过。
- `swift test --package-path CLI --filter XcodeCommandTests/streamingXcodeRunnerHonorsWorkingDirectory`：1 项通过；此前一次 30 秒超时为测试环境波动，单项重跑通过。
- 根包 UIKit 相关测试在 macOS 目标下完成编译，但因 `canImport(UIKit)` 不成立没有可执行 case；这不是 iOS runtime 通过证据。
- 本机没有 Android、Harmony 或物理 iOS target；`triton status/doctor --json` 显示 HTTP server unavailable，真实设备复现均记录为 blocker。
- `docs-linhay/scripts/verify.sh --local`：主线 e77c72b7 全量通过；GitHub Actions run 31301092517 的 scope、contracts、podspec、Swift tests 全部 success。
