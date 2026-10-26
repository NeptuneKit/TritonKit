# 2026-10-24 agents / Revyl 官方参考日检

影响层：CLI/HTTP/shared core静态对照；实际main固定`24e7d0f21017c8ca7104b6f8e3912fc2c44be892`。现有tracking WIP只读保留。12仓官方默认HEAD、所有非draft release分页（含prerelease及全部body）、固定HEAD许可证全文/hash已查询，5 complete / 7 partial。没有网络失败；7仓许可404继续保留，不推进成功检查点。

| 仓库 | HEAD | 最新非draft Release | 覆盖 | 相对昨日 |
|---|---|---|---|---|
| getsentry/MobileBuildMCP | `2998ac77ebbca59544e88a27f34bfb830db9d924` | v2.7.1 | complete | 未变 |
| awizemann/harness | `3f58c077ded131cca71d75efb05c5d325f0ed18f` | v0.8.4 | complete | 未变 |
| dongxinsuperman/ai-phone | `d339057bc64aa85002570765e2a20d45e0391bae` | v0.8.0 | complete | 未变 |
| karminski/eyes-on-my-phone | `eef71926e613c3242643923bb21c92beab439990` | 无 | partial | 未变 |
| RevylAI/revyl-cli | `8fe715c3c9adaff2d870b7e45f518637e53a150e` | v0.1.185 | partial | 变化 |
| RevylAI/app-explorer | `b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e` | 无 | partial | 未变 |
| RevylAI/greenlight | `fcb36e395bd4ae20448f2535382baecba9396fd9` | v0.2.0 | complete | 未变 |
| RevylAI/mobile-devtools | `efc1dae5da089ec08108a39f1ead39324c11b410` | 无 | partial | 未变 |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56a08f3718aefc82dc911c1b3a2f23` | 无 | partial | 未变 |
| RevylAI/visual-regression | `2758e8a88f4efb3a251b675e0984c091bf8abeb8` | 无 | partial | 未变 |
| RevylAI/figma-design-checker | `8b4e5cea045dcff5c30aa723b923e514d2cdc07a` | 无 | partial | 未变 |
| RevylAI/CogniSim | `3d8902e011981b93cb0ebfafba1794eab93b053e` | 无 | complete | 未变 |

## 固定来源与新增量

[Revyl CLI固定HEAD](https://github.com/RevylAI/revyl-cli/tree/8fe715c3c9adaff2d870b7e45f518637e53a150e)相对昨日c61af5e0为3 commits/26最终路径；版本0.1.186→0.1.188，最新公开Release仍[v0.1.185](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.185)。Devin alpha云proof harness、托管iPhone Duo/iOS27.1目录、多屏iOS set_fold_state schema为主要变化；Web默认sign_in规则属于托管session说明。固定源码清单及每个请求语义用途见source-request-allowlist.json；10项文本全文已读取。8个pyc只记录路径，不请求内容。generated.go/openapi大补丁及历史checkpoint至今27 commits/276路径来源仍未整体闭合，因此本仓保守partial，不能把局部文本审阅标为完整。

[proof说明](https://github.com/RevylAI/revyl-cli/blob/8fe715c3c9adaff2d870b7e45f518637e53a150e/docs/proof-of-changes.md)要求组织Devin连接与仓库访问，属于云服务授权；[fold schema](https://github.com/RevylAI/revyl-cli/blob/8fe715c3c9adaff2d870b7e45f518637e53a150e/internal/schema/yaml_test_schema.go)只宣告multi-display iOS限制，没有可审本机SimulatorKit折叠transport。托管目标目录不能证明当前本机目标或工具链支持。LICENSE固定HEAD仍404，README/pyproject MIT声明不能替代全文许可，未复制代码。

## 本地差距、价值、权限与BDD

main的CLIDeviceEnvironmentRuntime.swift:106明确Android fold实现与iOS Duo unsupported，原因是需要版本受控SimulatorKit而public simctl无操作；本次上游schema没有补足transport证据。云proof、组织连接、托管目标目录不属于当前本机CLI能力采用面。无新增可执行采用候选，不生成推测BDD；如果今后出现可审本地transport及正式工具链契约，再独立立项验证目标/多屏身份、fold状态读回、unsupported零副作用，而非直接复制托管枚举。

已核对SP-192/196/200/203～205/216的现有交付，alias/预算/unknown、设备能力、发现/日志/Runner鉴权和HDC归属不重复排期。当前main新增c0ce0cc2的display字段/identity严校验及replay UUID绑定已纳入对照；SP-218本机真实HID/swipe/占用拒绝恢复、SP-219普通→Resize→普通录屏已在2026-10-24由独立验收完成，并随v0.2.33发布。本监控未执行设备，不把历史未验断言沿用为当前全局状态；Resize AX/HID仍unsupported、不同工具链及用户项目仍另验。

其余11仓HEAD/Release/许可相对昨日不变；沿用昨日固定源审阅，原partial不因无变化自动恢复。5仓许可全文hash与昨日一致，NOASSERTION保持API原值不擅改为MIT。

仅官方只读取证，未执行第三方代码、二进制、安装、构建、测试、设备、远端写入或子会话；没有修改共享docs/state/git。已读AGENTS、ops-governance、subagent-supervision、经验索引及参考采用流程；本轮复用既有许可/白名单/partial规则，无需扩展产品经验，交由主控统一写回。
