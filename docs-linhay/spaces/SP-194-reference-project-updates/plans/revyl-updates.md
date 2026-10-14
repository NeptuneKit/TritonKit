# RevylAI 参考项目更新报告

- 截止：2026-10-14，北京时间；以下表格日期均为北京时间。
- 范围：本地 `docs-linhay/references/revylai.md` 已登记的 8 个仓库。
- 方法：只读 GitHub 官方 REST API；交叉核验 Release 页面。未 clone/pull、未运行上游代码。机器证据：[revyl-updates.json](revyl-updates.json)。
- 基线：revyl-cli 有旧 SHA `9931a77d9f98942f5aa3622e25d9e0613dca0e47`（本地记录克隆日期 2026-05-27）；其余项目只有 2026-05-24 调研文档，没有旧 SHA。本报告为它们建立首次精确基线，并明确区分「该日期后可见活动」与「完整差异」。

## 当前状态

8 个仓库均可访问，默认分支均为 `main`，未归档、未禁用，API canonical 名称与原名称一致，未发现仓库重定向。Release 404 仅指 latest Release 端点未找到公开非预发布版本，不是仓库 404。

| 项目 | 当前默认分支 SHA | 默认分支最近提交，北京时间 | 最新公开 Release | 许可证核验 |
| --- | --- | --- | --- | --- |
| [revyl-cli](https://github.com/RevylAI/revyl-cli) | `ac35cd88e6f122b9e956069d6f170380a419d3d1` | 2026-10-14 14:41，monorepo 同步 | [v0.1.153](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.153)，2026-10-14 06:38 | README 自称 MIT；API 未识别且根 LICENSE 404，未核实完整条款 |
| [app-explorer](https://github.com/RevylAI/app-explorer) | `b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e` | 2026-04-18 04:43，iOS skeleton extraction PR 合并 | latest 404 | API 未识别 |
| [greenlight](https://github.com/RevylAI/greenlight) | `fcb36e395bd4ae20448f2535382baecba9396fd9` | 2026-08-06 05:40，按单库检测 64 位缺口 | [v0.2.0](https://github.com/RevylAI/greenlight/releases/tag/v0.2.0)，2026-07-29 04:17 | MIT（API） |
| [mobile-devtools](https://github.com/RevylAI/mobile-devtools) | `efc1dae5da089ec08108a39f1ead39324c11b410` | 2026-07-22 03:18，加入 Redaction Checker | latest 404 | API 未识别 |
| [mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer) | `ba1250c72f56a08f3718aefc82dc911c1b3a2f23` | 2026-04-08 07:30，recording 模式 PR 合并 | latest 404 | API 未识别 |
| [visual-regression](https://github.com/RevylAI/visual-regression) | `2758e8a88f4efb3a251b675e0984c091bf8abeb8` | 2026-03-14 05:06，修正 CLI 链接 | latest 404 | API 未识别 |
| [figma-design-checker](https://github.com/RevylAI/figma-design-checker) | `8b4e5cea045dcff5c30aa723b923e514d2cdc07a` | 2026-08-05 04:17，Cursor Cloud 开发说明 | latest 404 | API 未识别 |
| [CogniSim](https://github.com/RevylAI/CogniSim) | `3d8902e011981b93cb0ebfafba1794eab93b053e` | 2024-11-25 06:31，主仓库文件同步 | latest 404 | MIT（API） |

“API 未识别”不等于没有许可证；本轮未逐仓库审阅其许可证文件。最近活动用默认分支提交日期，未把 star、issue 或仓库元数据的 `updated_at` 当成代码更新。

## revyl-cli：更新最多，优先读契约与安装治理

[旧基线到当前的官方 compare](https://github.com/RevylAI/revyl-cli/compare/9931a77d9f98942f5aa3622e25d9e0613dca0e47...ac35cd88e6f122b9e956069d6f170380a419d3d1) 返回 `ahead`，新增 332 个提交、落后 0。API 返回 300 个文件，已触及文件列表上限，因此此处是重点抽样，不是全部功能审计。大量提交标题只有 monorepo 同步编号，具体能力需依据差异文件及文档判断。

当前 README 版本徽章为 **0.1.157**，但公开 latest Release 为 **v0.1.153**。必须区分开发分支与已发布版本；下述当前行为只证明 main 文档和代码存在，不能全部归为 v0.1.153 的 Release 内容。[固定 SHA README](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/README.md)

确定值得跟进的变化：

1. **Skill 安装/更新治理更成熟**：推荐与可选 catalog 分离，提供已安装 JSON 查询与 `skill update`；共享 `.agents/skills/` 安装完整 package，更新保留本地改动，冲突有说明，`show/export` 只输出根文件。TritonKit 可借鉴包完整性、安装来源/版本账本、未修改包更新及冲突检测；不需要接入 Revyl 账户。[skill 实现](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/cmd/revyl/skill_commands.go)
2. **Atlas 观察图与探索入口增强**：新增 `explore.go`，Atlas 文档以观察证据支撑扁平 graph，明确起点、typed edges、双向遍历、branch/build/device/runtime 过滤和 `truncated/has_more`；节点可回溯源报告及视频区间。TritonKit 后续 screen map 应继承范围与完整性契约，避免把图边误当页面父子关系，把“未知/未采样”误判为不存在。[Atlas 文档](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/docs/atlas.md)、[探索入口](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/cmd/revyl/explore.go)
3. **配置迁移成为显式工作流**：新增 `config_migrate.go`；README 明确预览、迁移 ledger、原字节备份、原子替换、目标冲突停止，创建 test 不再顺带创建/迁移项目配置。TritonKit 可用同样原则治理 schema/config 升级，迁移与远端动作保持清楚边界。[迁移实现](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/cmd/revyl/config_migrate.go)
4. **本地 runtime 文件权限与路径保护**：新增私有运行文件实现；managed path 禁止目录符号链接跳转，Unix 目录/文件按 0700/0600，读取不改变旧权限。适合检查 TritonKit 的 evidence、会话状态和日志缓存写入路径，但用户指定导出目录与内部目录需分开约定。[路径治理文档](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/docs/local-runtime-files.md)
5. **产品范围扩大**：比较结果新增 `proof.go` 与独立 `revyl-computer`，Release 包提供独立 Computer CLI，包管理器安装不包含它。可参考产品入口和产物区分；当前 TritonKit 的本机移动设备边界不随上游扩成云桌面/SSH 产品。[Computer 入口](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/cmd/revyl-computer/main.go)、[proof 入口](https://github.com/RevylAI/revyl-cli/blob/ac35cd88e6f122b9e956069d6f170380a419d3d1/cmd/revyl/proof.go)

## greenlight：从 iOS 离线检查扩到 Android，并修正“未完成也通过”

没有旧 SHA，不做全量差异承诺。官方历史可确认 2026-05-24 后发生以下变化：

- **Android Google Play 扫描**：v0.2.0 是首个支持 Google Play 的 Release，`playscan` 涉及源码、manifest 和 APK/AAB；最新修复按每个 native library 检查 64 位缺口。值得借鉴源码与构建产物互补，以及无法解析信息时明确输出缺口。[Android 新增提交](https://github.com/RevylAI/greenlight/commit/7223ea2c4a150ac233b303e6363e61ed61ce763e)、[64 位缺口修复](https://github.com/RevylAI/greenlight/commit/fcb36e395bd4ae20448f2535382baecba9396fd9)
- **真实三态结论、HIGH 与 CI exit code**：扫描器崩溃或不完整也会阻止成功判定；新增 SARIF 2.1.0 输出。适合 TritonKit doctor/preflight 区分通过、已证明失败、无法完成验证；“未观察到”不能当通过。[三态提交](https://github.com/RevylAI/greenlight/commit/ab0e5c318151b801fed6baa871c3d1cebf6416d7)、[不完整扫描门禁](https://github.com/RevylAI/greenlight/commit/921c0dfff03327cddb4667ab023c7ae0c4f38baa)、[SARIF 提交](https://github.com/RevylAI/greenlight/commit/afbc262dd844c9c3a6d46e168b69382a3874427c)
- **静态检查与 runtime verify 分层**：新增 Revyl CLI 驱动验证，并修正不能把 setup/launch 失败记成业务流程失败、等待报告最终态、临时凭据/预演脱敏等问题。TritonKit 可吸收失败分类和 evidence 完整性；云验证与 App Store/Play 合规结论均是独立需求，不能直接等同现有 smoke。[runtime verify 新增](https://github.com/RevylAI/greenlight/commit/809813a3d40ecad61e4d13f66a007cd9dc2aa050)、[失败分类修复](https://github.com/RevylAI/greenlight/commit/5c42005cdfc33ed875d31e6ac5b833aefcdfa2be)

## 工具目录与 Figma：有更新，但先作为候选

- **mobile-devtools**：2026-06-09 加入 Device GIF Maker，2026-07-22 加入 Redaction Checker。后者关注 iOS app switcher / Android recents 的敏感页面遮挡；可形成未来隐私截图回归候选。两个工具属于 `ethanzhoucool` 的外部仓库，只是在目录中被推荐，不能误记为 RevylAI 自有仓库或本次已批准采用的参考项目。[目录当前内容](https://github.com/RevylAI/mobile-devtools/blob/efc1dae5da089ec08108a39f1ead39324c11b410/README.md)、[Redaction Checker 加入提交](https://github.com/RevylAI/mobile-devtools/commit/efc1dae5da089ec08108a39f1ead39324c11b410)
- **figma-design-checker**：2026-06-12 新增 Atlas 驱动 screenshot capture；2026-08-05 仅新增开发环境说明。启发是复用已观察截图做设计核验，降低重复设备采集；布局语义匹配、动态区域与截图范围仍需单独设计。[Atlas capture 提交](https://github.com/RevylAI/figma-design-checker/commit/a24695c0ca615619158001e988cfe77d0f8ef93a)、[开发说明提交](https://github.com/RevylAI/figma-design-checker/commit/8b4e5cea045dcff5c30aa723b923e514d2cdc07a)

## 四个静止项目：保留参考，降低检查频率

`app-explorer`、`mobile-pr-reviewer`、`visual-regression`、`CogniSim` 当前默认分支最后提交均早于本地 2026-05-24 调研记录，未发现该日期后的默认分支代码活动。本轮不是旧 SHA compare，也未审阅全部分支，不能据此宣称“项目完全停止”。

保留既有价值：app-explorer 的 static skeleton + runtime map、mobile-pr-reviewer 的 diff-aware evidence、visual-regression 的 baseline/current/diff 产物、CogniSim 的 AX + set-of-mark。优先关注主 CLI 的 Atlas 演进，静止项目可月度核验。原始 HEAD 证据分别为：[app-explorer](https://github.com/RevylAI/app-explorer/commit/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e)、[mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer/commit/ba1250c72f56a08f3718aefc82dc911c1b3a2f23)、[visual-regression](https://github.com/RevylAI/visual-regression/commit/2758e8a88f4efb3a251b675e0984c091bf8abeb8)、[CogniSim](https://github.com/RevylAI/CogniSim/commit/3d8902e011981b93cb0ebfafba1794eab93b053e)。

## 建议交由主报告排序

1. 近期：检查 skill 更新/冲突治理、失败三态、配置迁移备份与 runtime 文件保护是否已有对应 TritonKit 契约。
2. 下一轮专题：Atlas 图的完整性、过滤作用域与证据回溯。
3. 候选 backlog：Android 源码/产物 preflight、Figma 复用观察截图、后台敏感页面遮挡测试；均需独立 space 后实现。
4. 保持产品边界：不引入 Revyl 云构建、账户、云设备、Computer/SSH 或自动远端写入。
