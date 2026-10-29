# #224 显式主屏截图契约与验收

## 范围

用户继续处理#224，验收环境为Xcode27.1。CLI新增 `sim screenshot --primary-framebuffer`，只读、单次PNG；默认截图、device/top-level screenshot、录像、MJPEG、AX/HID不变。既有SP235承接issue中请求的bounded explicit framebuffer recovery，不新增Web/HTTP写入口。#224保持OPEN直到剩余边界明确；本轮不合并/发布。

## BDD

1. Given显式主屏选项与--display同时出现，Then在discovery/probe/输出IO前拒绝。
2. Given fresh Resize inactive或严格目标绑定的unsupportedDevice，且完整displays只有一个LCD/integrated/primary/activeOn，Then使用该次UUID截图，输出primary-display-framebuffer证据；unsupported仍为unknown、resizeVerified=false、inputDispatchVerified=false。
3. Given active/其他unknown/错目标或命令/失败/混合错误/截断/缺字段/额外off虚拟显示器，Then拒绝且零截图调用。
4. Given显式选项未提供，Then所有原保护不变；不把本模式结果用于触控、App内容完整或默认恢复声明。
5. Given捕获exit0但没有新PNG/不可解码/尺寸非法，Then失败；已有输出文件/链接不覆盖，成功产物须独占发布。

## 本机只读证据与生命周期

只操作前轮自有iPhone17与iPad A16，原始JSON/截图留ignored `.build/issue-224-display-proof/`，本文件脱敏。Triton状态/能力/schema先取证，产品不覆盖Resize start，故仅为自有fixture原生启动560x874会话，再SIGINT结束。

- iPhone开始前：24004 inactive，单个LCD。活动时：成功Resizable会话，清单含LCD及off虚拟Resizable，UUID对应。结束后：24004 inactive，但off Resizable仍留清单。因此显示器存在不能等同会话活动，背光off不能等同无会话。
- iPad：精确1001 capability rejection，完整清单单LCD；显式原生UUID截图成功。此项为后端可行性探针；后续产品验收见下方。
- 两次查询不是原子快照；绑定UUID避免新增显示器导致静默改拍，但不证明整个设备状态不变。独立审计同意捕获单独契约，否定以清单代替全局inactive/HID授权。

## 验证

红测：命令/契约2测试10断言失败，后端6测试18断言失败（fail-closed stub）；随后新增共用probe与产物测试，12测试focused通过。首次编译修正nonZeroExit实参标签。

真实候选：iPad显式截图1640×2360成功且目视为完整主屏LCD，输出unknown/unsupportedDevice、resizeVerified=false/inputDispatchVerified=false；默认截图及swipe仍typed拒绝，已有文件拒绝。iPhone默认截图1206×2622成功；单次swipe派发成功，前后截图确认Settings列表确实滚动；活动Resize默认截图1680×2622按原UUID路由，新模式拒绝active；结束后残留off虚拟屏也拒绝新模式。原生自有Resize进程均SIGINT正常结束。脱敏结果见[机器摘要](20261028-primary-framebuffer-evidence.json)。

真实互斥参数初版返回ArgumentParser文本而非JSON，已改为run开头typed validation，先于discovery/IO；最终CLI已复验为exit1、单一合法JSON、parameter_conflict且无输出文件；无效目标仍先收到互斥错误，证明先于discovery。完整CLI首轮1578测试3问题：缺失display failure父schema与recovery mapping两处已修复；未改动Harmony BuildRuntime fixture返回hvigor_build_failed而非预期hap_artifact_not_found，耗时34秒，根因未定，保留原日志并复测，不能当产品通过。随后发现CLI本地构建缓存不可用，重新构建，不归因到#214或删除动作。

独立审计确认安全/默认兼容边界，并建议补有效PNG+非零退出、PNG签名正确但截断反例以及display来源schema说明；均已补。Harmony同一未改fixture独立复跑通过（0.332秒），未确定首轮异常的底层原因、不修改该测试。schema补生产recovery family及独立测试taxonomy，并断言diagnose/plan不暗示重发。iPad最终候选截图再次成功，两自有Simulator已通过Triton shutdown并列举确认，Resize子进程已正常退出。docs/skill门禁已通过；最终完整CLI 1578项Swift Testing +94项XCTest全部通过，本地总门禁通过（根包401+7、Release CLI构建/smoke、Harmony/iOS observe smoke、docs）。可选裸Xcode构建以TRITON_VERIFY_XCODE=0跳过：本轮无embedded/UIKit/Runner源码变更，真实host设备验收单列，shared只补错误恢复分类。

## 2026-10-29 收口

第二轮全CLI暴露既有HostProcessDrain executionTimeout(combined)竞争：intentional interrupt=10ms早于execution deadline=50ms，可能在shell装trap前完成duration中断。测试改为复用已有invoke（combined cutoff=5秒），保留同一50ms执行超时及严格抛timeout断言；独立intentional interruption测试未改，生产runner未改。152项相关focused及最终全量通过；原始失败日志保留，不将此表述为已证明宿主具体调度时序。经验写回ops治理原条目。

阶段：实现与本地整合验证完成；已准备更新PR #236，未合并、未发布。#224继续OPEN；iPad输入仍缺安全Resize/触摸路由证据，后续只在获得可验证后端或独立路由契约时推进，不以本次主屏取证解除限制。主工作区17个原WIP文件hash、status、HEAD复核均未变；#214保持暂缓。

## 合并记录

2026-10-29用户授权合main；PR #236合并为27c7a875，合并树与已验证8c2fab81一致。[候选CI](https://github.com/NeptuneKit/TritonKit/actions/runs/40725631168)全部通过（发布作业按规则跳过）。#224/#214保持OPEN；主目录WIP未变。仅合并，不发布；不沿用历史“未合并”作为当前状态。
