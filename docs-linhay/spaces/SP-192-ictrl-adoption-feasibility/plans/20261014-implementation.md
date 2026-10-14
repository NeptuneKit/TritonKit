# SP-192 实施计划

状态：五项实现与本地门禁完成，独立 worktree 待集成。基线：8aaf6c31。仅本机 CLI/HTTP、host 观察与 Debug runtime；独立 Runner/DDI 不在本期。此前 Android APK 依赖阻塞与四项 iOS 既有失败已在[限制收口](./20261014-limitation-resolution.md)解除：Android 52 项及完整 APK、iOS 115 项通过。真实输入/坐标校准边界保留如下。

## 场景与合同

1. alias：Given schema 2 缓存，When `node resolve @N`，Then 校验 30 秒有效期、平台/真实目标/来源，重新采集当前观察并比较忽略 frame/focus 的全树身份指纹；精确唯一候选返回新 frame，换页、OID 变化、缺节点、多候选、旧 schema、当前遍历截断 fail closed 并提示刷新。host 索引身份无法辨别重启后完全相同的树；不宣称无条件 page generation，不新增 `tap @N`。以较小 `--max-nodes` 生成的 outline 若与当前更完整树不一致，也要求刷新。
2. 预算：Given 宽深树，When 采集，Then 节点、深度、宽度、deadline 在预处理和遍历中生效，输出 collection / truncation 与稳定限制原因。Simulator 用同一受限遍历处理翻译准备和读属性；embedded hierarchy/AX 在 UIKit 采集处应用预算；Android bridge tree 应用预算、Android XML 和 Harmony host layout 在主机解析/转换处限制。Swift scene、CLI 和 JS 只读归一化保留 metadata。设备端 dump、JSON 解码或 native 属性/children 调用本身仍可能先 materialize 完整结果，不能把后续遍历预算或 IPC timeout 写成 native 硬取消。
3. 视觉 settle：Given 截图序列，When 连续帧变化面积低于阈值且达到稳定窗口，Then settled；持续变化 timeout、无法采样 unknown。入口 `triton observe settle --device sim:<udid> --json` 或连接 runtime `--target <id>`；使用单次选定目标与有界采样。workspace `run --observe-live --execute-actions --visual-settle` 显式启用动作后视觉反馈；可配置 timeout/stable-window/threshold/interval。timeout/unknown 停止自动续行，不虚构新截图或重用缓存坐标；settled 保持 `businessVerified=false`，业务 verified 仍依赖既有断言。
4. OCR：Given 明确图像或截图目标及 policy，When 调用 `triton observe ocr --image <path> --json` 或 `--device sim:<udid>` / runtime `--target <id>`，Then macOS host Vision 返回来源、置信度、采集时间来源、freshness、raw-raster 坐标和 `candidateOnly`。默认 policy explicit；structure-unavailable 必须提供结构失败原因。像素原点为左上角，不隐式套用 EXIF 旋转；已知 scale 才能给 points，仍需真实截图到输入坐标验收。文件 mtime 标记为非采集时间，freshness=unknown；不伪造 OID、不自动点击或升级语义保证，既有 VLM 能力保留。
5. 健康：Given UI provider 阻塞，When ping/诊断或再次申请 UI 请求，Then 非 MainActor admission 提供占用和健康事实，不等待原 UI 工作；超时动作 outcome=unknown 并保持占用至真实完成，未启动动作拒绝重放；连续超时熔断并给出显式恢复建议。默认 runtime UI deadline 30 秒、连续超时阈值 3；后台 timeout 只释放调用者等待，不终止 MainActor/native 工作。旧 ping 缺失 uiHealth 应解释为 unknown，不能默认为 ready。Android UI 和健康请求隔离资源；平台实测仍单独验收。

## 文件所有权与集成

- alias track：CLIObservationModels / CLIObservationRuntime / CLINodeAliasFreshness 与专门测试。
- Simulator budget track：CLIHostSimulatorAXDriver / CLIObservationBudget 与专门测试。
- visual track：CLIVisual*、CLIWorkspaceVisualFeedbackRuntime、provider / 纯差分 / OCR / workspace 测试。
- health track：runtime RequestHandler、UI health controller / shared 合同与测试。
- Android budget track：Tools/AndroidBridge tree 采集 / 健康隔离及 fixtures。
- hierarchy metadata track：shared scene、CLI legacy decoder / 转换、JS 只读归一化与测试。
- 主控：跨模块接线、embedded / Harmony / Android XML 预算、命令/schema、验证、文档与最终审计。

所有构建/测试由主控串行调度，subagent 先补测试、实现后返回待验证点。禁止修改其他 worktree、提交、推送或操作用户 App。源码与文档结论须按实际证据同步。

## 首轮实现验证历史

首轮 focused CLI 测试 71 项中 1 项失败：visual unavailable 的 observation.captured 缺截图；已修复事件与 Atlas 的事实边界。新增命令/schema 后复跑 78 项、10 suites 全通过。根包 macOS 全量 274 项、37 suites 通过；Web hierarchy route 12 项通过。

iOS 使用 `triton xcode test --package . --scheme TritonKit-Package`：源码与测试编译成功，xcresult 汇总 109 passed / 4 failed。新增 collection metadata 与非语义 UIKit view 预算测试均通过。相同机器/Simulator 的原始 `main@8aaf6c31` 对照为 98 passed / 5 failed：本次四项失败全部在基线重现（alert modal 三项、UIView.alpha / layer.opacity 一项），未观察到新增失败。保留现有失败，不把整体 iOS 测试写成全绿；初次 `TritonKit` library scheme 没有 test action，已改 package scheme。

Android `./gradlew --offline :app:testDebugUnitTest :app:assembleDebug` 在插件解析失败，在线解析停滞后停止本任务进程。AGP 8.5.0 jar 与 SDK34 在缓存，但仓库 metadata 未解析；Google Maven 连接超时，MockK / org.json 缺缓存。用缓存 Kotlin 1.9.24 + SDK34 直接编译全部 16 个主源码文件，通过；缓存 JUnit 两套纯 JVM 场景 7 项通过。临时 BuildConfig 仅存 gitignored 私有验证目录，不进入产品。直接编译与纯 JVM 通过不能替代 APK / Android-coupled HTTP 测试，后者待依赖环境恢复。

完整 CLI 初跑发现 schema/public skill snapshot 未同步，已补 kind taxonomy、父级 failure codes、恢复分类与真实 parser 参数，1249 项通过。随后真实只读截图验收发现多帧采样复用 capture.png，触发 host 不覆盖产物约束；新增失败测试重现后改用每帧唯一私有文件，1250 项、117 suites 全量通过。真实 host settle 复测成功：3 个截图样本、1.919 秒，settled 且 businessVerified=false。

本机只读 host AX：`--max-nodes 2` 实际只访问/返回 2 节点并报告 max_nodes；完整 outline 49 个 alias，活 resolve @1 成功。指定既有 runtime 的新 ui-health 入口正常返回 pong，旧 SDK uiState=unknown、businessVerified=false。真实 host OCR 成功返回 20 个候选，candidateOnly=true、freshness=captured-on-request；默认短 capture deadline 曾 timeout，延长至20秒成功，不推断坐标输入正确。raw 输出/截图仅私有 gitignored 目录/临时目录，不发布内容。Web TypeScript/Vite build 通过，既有 bundle 大小 warning 保留。

本地 `verify.sh --local` 通过：SPM依赖边界、Debug隔离、macOS tests（59 runtime / 274 shared）、Release CLI build及smoke、Harmony和iOS runtime fixture smoke、真实iOS Simulator build、docs和diff检查。额外 `verify.sh --ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 收口复核。

## 最终门禁

- [x] Focused Swift tests 复跑，覆盖 alias、宽深/慢树、视觉动态/静态/unknown、OCR 坐标和 policy、health admission/timeout/熔断、workspace opt-in、scene metadata。
- [x] Android 完整 Gradle 52 项及 Debug APK 构建通过，JS 12 项通过；此前直接编译/依赖阻塞仅作为历史。
- [x] 完整 CLI tests（本次构建的 TRITON_CLI_PATH，--no-parallel）：1250 项通过；根包 macOS 全量 274 项通过。
- [x] `docs-linhay/scripts/verify.sh --local`、`check-docs.sh`、`git diff --check`。
- [x] UIKit 完整 runtime suite 115 项通过，四项既有失败已修复并增加覆盖；Android/Harmony 缺实时目标，未发送真实输入，真实 OCR raw-raster 未校准成输入坐标。
- [x] 主控写回 space 索引、overview 与每日 memory，最终仅报告实际通过和剩余风险。

## 用户授权限制收口

完整结果与失败诊断见[限制收口计划](./20261014-limitation-resolution.md)。Android 官方源恢复，沿用原始构建配置，完整 52 项与 Debug APK 成功；iOS 测试修复后实际 xcresult 115 passed / 0 failed / 0 skipped。alert routing 使用真实窗口、alert responder 与可命中的同坐标背景 cell 夹具；不将该 unit fixture 当作 UIKit presentation 集成验收。原始失败与基线对照保留为历史。
