# 参考项目更新组 C：Xcode 工作流与 Agent 执行

核查时间：2026-10-14 17:44 北京时间。范围为 CLI/HTTP 契约、宿主适配、动作验证与证据；本报告不代表已引入上游能力。只读 GitHub 官方 REST API、发布说明及源码文档，未下载或运行上游代码。除 ai-phone 外，本地无可靠 SHA，只报告 2026-05 参考日期以来已核实的发布与近期提交，不能据此声称完整增量。原始查询端点、精简提交和发布证据见 [agent-updates.json](agent-updates.json)。

| 项目 | 当前状态 / 正式发布 | 默认分支最新提交（北京时间） | 本地基线 / 比较口径 |
|---|---|---|---|
| XcodeBuildMCP → MobileBuildMCP | 未归档、MIT；v2.7.1，2026-09-24 | main `d13ff0c707b0681769cf31da0eb42c4f94ceafff`；09-24 04:14 | 2026-05-20 文档 v2.5.2，无 SHA；发布+近期活动抽样 |
| Harness | 未归档、MIT；v0.8.4，2026-09-03 | main `3f58c077ded131cca71d75efb05c5d325f0ed18f`；09-03 03:54 | 2026-05-21 文档 v0.3.1，无 SHA；发布+近期活动抽样 |
| ai-phone | 未归档、MIT；main v0.8.0，2026-10-13 | main `38ef0c4fd81975195f37bb4ceead9efaaeaeb141`；10-13 17:52 | next/server-brain `e03e8d137e7d5600c779624390dfc3c50485dac8`；基线作者提交时间为05-20 |
| eyes-on-my-phone | 未归档、无正式 release；许可证未充分确认 | main `eef71926e613c3242643923bb21c92beab439990`；05-22 16:44 | 本地无 SHA；全仓可见历史只有2条提交，不作精确增量比较 |

## 1. XcodeBuildMCP / MobileBuildMCP

**更新重点与兼容影响：**

1. v2.7.1 全面更名为 MobileBuildMCP。原 GitHub 地址重定向；包名、二进制、环境变量前缀、resource URI、schema ID、配置与状态目录均改名，旧文档域名已退役。MCP 的字典输入改成 key/value 数组，Xcode IDE arguments 采用 JSON 字符串，在边界验证后才转回内部对象。已有安装说明、桥接配置与外部 schema 验证器必须重评。[v2.7.1 发布](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1)、[更名提交](https://github.com/getsentry/MobileBuildMCP/commit/3794c208d3c2aecbd811263434b8fdcf5f840d20)。
2. v2.7.0 增加 Xcode 27 Device Hub 模拟器操作，按 UDID 选定目标、采用不依赖本地化的菜单动作，兼容旧 Simulator.app；增加可复用 `.xctestproducts` / `.xctestrun` 测试产物，每次仍生成新 `.xcresult`。构建/测试输出 schema 升到3，未指定 configuration 时跟随 scheme action。[v2.7.0 发布](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.0)。
3. v2.6.0 的动作后结果附 compact UI snapshot、稳定 element ref 和 screen hash；新增 wait predicate、batch、drag、差量 snapshot、replaceExisting 及机器可读 nextSteps，并修复失败场景 JSON envelope。其 Weather 性能数据是上游特定任务实验，不视为 TritonKit 收益保证。[v2.6.0 发布](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.6.0)。
4. 7月修复 macOS 停止应用误伤其他进程，以及 shell 参数/下载工具校验、workspace 扫描越界、绝对 DerivedData 和增量产物失效判断。[进程定位修复](https://github.com/getsentry/MobileBuildMCP/commit/a7d367fae1c1fc75f778b5b43753e8c706b28902)、[命令边界修复](https://github.com/getsentry/MobileBuildMCP/commit/61795738bc8b66e637081b114dd43746205174d2)。

**对 TritonKit 的判断：**优先对照 Device Hub 目标绑定、动作后复用观察、prepared test 产物和配置解析契约；补进程定位及 argv 边界负例。更名首先是参考链接/可选桥接的兼容风险，当前 Triton CLI 仍维持自身 envelope 和命令名。这里未证明 TritonKit 存在相同漏洞，也未运行新版真实 Xcode 验证。

## 2. Harness

**已核实发布变化：**

1. v0.8.0 提供 macOS 逐步 UI session、按 launched PID 限定输入/窗口/清理，默认 AX 后转目标 PID 的事件，耗尽后返回 unactuatable；observe/act 增加 structuredContent、point-space marks/rect 与页面文本，失败动作仍带当前观察。[v0.8.0 发布](https://github.com/awizemann/harness/releases/tag/v0.8.0)。
2. v0.8.1–0.8.2 增加 Web 登录 session-state 导入/导出、label_source 和动作前启动的 settle 观察；credential 缺失会失败，password 不作标签来源，WDA text-bearing 错误 body 在构造处脱敏。[v0.8.1 发布](https://github.com/awizemann/harness/releases/tag/v0.8.1)、[v0.8.2 发布](https://github.com/awizemann/harness/releases/tag/v0.8.2)。
3. v0.8.3 使 marks 与 page_text 同受前景 sheet/popover/menu 范围约束，macOS AX 名称解析提供 provenance、元素去重；文本角色 tap 做验证后的 focus，行/单元格做 select，失败不报成功；settle 同时要求连续一致的 AX 几何。[v0.8.3 发布](https://github.com/awizemann/harness/releases/tag/v0.8.3)。
4. v0.8.4 新增 Web set_value，经 native setter、input/change、blur 后读回，兼容 React controlled datetime/select；type 不再把未改变字段误报成功，日志仅返回布尔验证信息。[v0.8.4 发布](https://github.com/awizemann/harness/releases/tag/v0.8.4)。

**对 TritonKit 的判断：**高价值是动作可验证、前景范围一致性、mark 名称来源和错误链脱敏。Web 的整值设定可作为已有 embedded WebView 输入可靠性的专项参照；不应把上游 Web MCP 控制面直接搬进本项目 mock Web。macOS PID session 与真实桌面输入属于独立平台边界，需另做场景验收。release 中测试通过数为上游自述，本次未执行。

## 3. ai-phone

**两条分支必须分别追踪：**

- 研究分支 next/server-brain 仍存在，HEAD `9340e7ac641af20d3b6d42e130b549412e3c7188`，最后提交北京时间 2026-06-15 12:58；与基线直接 compare 为 **ahead 27 / behind 0**。[研究分支比较](https://github.com/dongxinsuperman/ai-phone/compare/e03e8d137e7d5600c779624390dfc3c50485dac8...9340e7ac641af20d3b6d42e130b549412e3c7188)。
- 推荐主线已恢复为 main（Agent 大脑），与研究基线 **diverged，ahead 141 / behind 95**，不是线性升级。main 独有的三端虚拟设备能力不能算成研究分支已提供。[main 比较](https://github.com/dongxinsuperman/ai-phone/compare/e03e8d137e7d5600c779624390dfc3c50485dac8...38ef0c4fd81975195f37bb4ceead9efaaeaeb141)、[分支策略变更](https://github.com/dongxinsuperman/ai-phone/commit/9c7ef2e8fed98d587aa27b6146a263c7742b7860)。

**更新重点：**

1. 研究分支27条增量包括 HDC noisy target 过滤、iOS reconnect readiness、stale JPEG 丢弃、设备状态新鲜度、应用分发及screen-off唤醒、function map context。iOS downsample 机型补物理镜像→WDA 坐标映射，涉及方向与边界 clamp。[坐标修复](https://github.com/dongxinsuperman/ai-phone/commit/c8ac9395dbddca636504b2a83c8144b273f4877b)、[新鲜状态修复](https://github.com/dongxinsuperman/ai-phone/commit/70c9c5b766c983553be6c7535395f69af2684064)。
2. 6月15日研究分支将 GPLv3 切换为 MIT；默认 main 的 LICENSE 和 metadata 也确认 MIT。本地 reference 中“GPLv3”和主线架构描述已过期；只能把当前核查结论用于相应版本，第三方组件仍有自己的声明。[许可证切换提交](https://github.com/dongxinsuperman/ai-phone/commit/6e72093a99ea9c4c0e60adcdcd96dcb3602805b5)、[当前 LICENSE](https://github.com/dongxinsuperman/ai-phone/blob/38ef0c4fd81975195f37bb4ceead9efaaeaeb141/LICENSE)。
3. main 的 v0.5–0.7 扩展 Android、HarmonyOS、iOS Simulator 全生命周期与实例恢复/端口租约；v0.7.1 专门修复单设备长期 readiness 故障扩散及 Simulator/真机扫描串扰。HarmonyOS 的本地公开 headless 仍未验证，不可把 roadmap 视为可用能力。[v0.6.0](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.6.0)、[v0.7.1](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.7.1)。
4. main v0.8.0 给 V3 普通 Click 回放接入 JEV 候选编号决策与三端快速通道，默认关闭，加入加载的有界等待、最新定位图救援交接；同时所有 V3 回放减少 after 截图并调整节奏。上游明确性能样本不保证每次速度，最新关闭分支 iOS 真机验证因锁屏未完成。[v0.8.0 发布](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.8.0)。

**对 TritonKit 的判断：**优先吸收坐标系契约、画面新鲜度、readiness 故障隔离、实例对账与端口租约的场景；JEV 的编号目标/原图与标注图区分适合观察与证据设计，但减少动作后证据的策略需结合我们的审计要求单独验证。分布式 Server/Agent、数据库、远端调度和真机池不自动进入本机接管边界。未来调研必须同时记录 main 与研究分支，不能用 release 推断旧分支拥有新功能。

## 4. eyes-on-my-phone

**未发现持续功能更新。**GitHub 可见 main 历史仅有 2026-05-22 初始提交和 README 封面提交，最新 `eef7192`；没有正式 releases，未归档。8月 repository updated_at 不能解释为8月代码更新。[提交列表 API](https://api.github.com/repos/karminski/eyes-on-my-phone/commits?per_page=30)、[最新提交](https://github.com/karminski/eyes-on-my-phone/commit/eef71926e613c3242643923bb21c92beab439990)、[release API](https://api.github.com/repos/karminski/eyes-on-my-phone/releases)。

当前快照仍是 Android CameraX/AudioRecord + 可选 MNN Qwen3-VL + watchdog 的设备端感知 MCP，文档写缺权重/native lib 时进入 degraded_mode，提供 heuristic 和可选原始 JPEG。它是摄像头/音频感知参考，不是 Android 屏幕点击执行器。[固定快照架构](https://github.com/karminski/eyes-on-my-phone/blob/eef71926e613c3242643923bb21c92beab439990/docs/architecture.md)。

**价值与风险：**可继续参考 provider 缺模型时的降级表达、watchdog 去抖和配对边界；无新增功能可列入本期采纳队列。README 声称 MIT，但 repository license=null，根 LICENSE 查询404，尚不足以确认代码和捆绑组件的授权面。本次只做设计参考，若以后复制需先核对许可证文件。[README](https://github.com/karminski/eyes-on-my-phone/blob/eef71926e613c3242643923bb21c92beab439990/README.md)、[LICENSE API 404 端点](https://api.github.com/repos/karminski/eyes-on-my-phone/contents/LICENSE)。

## 建议进入总报告的优先项

1. **P0 参考事实修正：**XcodeBuildMCP 更名和弃用域名；ai-phone 的分支推荐与 GPLv3→MIT；eyes-on-my-phone 的低活跃/许可证证据不足。
2. **P1 实现对照：**Device Hub 按目标绑定、动作后观察复用、readiness/扫描隔离、敏感错误 body 脱敏与输入 read-back，先与 Triton 已有行为做差距确认。
3. **P2 后续专项：**prepared test 产物、mark provenance 与前景范围、JEV 有界等待与救援图交接。上游宣称的数据只作研究线索，必须通过本项目失败场景、回归及真实 evidence 后才判定可采纳。

验证：JSON解析和指定文件 git diff --check；本次为文档调研，不运行上游或产品测试。无 clone/pull、提交、push、PR 或 merge。
