# SP-255 DTUHID 独立风险审查清单（2026-11-02）

阶段：静态预审，不是候选验收或真实兼容证明。影响CLI host隔离helper；基线main `44e81f5d333ba842051579639d3834981e7b2340`。执行SP-254，主控SP-255。没有设备动作授权，不运行Simulator/DeviceHub/HID探针；离线测试通过也不能宣称Xcode27可用。按ops governance核对现有证据，未修改实现。

## 固定来源与许可

- [Loupe实现提交](https://github.com/heoblitz/Loupe/commit/c4da89490375c2696b44a933cfa68c7348842d8e)；观察HEAD `180c60584867500b93b43ca6c8b556995bf8be7b`。重点文件`Sources/LoupeHID/LoupeDTUHID.m`、`LoupeHID.m`与`verify-dtuhid-transport.sh`；原始固定文本、逐父边清单及本地main证据保存在私有archives/reference-monitor/20261102/heoblitz__Loupe。
- [Loupe固定LICENSE](https://github.com/heoblitz/Loupe/blob/180c60584867500b93b43ca6c8b556995bf8be7b/LICENSE)：人工全文MIT，Copyright 2026 heoblitz，SHA-256 `0d7ebd755456885dba28523a5c468e59d06a26c8df2b896938632c9322c9e7e3`。API NOASSERTION保留，不能当作没有许可或自动替代人工识别。
- Loupe注释指向facebook/idb协议/XPC实现，该仓现重定向meta/idb。只读查询固定revision `c793afad2a31092628f7013cf1aa96f266c85024`的[LICENSE](https://github.com/meta/idb/blob/c793afad2a31092628f7013cf1aa96f266c85024/LICENSE)，全文MIT，Copyright Meta Platforms, Inc. and affiliates；blob `b93be90515ccd0b9daedaa589e42bf5929693f1f`，SHA-256 `da6d3703ed11cbe42bd212c725957c98da23cbff1998c05fa4b3d976d1a58e93`。
- 本轮只额外核对idb许可证，未下载其协议实现，不能声称已复核idb wire等价性。若候选复制/实质改写Loupe或idb代码，主控核对实际来源、原copyright与完整MIT通知的保留位置；仅标“MIT”或只记录一个上游URL不代替通知义务。Apple私有ABI/服务可用性不由MIT保证。

## 1. 无事件barrier：最多证明什么

上游发送`IndigoKeyboardButtonEvent`，`isBarrier=true`、`usageCode:uint64(0)`、`state:uint64(2)`、featureIdentifier匹配digitizer服务。它将barrier视为独立无事件消息；连接开始及结束均等reply，最多4秒。该含义是上游协议假设与fixture所验证行为，未在本机真实服务证明。

- [ ] 离线peer精确检查barrier字段、XPC类型、独立消息；barrier不得挟带实际touch/key输入，不能把真实input设isBarrier后误认为guest已收到。
- [ ] liveness在首个mutation前完成，finish在同一连接最后一条输入后发送；序列不可跨connection或并发queue串扰。
- [ ] reply error、invalid/interrupted连接、超时及取消都返回失败；检查reply实际类型/内容，不能把任意无error字典自动解释为更强的业务ACK。
- [ ] timeout后迟到callback不访问已释放内存，不二次resume；failure共享状态有同步，回调写入与等待读取无数据竞争；不能只复制上游`__block replyError`模式而不解释同步。
- [ ] barrier预算受整条helper/动作总预算约束；两次4秒等待及多个阶段不能意外超过上层deadline。取消能有界退出。
- [ ] 返回契约区分连接可响应、输入已提交、barrier应答、业务已验证。即使finish应答，也没有屏幕后置条件；不能新增`businessVerified=true`或“tap succeeded”语义。

## 2. Typed输入与contact状态

上游touch使用pointOne下x/y double，eventType/edge/target uint64；首down=0，contact active后move=1，up=2。keyboard usageCode/state uint64。只有pointOne，target=0，对应主显示语义不能外推。

- [ ] fixture验证wire数值类型及字段缺省，不只比较JSON看起来相同；完整首down→多move→up顺序，单tap和零move短drag均覆盖。
- [ ] 比例坐标在现有geometry/display/target验证后产生，finite、范围、方向/键码白名单和溢出先于发送检查；不把非法direction一律归为down。
- [ ] contact状态仅在实际发送条件满足时转移；send失败/取消后不把下一动作当move；多次up/重复down明确拒绝或定义恢复策略。
- [ ] failure发生于down后、move中或up/finish处时，保留已可能输入的unknown语义，不降格为not_started；只允许有界、同target自有contact释放，不自动重放整条gesture。
- [ ] XPC connection/endpoint/send right的所有权明确，所有early return释放自有资源；不在连接取消后继续发送，不随fallback复用旧contact状态。
- [ ] 次显示、Resize、未知display拓扑继续拒绝；不因目标设备存在或DTUHID service存在跳过现有display admission。

## 3. Fallback必须在mutation前收敛

上游只把lookup selector缺失或`com.apple.CoreSimulator.SimError`精确code405当unsupported。其他lookup/连接/符号/barrier错误均拒绝。实际服务没有权威公开规范，405的稳定性仍待真实授权验收。

- [ ] 用fixture分别覆盖精确domain+405、其他domain同405、同domain其他code、nil error、selector缺失、null port、endpoint/enable symbol缺失。
- [ ] “unsupported”只允许尚未开始mutation的backend选择；lookup有port但liveness失败不能静默fallback，任何已发送动作后都不能切legacy重播。
- [ ] selector缺失是否真能作为unsupported由目标/toolchain事实解释；不要把应用层异常、异常catch或所有nil统一标unsupported。
- [ ] legacy可用路径/原错误码与modern unsupported路径回归；probe状态不能把仅service lookup当transport verified，更不能在只读doctor中偷偷发送真实输入。
- [ ] host helper stdout依然单合法envelope，诊断走stderr；backend/source/unknown边界保留到CLI与HTTP，不被外层catch二次包装。

## 4. 主控候选验收顺序

1. 冻结SP-254 candidate SHA与批准diff；复核只涉及transport、所需helper/probe接线和有意义fixture，不夹带Web AX grid、SwiftUI私有遍历、真机或依赖安装。
2. 离线失败测试必须击中no-event/phase types/fallback边界、timeout/cancel/迟到回调、contact局部失败、display拒绝和单JSON，而非只照抄上游happy path。记录实际命令、测试数量与candidate SHA。
3. 运行受影响完整CLI与适用文档/本地门禁；审查框架符号加载、private ABI调用签名及已有legacy测试回归。无授权不启动设备来“补测”。
4. 独立审查通过后才本地合并与合后门禁。发布、真实兼容、运行接替分别记录；本轮真实DeviceHub与现代服务无事件/gesture后置条件均标“未执行，待单独授权”，不能靠mock peer或上游脚本结论补绿。

经验检查：此清单落实既有unknown不得重放、transport ACK不等于业务验证、逐来源许可与离线/真实分层规则，无新repo-wide规则；后续若测试暴露新风险应先修原权威方案，不将假设固化为兼容承诺。

## SP-254 非冻结工作区初审（2026-11-02，仅只读）

执行线程仍在写入，以下绑定当次读到的未提交工作树，不是最终候选缺陷清单；未运行测试或设备。实际接线已看到`NativeSimulatorDigitizer`先选DTUHID/再明确unsupported选legacy，helper在contact序列后调用finish，probe新增endpoint符号可用性但保持available/inputDispatchVerified=false。NOTICE与两份MIT完整许可已新增；仍需最终候选hash/差异核对。

### 必须向主控显式交代的范围

- **Device Hub ownership admission仍阻止modern分支**：`CLIHostNativeHIDCommand.run`在driver构造前、gesture前后均调用`nativeHIDGuardSnapshot`；该函数仍无条件拒绝`com.apple.coredevice.dtuhidd.active=1`。因此DeviceHub已claimed场景无法走到DTUHID。保留guard可以是本期安全取舍，但不能写成“DTUHID已修复DeviceHub claimed输入”；若要解除只能另给backend-aware ownership安全依据及离线接线测试，真实兼容仍待授权。当前NOTICE明确保留ownership，最终文档须同样一致。
- **probe兼容仅代表符号/框架可探测**：endpoint symbols存在不证明选定device service可lookup，更不证明barrier协议或gesture生效。当前保持available=false是正确边界；主控须确认schema/用户说明不把compatible误升为输入可用。

### 读到的WIP测试/状态机不一致（需冻结后重查）

- `DTUHIDSession.send`在down尝试前active=true；下发失败后测试`failuresDoNotReplayAndInvalidPointsNeverSend`直接finish并期待timeout，但实现会因active尚在而先messageInvalid，尚未进入barrier。测试应区分“未释放contact拒绝finish”与“已终结contact后finish barrier超时”。
- `contactStateRejectsDuplicateDownOrUpAndOnlyReleasesAfterFailure`期望move失败后第二次move不再发送、释放后新down拒绝；读到的session没有poison/failure状态，第二次move仍调用peer.send，之后新down也可进入。生产connection异步failure标志与session语义不能互相代替；若目标是fail后仅有界terminal up，须独立状态与测试证明。
- `DTUHIDReply`迟到reply latch虽有lock，真正`DTUHIDXPCConnection`仍没有可注入的XPC peer/endpoint factory测试；现有fake只替换connection协议，会跳过实际event-handler、pending、cancel与message-with-reply接线。主控应判断是否补真实本机XPC匿名peer（不涉及Simulator/设备）离线测试，或明确标未测，不把latch单测当connection端到端证明。
- 每次init/finish各固定4秒；目前尚未看到整条helper剩余预算传入session，也没有取消入口传递到session（connection.cancel主要在异常/deinit）。须核对现有外层helper kill预算及最大gesture时长，明确是进程隔离超时还是协作取消，不宣称两者等价。

以上已向主控即时反馈，不修改实现；执行者随后修改可解决这些观察，最终仅以冻结candidate复审与实际测试结果为准。


## 第二次只读复核：候选接线与前次风险收敛

当时HEAD：`44e81f5d333ba842051579639d3834981e7b2340`，以下仍为未提交候选内容hash绑定；执行线程报告完整CLI 1677 Swift Testing / 178 XCTest通过，本审阅者未运行测试，测试证据由主控核对。读取了全部tracked diff及新增transport/wire、两份测试、许可与候选space资料；不以git diff --stat忽略untracked文件。

结论：本次静态复核未发现需要阻止“离线transport候选”集成的新增缺陷；前次具体poison/finish测试不一致和真实XPC callback接线测试缺口已收敛。保留DeviceHub claimed拒绝、SimDevice私有endpoint所有权/ABI未真实验证及guest/business未证明边界。不将此结论作为最终验收或发布证明。

- poison：Session新增poisoned与releaseAttempted；send抛错后只允许一次未尝试terminal-up，之后move/new-down/finish拒绝；原错误测试拆出独立finish peer以命中barrier timeout。测试断言与现状态机一致。
- callback：新增匿名本机XPC peer通过实际DTUHIDXPCConnection init(connection:)覆盖barrier→touch→finish顺序、pending cancel唤醒、超时后迟到reply不复活。heap reply锁和single-result避免二次完成，connection.failed/pending受另一锁保护，invalidate在锁外唤醒reply，未见明显锁逆序。依然不覆盖SimDevice lookup/private endpoint函数真实ABI和send-right消费约定，这是未授权真实验收边界。
- helper：生产run实际调用performNativeHIDInput；测试调用同一函数，覆盖三次snapshot、modern dispatch/finish、claimed/unknown在makeDriver之前拒绝，以及geometry mismatch只握手不输入。该提取未新增CLI/env override；Resize/ownership门禁原样保留。
- probe：loaded且endpoint符号齐全可报bootstrap prerequisites，available/inputDispatchVerified仍false；消息明确lookup/liveness尚未测试，静态presence不冒充服务可用。无设备barrier隐藏在doctor中。
- 预算：候选契约明确父进程150秒隔离、两次barrier各4秒包含在原余量内，强杀不保证deinit/terminal-up；保持unknown不重放。不是协作取消保证，本期文档已区分。
- 来源：NOTICE列Loupe/idb固定SHA与具体路径，LICENSE.Loupe/LICENSE.idb完整MIT可见；无新增runtime依赖。候选明确不搬运idb retry/drain语义，避免虚假时序等价声明。
- 非阻塞测试余量：typed wire测试对barrier usageCode/state只校验值，未逐个assert XPC_TYPE_UINT64；实现调用set_uint64明确。后续可加断言。生产lookup method/port/endpoint失败目前主要分类函数测试，非设备fixture不能证明真实私有ABI，保持未验收。

### 当次完整文件hash（SHA-256）

| 文件 | SHA-256 |
| --- | --- |
| `CLI/Tests/TritonKitCLITests/DTUHIDTransportTests.swift` | `7388f469de730692530514963f249d9718314cf294ab24cee3478e507e08f981` |
| `CLI/Tests/TritonKitCLITests/DTUHIDXPCPeerTests.swift` | `02a4297fa0da07eaae38b65427df4b2cab6088417ee7ede9392b25d744e382db` |
| `CLI/Tests/TritonKitCLITests/IOSHostHIDProbeTests.swift` | `b1b4bf0c61ba1fc57251f890d9715e89faf5ea5f704c6e98ca580d23909235c7` |
| `Sources/TritonKitCLI/CLIHostDTUHIDTransport.swift` | `fca6e110edbb424f8d60610820cf416de3db717878586b71db1fdd0b0371cc61` |
| `Sources/TritonKitCLI/CLIHostDTUHIDWire.swift` | `b952eaebbfcdb57a25e7e5eda0da180075467d44b609e11c155d9af9a6b4c6c4` |
| `Sources/TritonKitCLI/CLIHostNativeDigitizer.swift` | `8eba13430acfa18d935902ec21bee2a9d957020b3771d98f44749cdecc0fa38a` |
| `Sources/TritonKitCLI/CLIHostNativeHIDCommand.swift` | `06d5ff353f7100581909e86e5a6a85c2900122c93ddaf5ae97a3602946cbdb79` |
| `Sources/TritonKitCLI/CLIHostSimulatorHIDProbe.swift` | `fb2421ccb92f2c4ed0082ab6611547f2c55b50502ee2789c36a8822a27406a21` |
| `Sources/TritonKitCLI/Resources/native-hid/LICENSE.Loupe` | `0d7ebd755456885dba28523a5c468e59d06a26c8df2b896938632c9322c9e7e3` |
| `Sources/TritonKitCLI/Resources/native-hid/LICENSE.idb` | `da6d3703ed11cbe42bd212c725957c98da23cbff1998c05fa4b3d976d1a58e93` |
| `Sources/TritonKitCLI/Resources/native-hid/NOTICE.txt` | `86cd08c3d562090364ef3c5c18f183e861350030f4c5516b2490f955d7c37543` |
| `docs-linhay/spaces/SP-254-simulator-dtuhid-transport/README.md` | `0d90fe59a3729ecba31ad14df13676afb141926c3477b0aef66211d738f35a8d` |
| `docs-linhay/spaces/SP-254-simulator-dtuhid-transport/plans/20261102-transport-contract.md` | `ae9c17ee098ac5431f173d5c8dde2508626ae109136571a2f7d47a02b51e1ece` |

若执行线程冻结前任何hash变化，主控按实际candidate重核受影响差异及测试；本清单不替代冻结提交的祖先/集成检查。

补充：采hash时执行线程已将候选stage，故使用git diff HEAD（含staged+unstaged）核对，共13文件；未执行任何Git写操作。

主控冻结复核：27437c0a的13文件hash全部匹配上述审查；原始full.exit=0，full.log确认XCTest162 + SwiftTesting1677/178。独立docs失败仅因执行分支缺公共SP254索引，交由实际main集成后门禁闭合。
