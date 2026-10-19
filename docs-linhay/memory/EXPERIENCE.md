# TritonKit 按任务触发的经验索引

只读与当前任务匹配的行及其权威原文；未命中时再按任务关键词检索 dev、space 和相关记忆，不全量预读每日历史。此表只分流，不登记任务状态或复制证据。[读取、更新与退出流程](../dev/20260619-agent-workflow-skill-governance.md)是治理真相源；使用旧发现前核对原文后续证据及[编号索引](../spaces/INDEX.md)。

| 触发条件 | 下次检查重点 | 权威链接 |
| --- | --- | --- |
| 构建、测试或交付结果声明 | 固定候选差异与实际二进制；代码冻结后重跑受影响检查；区分 fixture、真实运行与跳过，不累加重复测试 | [集成审计](../spaces/SP-190-open-issues-integration/plans/20261012-integration-review.md)、[缓存证据验证](../spaces/SP-175-issue-212-xcode-cache-evidence/README.md)、[上游优化真实验收与失败边界](../spaces/SP-196-upstream-optimization-delivery/plans/20261014-validation-report.md) |
| CLI 错误、递归 schema、replay 或 smoke 改动 | 实际进程输出仅一个合法 envelope；保留底层错误码；检查嵌套模型到最终 JSON 和真实 argv | [CLI 信息契约](../dev/agent-facing-cli-information-architecture.md)、[runtime smoke 修复](../spaces/SP-178-issue-213-real-device-runtime/README.md) |
| SwiftPM manifest、CLI 构建或依赖调整 | 根包不引入 CLI-only 依赖；从 CLI manifest 构建；跑现有 dependency-boundary 检查，核对 package identity | [SwiftPM 依赖边界](../dev/20260521-spm-ios-cli-dependency-boundary.md)、[CLI 修复沉淀流程](../../.agents/skills/tritonkit-ops-governance/SKILL.md) |
| 悬浮选择器、用户标记与 agent 操作 | 自有浮层统一排除；弱引用不证明复用身份；同一MainActor校验并执行；宿主测试和真实手势分开；拖球本身跟手，直接拖动实时预览并选取/长按移位，取消菜单移动模式；父子CLI连接参数做完整argv测试；罗盘保持空间稳定、父子路径记忆需弱身份复核、拖动中截图独立验收；独立显隐不重启连接，隐藏必须有外部恢复入口 | [选择器实现与经验](../dev/20261015-sdk-floating-picker.md)、[验证记录](../spaces/SP-201-sdk-floating-picker/plans/20261015-implementation-validation.md) |
| SDK 内置菜单、能力展示或配置样式 | 圆球是 SDK hub，选择器仅二级路由；状态读取当前实例；宿主配置不等于平台/provider 就绪；追踪字段消费者后才提供开关，硬编码版本不作真实版本；系统 pageSheet/导航/分组列表优先；modal 暂隐藏圆球和选择提示、整窗拦截，关闭/下拉恢复；外围透传仅非 modal；隐藏用系统确认且与罗盘分离；旧系统降级不承诺半屏；宿主菜单归宿主 | [选择器实现与经验](../dev/20261015-sdk-floating-picker.md)、[SDK hub 当前范围](../spaces/SP-209-picker-runtime-toggle/README.md) |
| SDK 接入、runtime bootstrap 或 Debug/Release 配置 | App 文件级 DEBUG 与显式启用；Release 编译并 no-op；包内编译条件和 App 接入条件分别验证 | [Debug-only runtime](../dev/20260519-debug-only-pm-runtime.md)、[iOS 接入](../dev/20260519-ios-integration-guide.md) |
| 设备选择、真机 smoke 或业务就绪声明 | host device 与 App runtime target 分别绑定；安装/启动/ACK 后检查目标与业务后置状态 | [真机 readiness](../spaces/SP-178-issue-213-real-device-runtime/README.md)、[iOS 接入](../dev/20260519-ios-integration-guide.md) |
| 发布资产、Homebrew、public skills 或版本同步 | 核对版本、双架构、BUILD_INFO 与源码边界；下载完整退出后再 checksum/解包；本地打包与实际发布分别验收 | [发布契约](../dev/20260519-github-ci-release-artifacts.md)、[资产复验经验](../spaces/SP-190-open-issues-integration/plans/20261012-v0.2.25-release.md)、[发布 skill](../../.agents/skills/tritonkit-release-package-governance/SKILL.md) |
| Web/Vite/packaged bridge 或 /web 路由改动 | browser 写路由稳定 405，畸形 body 不转发；展示不伪造动作成功；核对后续整合关系 | [Web 只读契约](../spaces/SP-142-web-readonly-contract/README.md)、[后续主线整合](../spaces/SP-151-trusted-baseline-integration/README.md) |
| DerivedData、增量构建或缓存命中解释 | 目录存在/mtime/逻辑 bytes 不证明命中、最后使用或可回收量；读 observedBuild 与日志覆盖，截断保留 partial | [缓存观察契约](../spaces/SP-175-issue-212-xcode-cache-evidence/plans/20260908-cache-observation-contract.md)、[清理边界](../spaces/SP-179-issue-214-derived-data-cleanup/README.md) |
| 删除、路径保护或并发安全修复 | 精确根白名单与只读 preview；核对当前 fail-closed 边界；恢复删除前证明排他、根身份及 partial 审计，隔离负例抓旧错 | [安全清理与剩余风险](../spaces/SP-179-issue-214-derived-data-cleanup/README.md)、[CLI 清理契约](../dev/ai-cli-readable-control.md) |
| 外部资料、归档会话、多 agent 结论或旧计划引用 | 区分纠正/方案/最终结论/实际落地；只继承事实线索；核对当前授权、真实 diff 与后续替代证据 | [治理流程](../dev/20260619-agent-workflow-skill-governance.md)、[监督审计](../../.agents/skills/tritonkit-subagent-supervision/SKILL.md) |
| 文档入口、内部 skill 接线或经验校验器调整 | 核对普通任务默认自动沉淀与收尾证据；可见规则/链接才算接线，示例/注释不算；隔离正负例防回退；并行登记前重查编号 | [治理闭环与校验边界](../dev/20260619-agent-workflow-skill-governance.md)、[本轮校验证据](../spaces/SP-198-agent-experience-loop/README.md) |
| 参考上游增量、采用分派或跨分支资料整合 | 先区分主目录HEAD与真实main；完整读取后独立推进检查点；采用与读取去重分离；模型失败不伪造thread；按清单保留较新授权与main产品历史 | [参考采用流程](../dev/reference-project-adoption-workflow.md)、[采用登记](../spaces/SP-207-reference-adoption-pipeline/README.md) |

| Simulator AX几何、Android前台身份或legacy文本输入 | AX拒绝猜测并测试生产提交边界；前台只展开ComponentName前导点且无效top不回退；shell字面量安全与设备输入能力分开验收 | [AX几何](../spaces/SP-210-simulator-ax-geometry/README.md)、[Android契约](../spaces/SP-212-mobile-mcp-android-contracts/README.md) |
