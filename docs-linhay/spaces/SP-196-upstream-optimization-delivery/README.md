# SP-196 — 参考更新优化交付

## 边界与授权

用户授权主控推进SP-194建议的规划、开发与验证。影响CLI/HTTP/shared core、host simulator和embedded WebView；Web只读展示。用户后续已授权分段提交、推送与发布；保留主线 SP-195 Runner、SP-197 高亮及 SP-198 治理改动。

状态：**已集成、推送并发布 v0.2.28**。独立worktree：`../TritonKit-worktrees/SP-196-upstream-optimization-delivery/`；branch：`feat/SP-196-upstream-optimization-delivery`；起点main@306dc42b。主控负责集成、失败场景、验证与记忆。主仓文档和索引为事实源，代码隔离于worktree。

## 交付队列与BDD

1. 资源安全：Given最新服务例外，When计划/apply/restore，Then assistantd/gamed保留、widgets保留navd，旧receipt与未知runtime不能误改用户override。
2. Resize Mode：Given目标显示器改变，When host触摸/截图/视频，Then携带正确scene/display事实；不能路由的输入拒绝，不把unknown当无resize。
3. Framebuffer/helper：Given所选Xcode27或阻塞消费者，When加载/取消，Then路径可诊断、终止有界、会话资源不串扰。
4. WebView输入：Given受控表单/日期/select，When type/set-text，Then native setter、适用事件与读回验证；无变化不报成功，secure不泄值。
5. 前景目标/证据：Given模态或不完整执行，Then候选范围一致、来源可解释、dry-run/skipped不当业务通过、失败保留证据时间线。
6. 测试复用：Given匹配编译产物，When测试执行，Then build-for-testing与test-without-building分离、每次新结果包、失效明确拒绝。
7. 场景配置：typed defaults保留presence/type/限定键；磁盘成功不证明运行App消费。
8. 安装与迁移：skill/config预演、校验、备份/冲突/原子替换，保留本地修改；managed路径与权限安全。
9. 网络与地图：沿用header-only采集与已有App Map，补完整性/范围/证据回溯，不扩采敏感body或接云平台。

## 证据与验收

每切片先失败测试，再最小实现；独立文件面可并行，shared scratch/服务/设备串行。focused测试、CLI完整回归、root/iOS/WebView实际destination按影响验收，本地verify门禁与docs检查；未覆盖平台必须明确记录。不把subagent完成声明当最终通过。

- [实施与验证计划](./plans/20261014-delivery-plan.md)
- [原始更新报告](../../dev/20261014-reference-project-updates.md)
- [接入裁决](../SP-194-reference-project-updates/plans/20261014-adoption-decision.md)

## 本地完成结果

11项优化已实现，详见[验收报告](./plans/20261014-validation-report.md)、[机器可读摘要](./plans/20261014-validation-summary.json)与[工程说明](../../dev/20261014-upstream-optimization-delivery.md)。CLI XCTest41项与Swift Testing报告1323项无失败（1项live默认禁用，另行显式启用通过）；真实iOS56项全部通过、无跳过。根包、本地总门禁、Release SDK编译及文档/安装门禁通过。

专用模拟器资源plan/apply/verify/restore完成，前后disabledLabels完全相同；typed prefs与relaunch实测、真实JPEG双订阅生命周期、一次编译两次测试复用及源码漂移拒绝均完成。原始设备身份、日志、结果包留在私有忽略目录。

真实active Resize、跨OS私有ABI、客户React业务消费和性能收益尚未证明；详见报告的剩余边界。本段保留隔离候选验收口径；后续已分段提交、主线集成并在新候选重跑门禁，最新状态见下方发布记录。本工作区SP-195只保留编号连续所需文档快照，不携带Runner实现。


## 提交与发布授权

用户追加分段提交、推送、发版；8个产品切片已与最新main集成，候选CLI1394+51、真实UIKit76项及总门禁通过。v0.2.27编译失败后以v0.2.28完成发布，原“未提交/未合入”描述保留当时验证阶段，最新阶段以[发布记录](./plans/20261014-release.md)为准。


## 已发布验收

2026-10-15：v0.2.28发布与双架构/Homebrew/skills/Runner验收完成；CLI1394+51、真实UIKit76项全过。详见[发布记录](./plans/20261014-release.md)与[机器可读发布摘要](./plans/20261015-release-summary.json)。v0.2.27旧编译器失败尝试保留tag，不移动历史。专项未测边界保留。
