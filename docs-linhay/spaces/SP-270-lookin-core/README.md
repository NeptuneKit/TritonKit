# SP-270 Lookin 核心能力内置

## 当前集成阶段（2026-11-03）

自动 issue 流程复用原负责人已停止写入的精确候选，进行独立审阅、整合与 SwiftPM iOS 16+ 回归。集成分支 `codex/sp270-lookin-integration`，worktree `../TritonKit-worktrees/SP-270-lookin-core-integration/`，基线 `9578782a7cbfd855228f8e996b07d93437725870`。原 `feat/SP-270-lookin-core` 未提交现场、原始证据和专属测试工程完整保留；当前 main 的占号登记由本完整 Space 替代。

集成候选已由 PR #276 合入 main（merge `3b82824333467cf6d4e148cba04a97b3f70705aa`），PR 精确 CI（含标准 Pod）与合并后 main CI 均通过；已随 v0.2.40（`232749b3`）正式发布；原私有 App 现场边界仍不宣称已解决；CocoaPods 已从支持列表移除，iOS 仅支持 SwiftPM/iOS 16+。42 个源码/测试及两个旧候选二进制与原验收 SHA256 一致；Web/package.json 仅保留新主线 0.2.40 版本并接入既有测试清单。标准 Pod 与精确整合回归已由 PR #276 完成；发布采用本定时任务持续授权，正式 v0.2.40 tag 已创建且固定。

## 原候选交接记录（历史阶段）

实现与本地验收完成，独立工作区候选未提交、未合并、未发布。用户 2026-11-03 明确“直接复刻”，并选择“把 Lookin 核心能力做进 TritonKit，沿用现有界面”。此决定替代 SP-061 调研的外部 LookinServer provider 建议；不要求安装 LookinServer 或兼容其 wire。历史 iOS 13 CocoaPods lint 记录已退休；当前发布契约为 SwiftPM/iOS 16+。

- 影响层：embedded UIKit runtime、shared/SDK DTO、CLI/HTTP inspection、现有 Web 只读检查器。
- 基线：origin/main edffb45e；主目录 main cbaf0641 有独立 WIP 与未推送改动，保持原样。相关检查器核心两基线一致。
- 跟踪 issue：[NeptuneKit/TritonKit#273](https://github.com/NeptuneKit/TritonKit/issues/273)，OPEN；记录范围、候选证据与剩余验证/集成事项。
- branch：feat/SP-270-lookin-core。
- worktree：../TritonKit-worktrees/SP-270-lookin-core/。
- 独立实现，不复制 Lookin 桌面源码；上游作为行为参考。LookinServer 根 LICENSE MIT 与 podspec GPL-3.0 不一致，桌面 GPL-3.0，不能忽略文件/制品差异。

## 范围

1. 保留完整 CALayer 树（包括没有 UIView 的自绘层），复用现有几何/预算/对象注册。
2. 实现有界按需节点详情与 solo/group PNG 截图，保留两类图片语义和失败原因，可靠恢复临时绘制状态。
3. 补裸 CALayer 属性读取，复用现有 typed 属性编辑、对象元数据和现有传输。
4. CLI/HTTP 提供详情读取；scene 消费独立图片来源；现有检查器增加只读 3D 分层查看，沿用页面结构和 Rhine Design。
5. SDK Debug-only/Release no-op 和跨平台 unsupported 保持明确；不扩展任意方法控制台、完整 SwiftUI 语义树、外部 Lookin 协议、真机平台边界或原生 Lookin UI 克隆。

## BDD 与验收

- Given UIKit view 下含裸 CALayer/嵌套子层，When 读取 hierarchy，Then 全部在预算内保留且 view/layer 类型、父子关系及几何正确。
- Given 红色父层、蓝色子层及原已隐藏子层，When 请求 solo/group，Then solo 仅含父层、group 含可见后代，结束后所有隐藏状态/顺序不变。
- Given 有效/已释放 OID、空/超量请求、非法像素预算，When 读取详情，Then 合法结果可解码，失败有稳定原因，部分成功不能标完整成功。
- Given 裸层属性修改，When 通过现有 patch-node 修改并回读，Then 读取与实际值一致。
- Given CLI debug details 参数与 HTTP request，When 分发到 runtime，Then 参数/结果/能力/schema一致，失败只有一个合法 JSON envelope。
- Given 带 solo/group 素材的 scene，When 在现有检查器进入3D并选择/旋转/调整间距，Then 与视图树共享选择，缺图诚实回退，不触发设备动作。
- Given Release或非UIKit，When 调用新增详情，Then 不采集、不响应为伪成功。

## 验证安排

先失败测试，再实现；SDK/shared和CLI构建串行，Web独立。根包汇总423、CLI1759、Web174、iOS Debug16/Release5及本地总门禁通过，环境条件跳过与标准Pod限制单独记录。真实CLI/HTTP双图像素、裸层patch回读、evidence capture和正式Inspector组件真实素材验收通过。详细命令、失败修复与边界见[验证记录](plans/20261103-validation.md)，设计见[Web记录](plans/web-design.md)，稳定契约见[技术说明](../../dev/20261103-lookin-core-inspection.md)。

下一步为用户评审及后续集成；不把未整合候选称为已发布功能。自有服务已停止、Simulator已shutdown，原始构建与证据保留在该工作区`.build/sp270-validation-host/`。

## 分工

### 2026-11-03 会话接管

用户要求接手原会话 `01a19f61-54ff-72c0-99b7-f46240745937`。已读取原会话最后实现回合，继续使用上述实际 worktree；原会话元数据仍指向搬迁前的 `.codex/worktrees` 路径，不作为执行目录。接管复核：候选清单中的 42 个源码/测试文件及 2 个 CLI 二进制 SHA256 全部一致，原始 evidence bundle 和 16 张截图仍存在。沿用原验收结果，本轮未重复运行产品测试；本机仍只有 Xcode 27.1，iOS 13 标准 lint 缺口未解除。产品候选仍未提交、未合并、未发布；主目录 WIP 不变。经验检查沿用既有核心说明和验证记录，无新增规则。

- SDK：树/节点截图/详情/裸层属性，含对应模型与SDK测试。
- CLI：details命令、分发/schema、scene图片语义与CLI测试。
- Web：现有检查器只读3D视图、独立评审入口、Web测试。
- 主控：契约裁决、构建/设备串行协调、集成、真实证据、space/index/memory。
