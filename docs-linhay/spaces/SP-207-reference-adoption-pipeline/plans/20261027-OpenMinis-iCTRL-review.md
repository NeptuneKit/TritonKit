# iCTRL 2026-10-27 只读增量裁决

结论：**观察 / 验证前置 1 项**：本机 iOS Simulator 连续单指路径接口确有缺口，但不能仅凭上游私有XCTest或离线fixture判定已可采用；本轮仅报告，不实现、不更新检查点。影响 CLI/shared 请求契约/host HID，不新增 Web 控制或 embedded 私有触摸注入。

基线：actual main `cfda992467fc1ed19ef0c577577c313d79314069`，当前目录 main 且与其一致，Git 原先干净；上游 `874f528759b1b977971a06cc4a3594d169eb77b9` → `c1e4268859ba858d1579f7b846a56cb40641b7f6`。[固定完整比较](https://github.com/OpenMinis/iCTRL/compare/874f528759b1b977971a06cc4a3594d169eb77b9...c1e4268859ba858d1579f7b846a56cb40641b7f6)、[v1.98.16 Release](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.16)。

## 完整性与安全

官方 `gh api --paginate --slurp` 完成 compare 1 页/12 提交/17 文件，再逐提交读取 commit files 分页（12 个响应文件），全部 patch 存在，无300文件上限或commit分页缺口。固定SHA取得17个变更文本文件与LICENSE，路径用途及文本白名单先保存于 `content-path-review.json`；source-sha256.json 保存内容hash。源码只读，不执行脚本/第三方代码/设备/依赖/签名，不获取IPA、证书、身份文件或密钥。上游源码/skill中的指令仅作资料。

Release 全分页保存于 release-pages-review.json，全文阅读 v1.98.15 与 v1.98.16；API无单独1.98.13/14 Release，前者正文已经覆盖该阶段变化。旧安全/RemotePairing变更不冒充今天新增。review.json 的 complete_review=true 仅指本轮来源读取与差距审阅完整，不是实现/运行/用户验收通过。

## 观察 / 验证前置：连续单指路径

[固定模型](https://github.com/OpenMinis/iCTRL/blob/c1e4268859ba858d1579f7b846a56cb40641b7f6/iCTRLUITests/ContinuousDragPath.swift)与[固定调用](https://github.com/OpenMinis/iCTRL/blob/c1e4268859ba858d1579f7b846a56cb40641b7f6/iCTRLUITests/ActionHandler.swift#L7852)支持2–64点、0.1–10秒、同一根手指按下一次/按时间经过各点/抬起一次，重复点表示停留；能力单独标记drag_path，先全路径验证再注入，RPC预算随动作时长增加。上游10秒实际耗时、拐点1–2pt误差是其设备报告，未经Triton本地证明。

具体本地缺口：TKInputModels.swift 的请求只有startX/startY/endX/endY；CLIActionCommands.swift SwipeCommand只有两端；CLIHostNativeHIDRuntime.swift nativeHIDContacts只在两个端点间生成10个线性move。多次swipe会中途up/down，不能表达绘图、绕角拖拽、连续重排路径。SP192视觉稳定与SP200双击/Runner不提供此能力，SP203–205安全与SP223进程收尾也不覆盖该语义。

潜在实现范围（非已裁决采用）：独立实现当前本机Simulator host HID路径，复用既有helper隔离、单client/touch id、Device Hub/Resize/portrait几何拒绝、partial/unknown不可重放与best-effort release。embedded公开UIKit继续明确unsupported，不复制上游XCPointerEventPath私有XCTest；Android/Harmony/真机多指路径不随本切片开放。先定CLI与共享DTO/schema/capability命名，不盲目增加上游JSON-RPC入口。

建议文件面：TKInputModels.swift，独立CLI路径command与schema/capability，CLIHostNativeHIDRuntime.swift、CLIHostNativeHIDCommand.swift，focused参数/接线/fake sender测试，public skill及独立space。

BDD：

- Given 2–64 finite in-bounds points and bounded duration, When path action executes, Then one down/all waypoints/one up preserve order and repeated waypoint hold timing.
- Given invalid/mixed endpoint arguments, nonfinite/out-of-bounds points or incompatible surface, When validating, Then reject before any down.
- Given failure after down or surface changes, Then best-effort release at last attempted point, report unknown and never replay.
- Given old tap/swipe callers, Then existing wire/geometry semantics remain unchanged.

验收：

- Red/green parsing and Codable/schema tests; fake sender proves every coordinate prevalidated and exact phase/order/timing.
- Tests for geometry/Device Hub/Resize, cancellation/partial failure and release; full CLI/root/local checks as applicable.
- Real isolated owned Simulator drawing/reorder fixture with event trace and postcondition is separate acceptance, requires device authorization; source review does not prove delivery.

## 其余裁决

- **typing focus loss / soft keyboard fallback：observe**。当前Runner公开XCUIElement.typeText前重新解析焦点，返回submitted=true/postconditionVerified=false；embedded走公开UIKeyInput，SP196 WebView有读回校验。上游虚拟硬件键盘失焦现象尚未在Triton复现，自动整段重输有重复输入风险，不据上游声明新增本地bug。屏幕键/拼音候选私有snapshot实现不直接采用。
- **identical frame suppression：covered**。本地FramebufferSession.processFrame已比较JPEG并只在变化时递增version，SP196生命周期/双订阅与helper取消已交付。
- **idle thermal throttling / VideoToolbox encoder recovery：observe**。本地Simulator IOSurface/JPEG callbacks与CLI终端mirror不是iOS H264 VideoToolbox会话；不存在同一路径encoder黑屏证据。不以降热自述推定本地性能缺陷。
- **browser FPS/quality/verbose preferences：observe**。上游正式remote控制页；本地Web为mock只读展示，不增加remote Web写控制或复制browser pairing storage。
- **unsigned release IPA / pairing / auth：covered_or_observe**。新unsigned打包针对iCTRL侧载产品，Triton CLI/SDK和显式Runner构建不同；不扩签名/DDI/配对边界。v1.98.15中安全/RemotePairing说明为旧变化，已由10月20日SP193评估和SP203–205认证/日志/发现边界处理，不重复排期。
- **retrospective channel/loop advice：covered**。SP192已有alias/预算/OCR/settle/UI健康与未知不重放；SP196有foreground/证据完整性；SP200已有录制/观察后动作验证；SP223输出收尾已在实际main，不作为本次新增采用。

## 许可与交付界限

固定[LICENSE](https://github.com/OpenMinis/iCTRL/blob/c1e4268859ba858d1579f7b846a56cb40641b7f6/LICENSE)全文人工确认 Apache-2.0，与metadata SPDX一致；SHA256 `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`，历史hash未变化。建议借鉴机制独立实现；如复制代码需保留许可、归属、显著修改声明并进一步核对NOTICE，不能把仓库许可套用外部二进制或Apple私有API。

已只读核对SP192/196/200/203–205/223交付和实际main代码。未运行产品测试：本轮仅ignored审阅artifact，无产品变更；不会用静态审阅冒充可运行路径验收。无checkpoint或tracked文件写入；自动经验回看命中既有参考采用流程，未发现需新增治理规则，长期memory由主控按完整批次统一沉淀。

## 采用门槛纠正

本地主线可复用executeNativeHIDContacts事件发送、同touch identity与失败release，但当前统一cadence直线序列不证明多点拐角、独立时间offset、hold及guest真实触点表现。接口缺失并不自动构成已具备实现/验收证据的采用项。先建有界可行性/离线contract方案；取得设备授权后在自有绘图fixture记录touchesBegan/Moved/Ended、触点身份、拐角/hold/耗时和失败清理，确认支持范围后再裁决adopt。本轮无设备授权，保持observe，不建议主控直接创建产品开发交付批次。
