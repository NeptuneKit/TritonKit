# TritonKit 参考项目更新报告 — 2026-10-14

核查日期：2026-10-14，北京时间。覆盖 23 个主要参考仓库（含 RevylAI 8 个子项目），另附 9 个历史研究候选。采用 GitHub 官方 API、Release notes 与固定 SHA 源码；各请求的观测时间见来源 JSON，不是所有仓库在同一秒的原子快照。报告与验收：[SP-194](../spaces/SP-194-reference-project-updates/README.md)。

## 本期判断

值得优先研究的是**防止输入或验证误报成功、Xcode 27 适配、采集与证据完整性**。iCTRL 与本日登记基线相同，未出现新机制；OpenDeviceHub 与 10-08 研究基线相同。其他项目的活跃更新不能直接解释为 TritonKit 存在相同缺陷，以下采纳顺序属于研究建议。

1. **先对照兼容与安全边界**：sim-use 对 Resize Mode 无法路由的触摸显式拒绝；Loupe 修复 SimulatorKit 的 Xcode 27 路径；simslim 保留特定服务以避免节省资源反而造成泄漏、启动延迟和日志洪泛。
2. **再补验证场景**：Harness 的输入读回与前景范围；mirroir 的全 skipped 拒绝成功；Maestro 的陈旧树、WebView 超时、产物时间线与路径保护；Revyl 的扫描三态和不完整结果门禁。
3. **更新参考事实**：XcodeBuildMCP 全面更名为 MobileBuildMCP；ai-phone 默认主线与原研究分支已分化，当前许可证为 MIT；Rockxy 公共 Community 源码与官方二进制采用不同分发条款。
4. **新能力另立切片**：Baguette typed defaults、Revyl skill 更新治理与 Atlas 图、配置迁移 ledger 值得进入后续候选。远端设备、云平台、MCP/Web 控制面和私有 Runner 不随报告自动采用。

## 比较口径

- `+N` 是相对已归档 SHA 的 GitHub compare 提交数，含合并、发布和依赖提交，不是新增功能数。
- 有旧 SHA 才做确定增量；仅有文档日期/版本的项目，报告近期活动或版本变化并建立首次精确基线。
- Release、源码版本和 HEAD 分开记录。serve-sim 的 0.1.46 来自源码 package，不证明 npm 已发布；Atlantis 的新 loader 只在 main；revyl-cli main 徽章版本也不同于 latest Release。
- Baguette、sim-use 的 compare 提交/文件摘要达到上限；mirroir、Rockxy、revyl-cli 的文件列表达到 300 上限。已读取重点发布、提交与源码，但不宣称逐文件审计了所有变化。
- 性能、上游测试数和平台成功率仅作线索；本次未构建或执行上游代码、未操作设备，不代表 TritonKit 实测收益。

## 1. 模拟器与 Device Hub

| 项目 | 当前版本 / 最新 HEAD | 最近默认分支提交（北京时间） | 相对参考基线 | 本期重点 |
| --- | --- | --- | --- | --- |
| [Baguette](https://github.com/tddworks/baguette/releases/tag/v0.2.6) | v0.2.6 / `8930ac60` | 10-13 17:44 | `fb7cc51a` → +542；有界摘要 | typed defaults、App Group、存在性与类型区分、指定键导入；3D 流与手机预览 |
| [serve-sim](https://github.com/EvanBacon/serve-sim/commit/6d009686ed08f7d8bd19bca9f9f67a9237931f44) | 源码 0.1.46 / `6d009686`；无 GitHub Release | 10-12 02:23 | `f94d57c3` → +23 | Device Hub keyboard target gate、camera helper shutdown 竞态、Duo RealityKit main actor 修复 |
| [sim-use](https://github.com/lycorp-jp/sim-use/releases/tag/v0.15.0) | v0.15.0 / `ca90b054` | 10-14 14:39 | `b809ea84` → +360；有界摘要 | Resize Mode advisory 与触摸/视频拒绝；stdin/file 输入由调用方读取后送 daemon |
| [simslim](https://github.com/MobAI-App/simslim/releases/tag/v0.12.2) | v0.12.2 / `6518ba7e` | 10-09 23:38 | SP-177 catalog `4ae1659a` → +7 | assistantd、gamed、navd 例外；批量 unload 及跨 Apple 平台 profile |
| [OpenDeviceHub](https://github.com/Mastersam07/OpenDeviceHub/releases/tag/v0.2.0) | v0.2.0 / `e50f07f1`，默认 `dev` | 09-28 07:10 | 与 10-08 基线相同，+0 | 无新增；既有折叠屏显示器、重连与菜单目标限制保留参考 |
| [device-hub-ios](https://github.com/JaviSoto/device-hub-ios/commit/9ea14d11e492ae289f2f92e47da6d1b9044adee0) | 无 GitHub Release / `9ea14d11` | 10-14 14:31 | `1fcdfb0a` → +16 | 满窗口画面、测试设备 ownership、先编译后分配设备、进程审计范围限制 |

**对 TritonKit 的影响：**优先在 SP-177 核查最新服务 catalog 的漂移与恢复场景；在 SP-183/SP-180 等适配工作中对照 Resize Mode、宿主键盘目标和 framework discovery。typed defaults 可支撑 `.tritonplan` 的场景准备，但磁盘写成功不能当作运行中 App 已消费新值。上游其他 Apple 平台 profile、远端 adb 与手机控制页仍是独立产品边界。

详细变更、发布链接与限制：[模拟器分组报告](../spaces/SP-194-reference-project-updates/plans/simulator-updates.md)；[结构化来源](../spaces/SP-194-reference-project-updates/plans/simulator-updates.json)。

## 2. Runtime、观察与网络

| 项目 | 当前正式 Release / HEAD | 最近默认分支提交（北京时间） | 相对参考基线 | 本期重点 |
| --- | --- | --- | --- | --- |
| [Loupe](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1) | v0.5.1（10-14 发布）/ `ff135124` | 10-14 16:10 | `5b89c9f5` → +59 | Xcode 27 SharedFrameworks fallback；手势可操作性；失败取消而不重放部分动作 |
| [mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1) | v0.40.1 / `845a9811` | 10-13 16:22 | `7e97f0c8` → +131 | ScreenCaptureKit 优先、减少焦点争用；live target；全 skipped/未执行计划拒绝成功 |
| [Rockxy](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0) | v0.41.0 / `de791b63` | 10-08 15:05 | `120a4428` → +599 | Traffic Insights、本地 Project、SSE/NDJSON/WS 证据、脱敏导出和 retention |
| [Atlantis](https://github.com/ProxymanApp/atlantis/pull/195) | 1.36.0；新提交尚未发版 / `cc059013` | 10-14 17:41 | `6427600e` → +1 | iOS 26/27 NWURLSession loader、async upload body、WS 握手队列顺序与清理 |
| [iCTRL](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1) | v1.97.1 / `99dbfecd` | 10-13 19:32 | 与本日登记及 SP-192 相同，+0 | 无新增；1.97.1 配对文件选择器修复已在基线内，Runner 无功能变化 |

**对 TritonKit 的影响：**对照 SimulatorKit 路径失败证据、只读截图的焦点副作用和实际执行计数。网络 evidence 需要区分原始 capture、脱敏导出、流结束时间与导入保留策略；Atlantis 是 embedded hook 替代路线，其更新不能自动改变我们的宿主代理边界。它在本轮查询期间刚产生新提交，因此报告按独立请求记录，未将其未发布能力归入 1.36.0。

**平台与许可限制：**Loupe v0.5.0 不再支持 Intel，不能照搬到 TritonKit 双架构分发；mirroir 的 iPhone Mirroring 不等于两个独立触点。Rockxy 公共源码为 AGPL Community edition，官方 DMG 的条款和组成另列，代码/产物复用需针对具体对象确认。[Rockxy 固定 README](https://github.com/RockxyApp/Rockxy/blob/de791b63e7f9b5df49f127524a5c9320e675eb23/README.md)

详细报告与固定比较：[runtime 分组报告](../spaces/SP-194-reference-project-updates/plans/runtime-updates.md)；[结构化来源](../spaces/SP-194-reference-project-updates/plans/runtime-updates.json)。

## 3. Xcode 工作流与 Agent

| 项目 | 当前正式 Release / HEAD | 最近默认分支提交（北京时间） | 比较口径 | 本期重点 |
| --- | --- | --- | --- | --- |
| [XcodeBuildMCP → MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1) | v2.7.1 / `d13ff0c7` | 09-24 04:14 | 本地 v2.5.2 文档，无旧 SHA；发布与近期活动 | 全面更名、MCP 字典 wire 表达调整；Device Hub、prepared tests、schema3、动作后 snapshot/ref/hash |
| [Harness](https://github.com/awizemann/harness/releases/tag/v0.8.4) | v0.8.4 / `3f58c077` | 09-03 03:54 | 本地 v0.3.1 文档，无旧 SHA；发布与近期活动 | 输入读回、前景 sheet 范围、mark provenance、PID session 与错误 body 脱敏 |
| [ai-phone](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.8.0) | main v0.8.0 / `38ef0c4f` | 10-13 17:52 | 研究分支 +27；main 与研究基线分叉 +141/−95 | 三端虚拟设备/readiness 隔离、坐标新鲜度；v0.8 JEV click 回放默认关闭；当前 MIT |
| [eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone/commit/eef71926e613c3242643923bb21c92beab439990) | 无 Release / `eef71926` | 05-22 16:44 | 无旧 SHA；全仓可见历史仅 2 条提交 | 未见持续功能更新；仍是 Android 相机/音频感知与模型降级参考 |

**更名影响是现实的参考维护问题：**MobileBuildMCP v2.7.1 改了包名、CLI、环境变量、schema ID、配置目录与状态目录；旧文档域名也已退役。当前 TritonKit 自有命令契约不受其名字控制，但后续可选桥接与排障资料需用新入口。prepared test 产物复用仍要求每次新建结果包，不能复用旧 `.xcresult` 冒充新测试。

**ai-phone 必须区分分支：**原 `next/server-brain` HEAD 为 `9340e7ac`，最近提交 06-15，自基线 `e03e8d1` 增加 27 条；默认 main 与它不是线性升级。6月许可切换已由相应提交与当前 LICENSE 核实，旧参考文档的 GPLv3 与主线描述过期；历史快照及第三方组件仍须分别看许可。新能力不能反推旧分支已具备。

详细发布、分支比较、固定许可证链接：[Agent 分组报告](../spaces/SP-194-reference-project-updates/plans/agent-updates.md)；[结构化来源](../spaces/SP-194-reference-project-updates/plans/agent-updates.json)。

## 4. RevylAI 8 个子项目

| 项目 | 当前版本 / HEAD | 最近默认分支提交（北京时间） | 更新判断与价值 |
| --- | --- | --- | --- |
| [revyl-cli](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.153) | Release v0.1.153（10-14 06:38）；main 徽章0.1.157 / `ac35cd88` | 10-14 14:41 | 旧 SHA → +332；skill 更新冲突、Atlas 范围/完整性、配置迁移账本/备份、runtime 路径保护 |
| [greenlight](https://github.com/RevylAI/greenlight/releases/tag/v0.2.0) | v0.2.0 / `fcb36e39` | 08-06 05:40 | 无旧 SHA；调研后可见新增 Google Play 扫描、三态与未完成扫描门禁、SARIF、runtime verify 分类 |
| [mobile-devtools](https://github.com/RevylAI/mobile-devtools/commit/efc1dae5da089ec08108a39f1ead39324c11b410) | 无正式 Release / `efc1dae5` | 07-22 03:18 | 无旧 SHA；目录增加 GIF Maker 和 Redaction Checker，均是外部工具，不是 Revyl 自有新项目 |
| [figma-design-checker](https://github.com/RevylAI/figma-design-checker/commit/a24695c0ca615619158001e988cfe77d0f8ef93a) | 无正式 Release / `8b4e5cea` | 08-05 04:17 | 无旧 SHA；06-12 增加 Atlas 截图 capture，08-05 仅开发说明 |
| [app-explorer](https://github.com/RevylAI/app-explorer/commit/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e) | 无正式 Release / `b3edc443` | 04-18 04:43 | 默认分支未见05-24调研后活动；保留 static skeleton/runtime map 参考 |
| [mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer/commit/ba1250c72f56a08f3718aefc82dc911c1b3a2f23) | 无正式 Release / `ba1250c7` | 04-08 07:30 | 默认分支未见调研后活动；保留 diff-aware evidence |
| [visual-regression](https://github.com/RevylAI/visual-regression/commit/2758e8a88f4efb3a251b675e0984c091bf8abeb8) | 无正式 Release / `2758e8a8` | 03-14 05:06 | 默认分支未见调研后活动；保留 baseline/current/diff 产物设计 |
| [CogniSim](https://github.com/RevylAI/CogniSim/commit/3d8902e011981b93cb0ebfafba1794eab93b053e) | 无正式 Release / `3d8902e0` | 2024-11-25 06:31 | 默认分支未见调研后活动；保留 AX + set-of-mark 参考 |

**建议：**优先比较我们 public skill 的安装来源/版本账本、保留本地改动与更新冲突，以及 doctor/preflight 是否严格区分“通过、失败、未知/未完成”。Atlas 后续可支撑独立 screen graph，但要带 branch/build/device/runtime 范围、truncated/has_more 和证据回溯；探索过不等于业务验证通过。Revyl 的账户、云构建、云设备及 Computer/SSH 产品不自动进入本机范围。

详细依据、首次基线及文件列表上限：[Revyl 分组报告](../spaces/SP-194-reference-project-updates/plans/revyl-updates.md)；[结构化来源](../spaces/SP-194-reference-project-updates/plans/revyl-updates.json)。

## 5. 历史专题候选附录

这些是已有研究线索，不等于正式采用或已启用自动追踪。本次主要核查当前 HEAD、Release 和 06-20 研究日期后可见活动；缺旧 SHA 不做全量增量承诺。日期为北京时间。

| 候选 | 当前版本 / HEAD | 最近默认分支提交 | 本期判断 |
| --- | --- | --- | --- |
| [Lookin](https://github.com/hughkli/Lookin/releases/tag/1.0.7) | 1.0.7 / `95e30fdc`；Develop | 2024-03-04 | 本次仅核查该仓库；仍作 Debug hierarchy 展示参考，不推断其他 Lookin 组件同步静止 |
| [UGround](https://github.com/OSU-NLP-Group/UGround/commit/8974f95b0685f139a6257f82d6b13895db3356cf) | 无 Release / `8974f95b` | 2026-08-24 | 研究后有 README 更新，不能据此宣称新增模型能力 |
| [UI-TARS](https://github.com/bytedance/UI-TARS/commit/582f3a7ea5d285ee8ed9e2e84048d1ab01453c49) | 无 Release / `582f3a7e` | 2025-09-05 | 原仓库 HEAD 早于研究日期；未扩展查询桌面产品/其他系列仓库 |
| [AgentCPM-GUI](https://github.com/OpenBMB/AgentCPM-GUI/commit/2168ae21b1bed1cdb88736d422934825795a9fd7) | 无 Release / `2168ae21` | 2026-01-11 | 默认分支 HEAD 早于研究日期，保留 Android action schema 参考 |
| [MobileAgent](https://github.com/X-PLUG/MobileAgent/commit/593f9758a83214ed1d5eeeaed533a8d079d446c5) | 无 Release / `11cea575` | 2026-07-07 | 修复 AndroidWorld app 架构优先级、Qwen 依赖与脚本；未做模型基准 |
| [SeeClick](https://github.com/njucckevin/SeeClick/commit/0ef37ac4d7aaf37ba7b990e3e3c3ca77e1fb8f93) | 无 Release / `0ef37ac4` | 2025-07-13 | 研究后未见默认分支活动；本轮 API 识别 Apache-2.0，与旧文档 MIT 描述不同，不能当作已证明许可切换 |
| [android_world](https://github.com/google-research/android_world/commit/3e50888527ef9f29b9157ecd537e408008bb1c85) | 无 Release / `e54ed4f2` | 2026-10-13 | 有近期维护；07-10 AndroidEnv loader 统一端口选择，后续含类型检查维护；未审计所有任务 |
| [Maestro](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.11.0) | cli-2.11.0 / `df40dea5` | 2026-10-13 | 本地2.6.1→发布2.11.0；逐步截图/manifest、陈旧树/WebView 超时、路径保护、unknown 不重试、视频开始时间；Android17/API37 |
| [SKProcessRunner](https://github.com/linhay/SKProcessRunner/commit/24e036604b9e2b28e14c3f55e75a686be1a8bd8a) | Release0.0.17 / `24e03660` | 2026-05-16 | 目前只是 process runner 候选基线；最近提交为错误类型源码兼容修复，无新增活动结论 |

候选证据：[元信息 JSON](../spaces/SP-194-reference-project-updates/plans/research-candidates.json)、[近期活动 JSON](../spaces/SP-194-reference-project-updates/plans/research-candidate-activity.json)、[Maestro 版本变化摘要](../spaces/SP-194-reference-project-updates/plans/maestro-changelog-excerpt.md)。模型代码仓库无 GitHub Release 不代表 Hugging Face 模型未更新，本次不额外核查模型权重。

## 6. 建议后续队列

用户追加询问哪些适合接入后，已只读对照现有源码。建议第一批是 **simslim服务保留规则、sim-use Resize Mode输入门禁、Loupe Xcode27画面流framework加载**。其中HID probe已有SharedFrameworks支持，缺口集中在另一个硬编码加载路径的framebuffer service；workspace业务验证与空plan拒绝也已有，优先补失败场景而不是重写。详见[接入裁决](../spaces/SP-194-reference-project-updates/plans/20261014-adoption-decision.md)。

| 顺序 | 研究切片 | 建议验收边界 |
| --- | --- | --- |
| 优先 | simslim catalog 与 Resize Mode | 先检查已实现范围；服务例外要有 apply/restore、UI功能、日志/内存趋势证据；错误 display 的动作拒绝并带原因 |
| 优先 | Xcode27 framework 与输入契约 | 加载失败路径可诊断；touch/type 的送达与业务断言分开；旧版本与当前平台分别验证 |
| 下一轮 | 动作后反馈与测试完整性 | input read-back、前景目标范围、全skipped拒绝成功、未知结果不重试、敏感错误链脱敏 |
| 下一轮 | 网络 evidence 生命周期 | 原始数据与脱敏导出分层、encoded body 不可检查状态、握手顺序、错误/未完成采集不能当作通过 |
| 独立立项 | defaults / skill update / config migration / Atlas | typed presence、限定键、冲突保护、迁移备份、图范围和截断可读；采用前先与现有能力比对 |

当前仅 [iCTRL SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md) 已启用每天北京时间10:00定时追踪。本报告不新建其他定时任务；上表是后续建议，不代表自动实施。静止项目可降低检查频率，活跃兼容性项目宜优先关注。

## 7. 证据缺口与验证

主要 23 个仓库 API 均可访问、未归档；MobileBuildMCP 是已确认更名重定向。latest Release 404 仅表示没有符合该端点的公开正式版本。OpenDeviceHub 网页读取失败，但仓库/HEAD/Release/compare API 成功，未将其误判下线。

许可证的 API 识别与文件条款必须区分：eyes-on-my-phone、revyl-cli README 声称 MIT，但根 LICENSE 查询404，当前证据不足；多个 Revyl 子项目、SKProcessRunner 的 API license 未识别，本次不作复制授权判断。SeeClick 的现有记录与当前元信息不一致，后续复制前须核对具体版本文件。

本次仅报告与来源归档，无产品代码变更，不运行 Go/Swift/Android 或设备功能测试。文档门禁及来源结构验证结果在 [SP-194](../spaces/SP-194-reference-project-updates/README.md) 记录。长期来源以固定 SHA、Release tag 和结构化证据为准，references 中的旧快照不覆盖、不更新；没有提交、推送或发布。
