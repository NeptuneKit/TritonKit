# 20260613 Web Triad QA

## 背景

本轮目标是让三个 subagent 分别承担 Web 端体验闭环里的不同角色：修改者、质疑者、法官。主控 agent 负责需求边界、集成、验证、文档与最终完成判断。

TritonKit Web 仍是 React / Vite mock 工程，不改变 CLI / HTTP 是业务控制事实入口的产品边界。本轮只围绕 Web 端体验、可测试性、三端目标切换与浏览器验收做收敛。

## 目标

- 用三角色 subagent 循环推进 Web 体验和测试。
- 修改者负责最小代码改动与测试补齐。
- 质疑者负责从 iOS / Android / Harmony 三端开发视角提出体验、边界和验证风险。
- 法官负责按验收标准裁决是否通过，并明确 remaining blockers。
- 主控 agent 集成所有结果，持续循环直到合格或出现明确 blocker。

## 范围

- `Web/` React / TypeScript / Vite mock 应用。
- 三端 target 切换、设备镜像、Inspector、Network evidence、Logs、host bridge 状态展示。
- 桌面浏览器体验验证，重点视口约 1200px 和较窄宽度。
- 自动化验证优先覆盖 `npm run test`、`npm run build`、`git diff --check`。
- 必要时使用浏览器自动化截图并归档到本 space。

## 不在本轮范围

- 不恢复 Wails 桌面壳。
- 不新增 Web 业务控制入口。
- 不绕过 Triton CLI 直接调用 `xcrun`、`adb`、`hdc`。
- 不引入远端 agent、设备云、多租户或真实代理控制台。
- 不把 Web mock 变成正式产品 UI，除非后续单独建立 space。

## BDD 场景

### 场景：修改者修复可体验问题

- Given Web mock 工程位于 `Web/`
- And 现有测试和构建可作为回归门禁
- When 修改者发现阻碍三端体验验证的问题
- Then 修改者以最小范围修改 `Web/src/` 或 `Web/dev/`
- And 同步补充或更新可执行测试
- And 不触碰无关产物、`node_modules`、`dist` 或用户未跟踪文件

### 场景：质疑者从三端视角审查

- Given 页面展示 iOS、Android、Harmony 三类 target
- When 质疑者检查首屏、目标切换、状态文案、网络证据和日志
- Then 必须列出会阻塞三端开发者使用的体验问题
- And 必须区分 Web mock 体验缺陷与 CLI / HTTP 契约缺口
- And 对不能由 Web 层解决的问题给出明确理由

### 场景：法官裁决是否通过

- Given 修改者提交修复结果
- And 质疑者给出风险清单
- When 法官按本 space 验收标准检查
- Then 只有自动化验证、浏览器验收和三端切换体验全部达标时才判定通过
- And 若未通过，必须输出下一轮修改者应处理的具体 blocker

### 场景：浏览器验收三端切换

- Given dev server 运行在 `127.0.0.1:34127`
- When 浏览器打开 `/`
- Then 页面首屏非空，title 与主界面可见
- And iOS、Android、Harmony 目标都可被选择
- And 目标切换后 App 标识、bundle / target、平台状态、网络事件和日志随选择变化
- And 浏览器 console 没有 error

### 场景：布局可扫读且无横向溢出

- Given 浏览器视口宽度约为 1200px
- When 用户查看 Device Hub mock
- Then 页面没有横向滚动
- And 顶部工具栏、左侧 target、中央 canvas、右侧 Inspector、底部 controls / logs 不互相遮挡
- And 长文案在容器内省略、换行或内部滚动，不撑破整体窗口

### 场景：host target 为空时显式说明 QA mock fallback

- Given `/web/host-targets` 请求成功
- And 返回的 `targets` 为空数组
- When 页面退回内置 iOS / Android / Harmony QA mock targets
- Then 页面必须明确提示“当前没有可用 host target，正在展示 QA mock fallback”
- And 提示不能伪装成真实 host target 已发现
- And 该状态必须有自动化测试或纯 helper 测试兜底

### 场景：挂载后的 App 真的出现 fallback notice

- Given `App` 在测试 DOM 环境中被真实挂载
- And `/web/host-targets` 返回 `ok=true` 且 `targets=[]`
- When 页面完成首次 host bridge 拉取
- Then 挂载后的 DOM 中必须出现 `QA mock fallback` 副标题与 fallback notice 文案
- And 该 smoke 不能只断言 pure helper 或 server-render markup
- And smoke 必须仍保持 readonly mock 边界，不引入业务控制语义

### 场景：host bridge 请求失败时挂载后的 App 也出现 fallback notice

- Given `App` 在测试 DOM 环境中被真实挂载
- And `/web/host-targets` 返回非 2xx 或抛出请求错误
- When 页面完成首次 host bridge 拉取失败
- Then 挂载后的 DOM 中必须出现 `QA mock fallback` 副标题与错误态 fallback notice 文案
- And 该 smoke 必须和成功但空 `targets` 的 mounted DOM smoke 保持同级覆盖
- And smoke 仍然只验证只读 host bridge 展示边界，不引入业务控制语义

### 场景：mounted DOM smoke 运行时不再产生 Vite WebSocket EPERM 噪音

- Given mounted DOM smoke 通过 Vite server + SSR 加载 `App`
- When `cd Web && npm test` 运行所有 Web smoke
- Then 测试输出不应再出现 `WebSocket server error: listen EPERM 0.0.0.0:24678`
- And 现有 11 条通过中的 mounted DOM / markup / readonly smoke 不能回归
- And 若仍需保留某种测试期 server 配置，必须保持最小化，不为消噪音引入更重的测试栈

### 场景：真实 dev browser 里的 request-failed fallback 也能成立

- Given Vite dev server 运行在 `127.0.0.1:34127`
- And 页面 URL 带上 `__tritonkit_mock_host_targets=request-failed`
- When 页面以真实浏览器布局重新加载 `/`
- Then 首屏必须显示 `QA mock fallback` 副标题与错误态 fallback notice
- And notice 明细必须保留可追踪的失败原因，不伪装成真实 host target 已发现
- And `1200 x 820` 与较窄桌面视口下都不能出现横向溢出
- And console 不得出现新的 error
- And 必须补一张对应错误态 fallback 的浏览器截图
- And bridge route 的只读 502 语义继续由 Node smoke 单独覆盖，不要求真实浏览器也发出失败网络请求

### 场景：dev browser 错误态入口不能为了触发 fallback 污染 console

- Given 浏览器验收仍需要一个可重复触发的 request-failed fallback 入口
- When 开发态页面以该入口进入错误态 fallback
- Then 页面仍需显示 `QA mock fallback` 与可追踪失败原因
- And 该入口不能额外制造浏览器 `console error`
- And 原有 mounted DOM / readonly route smoke 仍需保留，用来覆盖客户端错误态与 bridge 502 语义

### 场景：request-failed fallback 下三端切换仍然成立

- Given 浏览器打开 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed`
- And 页面已经显示 `QA mock fallback` 与错误态 fallback notice
- When 用户依次切换 iOS、Android、Harmony 三个 target
- Then 当前应用、bundle / target、network evidence 与 logs 仍需随 target 变化
- And 错误态 fallback notice 在切换后仍需保留，不得静默消失
- And 该场景至少要有一条自动化 smoke 或 mounted DOM 覆盖
- And 真实浏览器验收要明确记录 Android / Harmony 在错误态 fallback 下的可见 DTO 变化

### 场景：request-failed fallback 下往返切回 iOS 时 DTO 不会被污染

- Given 浏览器已经在 `?__tritonkit_mock_host_targets=request-failed` 错误态下完成 Android 与 Harmony 切换
- When 用户再切回 iOS `DXY iPhone 15`
- Then `QA mock fallback` notice 仍需保留
- And 当前应用、bundle、network evidence 与 logs 需要回到 iOS 对应文案
- And 至少要有一条自动化 smoke 覆盖 Android -> Harmony -> iOS 的往返切换
- And 真实浏览器验收要明确记录回到 iOS 后的 DTO 文案与视口结果

### 场景：视图树面板下仍能切换三端 target

- Given 浏览器已进入 `?__tritonkit_mock_host_targets=request-failed` 错误态 fallback
- And 左侧侧栏当前切到 `视图树`
- When 用户需要从 iOS 切到 Android 或 Harmony 再切回 iOS
- Then 视图树面板内仍需保留可见且可点击的 target 切换入口
- And 切换 target 后，视图树标题、树节点文案与当前应用 / bundle / network / logs 都要跟着变化
- And `QA mock fallback` notice 不得因为停留在 `视图树` 面板而消失
- And 至少要有一条 mounted DOM smoke 覆盖 `视图树` 面板里的 target 往返切换
- And 真实浏览器验收要明确记录 `视图树` 面板内 target 入口仍可见、可切换且无横向溢出

### 场景：搜索框必须真实过滤 target

- Given 左侧侧栏顶部存在 `搜索` 输入框
- When 用户输入 `Pixel`、`DevEco` 或 `DXY`
- Then `设备` 面板里的 target 列表必须按关键字过滤，而不是继续显示全部 target
- And 切换到 `视图树` 面板后，同一个搜索关键字也必须过滤 target chip，而不是继续显示全部 target
- And 清空搜索后，三端 target 需要完整恢复
- And 搜索过程不得破坏 `QA mock fallback` notice、当前选中 target 或已通过的三端 DTO 切换逻辑
- And 至少要有一条 mounted DOM smoke 覆盖 `设备` 与 `视图树` 两个面板下的搜索过滤行为
- And 真实浏览器验收要明确记录 `1200 x 820` 与较窄桌面视口下的过滤结果和无横向溢出

### 场景：搜索无结果时设备面板必须给出准确空态

- Given 左侧侧栏顶部存在 `搜索` 输入框
- And 当前 `设备` 面板原本有 iOS、Android、Harmony 三个 target
- When 用户输入一个不匹配任何 target 名称或 app 文案的关键字
- Then `设备` 面板不能显示“暂无运行中的仿真器”这类真实空设备文案
- And 必须显示“未找到匹配 target”，明确这是搜索过滤后的空结果
- And 切到 `视图树` 面板时，同一搜索关键字下的 target chip 空态文案也必须保持一致
- And 清空搜索后，两个面板都恢复三端 target
- And 至少要有一条 mounted DOM smoke 覆盖两个面板的搜索无结果与清空恢复
- And 真实浏览器验收要记录过滤为空时的设备面板、视图树面板、清空恢复和无横向溢出

### 场景：实时预览帧率必须可由用户调整

- Given Web 连接到本机 readonly host target
- And 设备画布右上角显示 `实时 1 fps`
- When 用户通过 `提高实时预览帧率` 或滑杆把预览刷新率调到 `15 fps`
- Then 右上角 live preview badge、滑杆值和右侧 `帧率` Metric 必须同步显示 `15`
- And live preview 刷新 loop 必须使用调整后的 fps 间隔，不再固定为 `900ms`
- And 帧率设置按 target 隔离，切到其他 target 后不污染对方，切回原 target 后保留原 target 的本地预览 fps
- And 该控制只影响 Web mock 预览刷新率，不新增 CLI / HTTP 业务控制命令，不改写 app / bundle / network / logs DTO
- And 真实浏览器验收要记录桌面与较窄视口下的调节结果、无横向溢出和 console 状态

### 场景：实时预览帧率调节条默认不应常驻

- Given 设备画布右上角存在 `实时 N fps` 状态胶囊
- When 用户只是观察设备画面
- Then 页面默认只显示状态胶囊，不显示滑杆和升/降帧按钮，避免遮挡画布
- When 用户点击状态胶囊
- Then 才展开 `刷新率` 滑杆和升/降帧按钮
- And 展开后仍能把 fps 调到目标值，并保持 badge、滑杆和右侧 `帧率` Metric 同步

### 场景：Web host input 路由必须保持只读 405 边界

- Given Web mock 仍不是业务控制入口
- And host input 的真实执行只能通过 CLI / HTTP runtime 契约完成
- When 页面或测试向 `/web/host-input` 发起 POST
- Then dev bridge 必须固定返回 `405` 与 `web_host_input_readonly`
- And 前端点击 / 拖动只能记录本地只读提示，不能调用 host input POST
- And 代码中不能重新引入 `dispatchHostInput`、`HostInputResponse` 或 `triton serve` 转发链路

## 三角色合格标准

### 修改者

- `npm run test` 通过。
- `npm run build` 通过。
- 变更文件路径清晰，优先限定在 `Web/` 与本 space 文档。
- 若新增 UI 状态，必须有可观察的 DOM 文案或测试入口。
- 不引入 Web first 的业务控制语义。

### 质疑者

- 至少覆盖 iOS、Android、Harmony 三端视角。
- 至少检查一个桌面窄宽度布局风险。
- 至少检查一次目标切换后的 DTO 值是否真实变化。
- 明确区分阻塞项、非阻塞建议和已通过项。

### 法官

- 复核修改者测试结果。
- 复核质疑者阻塞项是否被解决或被合理降级。
- 复核浏览器验收截图或机器可读证据。
- 只有所有阻塞项关闭时才判定通过。

## 循环规则

1. 主控启动三个 subagent：修改者、质疑者、法官。
2. 修改者先做一轮最小修复与测试。
3. 质疑者审查修改结果，输出阻塞项。
4. 法官按验收标准裁决。
5. 若法官未通过，主控把 blocker 回传给修改者进入下一轮。
6. 若连续三轮卡在同一环境 blocker，主控记录 blocker 并停止。
7. 通过后主控补齐验证记录、截图、memory 和最终汇报。

## 验收标准

- `npm run test` 通过。
- `npm run build` 通过。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 通过。
- 浏览器打开 `http://127.0.0.1:34127/` 后首屏非空。
- 1200px 左右桌面视口无横向溢出。
- 目标切换会更新三端可见 DTO 值。
- console 没有 error。
- 截图保存到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/`。

## 实现记录

- 2026-06-13 修改者：调整 `Web/src/App.tsx` 的 fallback target 列表，本机 host bridge 不可用时展示全部内置 iOS / Android / Harmony mock targets，确保纯 mock 状态下也能验证三端目标切换与可见状态变化。
- 2026-06-13 修改者：抽出 `Web/dev/iosSimulatorBridge.mjs` 的 host captures 聚合纯函数 `mapTritonHostCapturesToWebTargets`，让 `/web/host-targets` 与测试复用同一条 iOS / Android / Harmony target mapping 路径。
- 2026-06-13 修改者：在 `Web/dev/iosSimulatorBridge.test.mjs` 增加三端 host captures 合并测试，验证 Web 可切换 target 同时包含 iOS Simulator、Android Emulator、Harmony Emulator，并保留命令来源与 app / bundle 可观察字段。
- 2026-06-12 主控：回应质疑者阻塞项，调整 `Web/src/App.tsx` 的页面 target 列表为“真实 host target 优先，缺失平台由内置 QA mock target 补齐”，避免本机当前只有 iOS Simulator 时三端验收被环境状态阻塞。
- 2026-06-12 主控：调整 `Web/src/data/iosSimulatorClient.ts` 的未知 app / bundle fallback，保持 `前台 App 未暴露` 语义，但追加设备名与 `Target <selector>`，让同平台 host target 切换时 App tile、target、network evidence 与 logs 都有可见差异。
- 2026-06-12 修改者 subagent：清理 Web mock 只读边界 residual risk，移除 `sendHostInput`、共享 host input response 类型、dev bridge 中残留的 host input 执行链路和 `triton serve` 启动 helper；保留 `/web/host-input` 只读 405 route，并新增 middleware 测试固定 `web_host_input_readonly`。
- 2026-06-13 修改者 subagent 第二轮：新增 `Web/src/data/hostBridgePresentation.ts` 纯 helper，显式区分“加载中 / host bridge 请求失败 / host bridge 成功但 targets 为空”三种页面语义。
- 2026-06-13 修改者 subagent 第二轮：在 `Web/src/App.tsx` 接入 host bridge presentation helper；当 `targets=[]` 时 toolbar 副标题切为 `QA mock fallback`，并渲染 `HostBridgeNotice` 提示条，明确说明“当前没有可用 host target，正在展示 QA mock fallback”。
- 2026-06-13 修改者 subagent 第二轮：在 `Web/src/styles.css` 增加 `bridge-notice` warning / error 样式；在 `Web/dev/iosSimulatorBridge.test.mjs` 补两条自动化测试，覆盖“请求成功但空 targets”与“请求失败”两条 fallback 路径。
- 2026-06-13 修改者 subagent 第三轮：新增 `Web/src/components/HostBridgeNotice.ts` 无 JSX 共享组件，让真实页面渲染与 Node smoke 复用同一份 notice markup。
- 2026-06-13 修改者 subagent 第三轮：在 `Web/src/App.tsx` 改为直接复用共享 `HostBridgeNotice` 组件，避免 fallback notice 的真实 UI 与测试 renderer 分叉。
- 2026-06-13 修改者 subagent 第三轮：在 `Web/dev/iosSimulatorBridge.test.mjs` 增加 `react-dom/server` smoke，直接断言 notice 的 `class`、`role`、`aria-label`、`strong` 和 `span` 文案被渲染出来，不再只检查 pure helper 返回对象。
- 2026-06-13 修改者 subagent 第四轮：新增 `Web/dev/appFallbackDom.test.mjs`，用 `happy-dom` + Vite `ssrLoadModule("/src/App.tsx")` 真挂载 `App`，stub `/web/host-targets => ok=true, targets=[]`，断言挂载后的 DOM 里出现 `QA mock fallback` 副标题与 fallback notice 文案。
- 2026-06-13 修改者 subagent 第四轮：在 `Web/package.json` / `Web/package-lock.json` 只增加最小测试依赖 `happy-dom`，没有引入更重的 testing-library 栈。
- 2026-06-13 修改者 subagent 第五轮：在 `Web/dev/appFallbackDom.test.mjs` 增加 mounted DOM 错误分支 smoke，真实挂载 `App`，stub `/web/host-targets` 返回 `502`，断言 DOM 中出现 `QA mock fallback` 副标题、错误态 notice 标题与 `Host targets request failed: 502` 明细。
- 2026-06-13 修改者 subagent 第六轮：在 `Web/dev/appFallbackDom.test.mjs` 的 Vite middleware server 配置中显式加上 `server.ws: false`，并保留 `hmr: false`，只收敛 mounted DOM smoke 期间的测试环境噪音，不触碰运行时代码或 readonly 语义。
- 2026-06-13 修改者 subagent 第七轮：在 `Web/src/data/iosSimulatorClient.ts` 引入 dev-only URL 参数入口 `__tritonkit_mock_host_targets=request-failed`；在 `Web/dev/iosSimulatorBridge.mjs` 增加对应的只读 502 route smoke，在 `Web/dev/iosSimulatorBridge.test.mjs` 固定其 `web_host_targets_forced_failure` 语义。
- 2026-06-13 修改者 subagent 第七轮：为支持 `import.meta.env.DEV` 读取补上 `Web/src/vite-env.d.ts`；在 `Web/dev/appFallbackDom.test.mjs` 让 mounted DOM 错误分支显式跑在该 URL 参数场景里，确保浏览器和测试夹具都沿用同一个 dev-only 入口。
- 2026-06-13 主控第七轮：首次真实浏览器验证发现，直接让 bridge route 返回 502 虽然能展示正确 fallback notice，但 Chrome console 会多出两条 `Failed to load resource: 502`，与 space 的“console 没有 error”验收标准冲突，因此把它升级为下一轮 blocker，而不是把第七轮直接判过。
- 2026-06-13 主控第八轮：把 `Web/src/data/iosSimulatorClient.ts` 的 dev-only `request-failed` 入口改为客户端短路，直接抛出 `Host targets request failed: 502`，让真实浏览器仍进入同一错误态 fallback，但不再额外发起失败网络请求污染 console。
- 2026-06-13 主控第八轮：保留 `Web/dev/iosSimulatorBridge.mjs` 与 `Web/dev/iosSimulatorBridge.test.mjs` 里的只读 502 route smoke，继续覆盖 bridge 语义；同时把 `Web/dev/appFallbackDom.test.mjs` 的错误态 mounted DOM smoke 改为断言 dev-only URL 参数场景下不会调用 `fetch("/web/host-targets")`，分清“浏览器错误态入口”和“bridge 502 route”两层责任。
- 2026-06-13 修改者 subagent 第九轮：继续只改 `Web/dev/appFallbackDom.test.mjs`，新增 `keeps request-failed fallback notice while switching Android and Harmony targets in mounted DOM`，在 dev-only `request-failed` 错误态下真实挂载 `App`，点击 Android / Harmony target，断言当前应用、bundle、network evidence、logs 都随切换变化，同时错误态 fallback notice 始终保留。
- 2026-06-13 修改者 subagent 第十轮：继续只改 `Web/dev/appFallbackDom.test.mjs`，新增 `restores iOS DTO after round-tripping Android and Harmony targets in request-failed fallback`，在同一个 dev-only `request-failed` 错误态会话里按 iOS -> Android -> Harmony -> iOS 往返点击，断言 `QA mock fallback` notice 持续保留，且当前应用、bundle、network evidence、logs 最终回到 iOS 对应文案。
- 2026-06-13 主控第十一轮：在 `Web/src/App.tsx` 的 `ViewTreePanel` 内补回 target 切换入口，把 `selected / targets / onSelect` 从 `TargetNavigator` 传进视图树面板，新增 `视图树 target 切换` 区块，确保停留在 `视图树` 时也能直接切 iOS / Android / Harmony。
- 2026-06-13 主控第十一轮：在 `Web/src/styles.css` 为视图树面板新增 `view-tree-target-list` 与 `view-tree-target-chip` 样式，保持三端 chip 在标准桌面与较窄桌面视口下都可见、可点且不引入横向溢出。
- 2026-06-13 主控第十一轮：在 `Web/dev/appFallbackDom.test.mjs` 新增 `keeps target switching available inside view-tree panel during request-failed fallback round-trip`，真实挂载 `App` 后先切到 `视图树`，再在树面板内完成 `iOS -> Android -> Harmony -> iOS` 往返，直接断言 target 入口、树标题/节点、app、bundle、network、logs 与错误态 notice 的联动。
- 2026-06-13 修改者 subagent 第十一轮：在 `Web/src/App.tsx` 的 `ViewTreePanel` 内补回可见 target 切换入口，保留 `视图树` 面板本身，同时让 iOS / Android / Harmony 都能在该面板里直接点击切换；`Web/src/styles.css` 只补最小样式承载这块入口。
- 2026-06-13 修改者 subagent 第十一轮：在 `Web/dev/appFallbackDom.test.mjs` 新增 `keeps target switching available inside view-tree panel during request-failed fallback round-trip`，直接覆盖 `视图树` 面板里的 `iOS -> Android -> Harmony -> iOS` 往返切换，断言视图树标题 / 节点、当前应用、bundle、network evidence、logs 会同步变化，且 `QA mock fallback` notice 不消失。
- 2026-06-13 修改者 subagent 第十二轮：在 `Web/src/App.tsx` 给左侧顶部 `搜索` 输入框补上真实 state / filter 接线，新增 `targetSearch` 与 `filterTargetsBySearch`，让 `设备` 面板列表和 `视图树` 面板 target chip 都按 target 名称或 app 文案过滤；搜索只收敛左侧可选入口，不偷偷改当前选中 target，也不碰 `QA mock fallback` notice 或现有 DTO 逻辑。
- 2026-06-13 修改者 subagent 第十二轮：继续只在 `Web/dev/appFallbackDom.test.mjs` 补 mounted DOM smoke `filters targets through the shared search box across devices and view-tree panels`，覆盖 `设备` 与 `视图树` 两个面板下的搜索过滤、app 文案过滤、清空恢复三端，以及搜索期间已有 target 切换 / DTO 恢复逻辑仍成立。
- 2026-06-13 主控第十二轮：复核后明确保留“搜索只过滤左侧入口，不自动切换当前选中 target”的交互约束，并把它写回 space 文档，避免后续把过滤行为误做成隐式 target 切换。
- 2026-06-15 主控第十三轮：把搜索无结果空态从“可过滤”继续收敛到“文案不误导”。`Web/src/App.tsx` 的 `DeviceListPanel` 现在接收 `isSearching`，搜索过滤为空时显示 `未找到匹配 target`，非搜索态无 target 时才保留 `暂无运行中的仿真器`。
- 2026-06-15 主控第十三轮：在 `Web/dev/appFallbackDom.test.mjs` 新增 mounted DOM smoke `shows search empty state across devices and view-tree panels without implying no running targets`，覆盖无匹配关键词下 `设备` 与 `视图树` 空态一致、旧无设备文案不出现、清空后恢复三端 target，且 `QA mock fallback` 与当前 iOS DTO 不被搜索污染。
- 2026-06-15 主控第十四轮：把 live preview badge 从只读 `实时 1 fps` 扩展为可调本地预览刷新率。`Web/src/App.tsx` 新增 per-target `previewFpsById`，badge、滑杆和右侧 `帧率` Metric 同源读取当前 target 的 fps。
- 2026-06-15 主控第十四轮：live preview 刷新 loop 改为 `fpsToRefreshIntervalMs(selectedPreviewFps)`，根据用户调整后的 fps 重新安排下一帧，不再固定 `900ms`；新增 `1..60` fps clamp，避免异常输入。
- 2026-06-15 主控第十四轮：在 `Web/src/styles.css` 为右上角 live preview 控件增加滑杆和升/降帧按钮样式；按钮只改本地预览刷新率，不新增 host action。
- 2026-06-15 主控第十四轮：在 `Web/dev/appFallbackDom.test.mjs` 新增 mounted DOM smoke `lets users tune live preview fps without changing selected host target state`，覆盖从 `1 fps` 调到 `15 fps` 后 badge / slider / Metric 同步，且 app / bundle DTO 不被污染。
- 2026-06-15 主控第十五轮：回应浏览器反馈“拖动条为什么不是点击才显示”，把 live preview fps 控件改为默认只显示 `实时 N fps` 胶囊，点击胶囊后才展开滑杆和升/降帧按钮；点外部或切换 target 会收起。
- 2026-06-15 主控第十五轮：更新 mounted DOM smoke，先断言默认状态不存在 `调整实时预览帧率` input，再点击 `展开实时预览帧率控制` 后调到 `15 fps`，继续断言 badge / slider / Metric 同步。
- 2026-06-17 主控第十六轮：回应质疑者 / 法官对只读边界的 blocker，删除 `Web/src/App.tsx` 对 `dispatchHostInput` 的调用，点击 / 拖动只写入本地只读 warning 与 interaction log，不再发起 `/web/host-input`。
- 2026-06-17 主控第十六轮：把 `Web/dev/iosSimulatorBridge.mjs` 的 `/web/host-input` 固定为 `405 web_host_input_readonly`，移除 `triton serve` 转发 helper、runtime server 探测、host input body 解析与 payload normalize 链路。
- 2026-06-17 主控第十六轮：删除 `Web/src/data/iosSimulatorClient.ts` 中的 `dispatchHostInput` 客户端方法，并移除 `Web/src/types.ts` 中的 `HostInputResponse` 类型，避免 Web mock 重新暴露业务控制语义。

## 验证记录

- 2026-06-13 修改者：先运行 `npm run test`，原有 4 项通过；补测试后确认红灯为缺少 `mapTritonHostCapturesToWebTargets` 导出；实现后 `npm run test` 通过，5 项通过。
- 2026-06-13 修改者：在 `Web/` 下运行 `npm run build` 通过，`tsc --noEmit && vite build` 成功。
- 2026-06-13 修改者：启动 `npm run dev` 后用浏览器在 1200 x 820 视口验证，正常 host targets 模式 `documentElement.scrollWidth = 1200`、无横向溢出、console error 为 0；临时让 `/web/host-targets` 返回 502 触发 mock fallback 后，iOS / Android / Harmony 三端切换均更新当前应用、bundle、网络证据与日志文案。
- 2026-06-13 修改者：运行 `git diff --check -- Web/src/App.tsx Web/dev/iosSimulatorBridge.mjs Web/dev/iosSimulatorBridge.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；运行 `docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-12 主控复核：`npm test` 通过，5 项 node test 全绿；`npm run build` 通过，`tsc --noEmit && vite build` 成功；`git diff --check` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-12 主控复核：复用已运行的 `127.0.0.1:34127` Vite dev server；真实 host bridge 返回 2 个 booted iOS Simulator target，页面展示只读 host discovery、`前台 App 未暴露` 与 `Bundle ID 未暴露`，console error 为 0，`1200 x 820` 下 `scrollWidth = clientWidth = 1200`。
- 2026-06-12 主控复核：通过浏览器 init script 强制 `/web/host-targets` 返回 502，验证 mock fallback 同时展示 `DXY iPhone 15`、`Pixel API 35`、`DevEco Local`；切换 Android 后 App / bundle、network evidence、logs 更新为 `Overloaded`、`overloaded.cn.debug`、`/api/catalog`、`ADB target ready: emulator-5556`；切换 Harmony 后更新为 `Triton Smoke`、`com.tritonkit.demo`、`/capabilities`、`HDC target discovered from plain list fallback`。
- 2026-06-12 主控复核：`960 x 820` 窄桌面视口下 `scrollWidth = clientWidth = 960`，无横向溢出，console error 为 0；截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-triad-switching-after-01.png`。
- 2026-06-12 主控复核：质疑者指出真实 host 模式只有 iOS target、同平台 app tile fallback 静态；修复后重新运行 `npm test` 通过 5 项、`npm run build` 通过。
- 2026-06-12 主控复核：真实 host 模式下页面同时展示 2 个 iOS Simulator host target、`Pixel API 35` Android QA fallback、`DevEco Local` Harmony QA fallback；切换 iPhone 17 后 App tile 更新为 `前台 App 未暴露 · iPhone 17` 与 `Target 60667794-96F8-40E6-8664-85538EC4663E`，network evidence 与 logs 更新为该 UDID。
- 2026-06-12 主控复核：真实 host + missing-platform fallback 混合模式下切换 Android 显示 `Overloaded`、`overloaded.cn.debug`、`/api/catalog`、`ADB target ready: emulator-5556`；切换 Harmony 显示 `Triton Smoke`、`com.tritonkit.demo`、`/capabilities`、`HDC target discovered from plain list fallback`；`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，console error 为 0。
- 2026-06-12 主控复核：更新截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-triad-switching-after-02.png`。
- 2026-06-12 修改者 subagent：运行 `cd Web && npm test` 通过 5 项；运行 `cd Web && npm run build` 通过；运行 `git diff --check` 通过。
- 2026-06-12 主控复核：重新运行 `npm test` 通过，5 项包含 `keeps Web host input POST route readonly with 405 semantics`；`npm run build` 通过；`git diff --check` 通过；`docs-linhay/scripts/check-docs.sh` 通过；搜索确认 `sendHostInput`、`runHostInput`、`HostInputResponse`、`HostInputRequest`、`readJSONBody`、`buildTapArgs`、`buildSwipeArgs`、`ensureTritonWebServer`、`normalizeIosRuntimeInput` 等 Web input 执行残留已不存在。
- 2026-06-12 主控复核：在最新代码下刷新 `127.0.0.1:34127`，页面展示 2 个 iOS host target、`Pixel API 35` Android fallback、`DevEco Local` Harmony fallback；切换 Android / Harmony 后 app、bundle、network evidence、logs 均更新；`1200 x 820` 与 `960 x 820` 下 `scrollWidth = clientWidth`，console error 为 0。
- 2026-06-12 主控复核：最终截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-triad-switching-after-03.png`。
- 2026-06-13 主控复核：重新启动 `Web` dev server 后，用浏览器重新打开 `http://127.0.0.1:34127/`；in-app Browser 因本地 URL policy 拒绝访问 `127.0.0.1`，改用既有 Chrome DevTools 验收面板继续验证，不绕过浏览器策略。
- 2026-06-13 主控复核：`1200 x 820` 下 `documentElement.scrollWidth = clientWidth = 1200`，console 仅有 React DevTools info，无 error；默认 iOS mock target 可见。
- 2026-06-13 主控复核：切换 Android `Pixel API 35` 后，页面同步显示 `Overloaded`、`overloaded.cn.debug`、`/api/catalog`、`ADB target ready: emulator-5556`。
- 2026-06-13 主控复核：切换 Harmony `DevEco Local` 后，页面同步显示 `Triton Smoke`、`com.tritonkit.demo`、`/capabilities`、`HDC target discovered from plain list fallback`；`960 x 820` 下 `scrollWidth = clientWidth = 960`，无横向溢出。
- 2026-06-13 主控复核：最新截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-triad-switching-after-v04.png`。
- 2026-06-13 修改者 subagent 第二轮：`cd Web && npm test` 通过 7 项；新增 `surfaces QA mock fallback when host bridge succeeds but returns no targets` 与 `surfaces QA mock fallback when host bridge request fails` 两项测试。
- 2026-06-13 修改者 subagent 第二轮：`cd Web && npm run build` 通过，`tsc --noEmit && vite build` 成功。
- 2026-06-13 主控复核第二轮：通过浏览器 reload init script 强制 `/web/host-targets` 返回 `ok=true` 且 `targets=[]`；`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，页面显示 `当前没有可用 host target，正在展示 QA mock fallback` 与 toolbar 副标题 `QA mock fallback`，console 仅有 React DevTools info，无 error。
- 2026-06-13 主控复核第二轮：同一强制空数组场景下，`960 x 820` 视口 `scrollWidth = clientWidth = 960`，提示条 detail 不触发横向溢出。
- 2026-06-13 主控复核第二轮：恢复真实 host 场景后，Android 仍显示 `Overloaded`、`overloaded.cn.debug`、`/api/catalog`、`ADB target ready: emulator-5556`；Harmony 仍显示 `Triton Smoke`、`com.tritonkit.demo`、`/capabilities`、`HDC target discovered from plain list fallback`，证明第二轮提示改动未破坏既有三端切换。
- 2026-06-13 主控复核第二轮：`git diff --check` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第二轮：新增截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-triad-empty-host-fallback-after-v05.png`。
- 2026-06-13 修改者 subagent 第三轮：`cd Web && npm test` 通过 9 项，新增 `server-renders warning fallback notice markup for readonly host bridge` 与 `server-renders error fallback notice markup when host bridge request fails` 两条 server-render smoke。
- 2026-06-13 修改者 subagent 第三轮：`cd Web && npm run build` 通过；`git diff --check -- Web/src Web/dev/iosSimulatorBridge.test.mjs` 通过。
- 2026-06-13 主控复核第三轮：再次强制 `/web/host-targets => ok=true, targets=[]`，页面仍显示 `QA mock fallback` 副标题与完整 notice 文案；当前 `960 x 820` 下 `scrollWidth = clientWidth = 960`，说明共享组件接线后没有引入回归。
- 2026-06-13 主控复核第三轮补证：补拍第三轮专属浏览器截图 `20260613-web-triad-empty-host-fallback-after-v06.png`；截图对应 `960 x 820` 强制空 `targets` fallback 场景，页面显示共享 `HostBridgeNotice` 组件渲染后的 `QA mock fallback` 副标题与 notice 标题。
- 2026-06-13 修改者 subagent 第四轮：`cd Web && npm test` 通过 10 项；新增 `mounts QA mock fallback notice in DOM when readonly host bridge returns no targets`，把 fallback 覆盖推进到 mounted DOM 层。
- 2026-06-13 修改者 subagent 第四轮：`cd Web && npm run build` 通过；`git diff --check -- Web` 通过。
- 2026-06-13 主控复核第四轮：在 mounted DOM smoke 合入后再次运行 `docs-linhay/scripts/check-docs.sh`，返回 `docs-linhay structure ok`；第四轮 docs / screenshots / memory 写回后结构校验仍通过。
- 2026-06-13 修改者 subagent 第五轮：`cd Web && npm test` 通过 11 项；新增 `mounts QA mock fallback error notice in DOM when host bridge request fails`，让请求失败分支和空 `targets` 分支拥有同级 mounted DOM 覆盖。
- 2026-06-13 修改者 subagent 第五轮：`cd Web && npm run build` 通过；`git diff --check -- Web` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第五轮：`npm test` 期间会打印一条 Vite `WebSocket server error: listen EPERM 0.0.0.0:24678` 告警，但 11 项测试全部通过，构建与文档门禁也都通过；暂记为新的非阻塞风险，不影响第五轮 mounted DOM 失败分支 smoke 生效。
- 2026-06-13 修改者 subagent 第六轮：`cd Web && npm test` 通过 11 项，且测试输出不再出现 `WebSocket server error: listen EPERM 0.0.0.0:24678`。
- 2026-06-13 修改者 subagent 第六轮：`cd Web && npm run build` 通过；`git diff --check -- Web` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第六轮：确认 mounted DOM success-empty / request-failed 双路径、server-render markup smoke、readonly 405 route 都仍然通过，说明关闭测试期 WS 通道没有打坏现有 11 条绿测。
- 2026-06-13 修改者 subagent 第七轮：`cd Web && npm test` 通过 12 项；新增 `/web/host-targets?__tritonkit_mock_host_targets=request-failed` 只读 502 smoke，并让 mounted DOM 错误分支显式跑在同一个 dev URL 参数场景。
- 2026-06-13 修改者 subagent 第七轮：`cd Web && npm run build` 通过；`git diff --check -- Web docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第七轮：真实浏览器打开 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 后，页面确实显示 `QA mock fallback`、`Host bridge 请求失败，正在展示 QA mock fallback` 与 `Host targets request failed: 502`；但当时网络面板仍出现两条 `/web/host-targets?...request-failed [502]`，console 也跟着出现两条 `Failed to load resource: the server responded with a status of 502 (Bad Gateway)`，因此本轮按 blocker 处理，不宣称通过。
- 2026-06-13 主控复核第八轮：再次运行 `cd Web && npm test`，12 项全绿；再次运行 `cd Web && npm run build` 通过；`git diff --check -- Web docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第八轮：真实浏览器打开 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 后，`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，页面仍显示 `QA mock fallback`、错误态 notice 标题与 `Host targets request failed: 502` 明细，console 只剩 React DevTools info，无新的 error。
- 2026-06-13 主控复核第八轮：把浏览器缩到 `960 x 820` 后，`scrollWidth = clientWidth = 960`，错误态 fallback 文案仍完整可见，没有横向溢出。
- 2026-06-13 主控复核第八轮：同一浏览器 reload 后，network 面板不再出现 `/web/host-targets?...request-failed` 的失败请求，只剩页面资源 `200`；说明第八轮已经把“可重复触发错误态 fallback”与“console clean”同时成立。
- 2026-06-13 主控复核第八轮：最新错误态浏览器截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-request-failed-fallback-after-v07.png`。
- 2026-06-13 修改者 subagent 第九轮：`cd Web && npm test` 通过 13 项；新增 mounted DOM smoke 在 `?__tritonkit_mock_host_targets=request-failed` 下切换 Android `Pixel API 35` 与 Harmony `DevEco Local`，确认 `Overloaded` / `overloaded.cn.debug` / `/api/catalog` / `ADB target ready: emulator-5556` 和 `Triton Smoke` / `com.tritonkit.demo` / `/capabilities` / `HDC target discovered from plain list fallback` 都会出现，且 `QA mock fallback` notice 不消失。
- 2026-06-13 修改者 subagent 第九轮：`cd Web && npm run build` 通过；`git diff --check -- Web/dev/appFallbackDom.test.mjs` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第九轮：在同一个 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 浏览器会话里切到 Android `Pixel API 35` 后，`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，页面仍显示 `QA mock fallback`、`Host bridge 请求失败，正在展示 QA mock fallback` 与 `Host targets request failed: 502`；同时当前应用切为 `Overloaded`、bundle 切为 `overloaded.cn.debug`，network evidence 显示 `/api/catalog`，logs 显示 `ADB target ready: emulator-5556`。
- 2026-06-13 主控复核第九轮：继续在同一个错误态会话里切到 Harmony `DevEco Local` 后，`960 x 820` 下 `scrollWidth = clientWidth = 960`，错误态 notice 仍保留；当前应用切为 `Triton Smoke`、bundle 切为 `com.tritonkit.demo`，network evidence 显示 `/capabilities`，logs 显示 `HDC target discovered from plain list fallback`。
- 2026-06-13 主控复核第九轮：Android 与 Harmony 切换后的浏览器 console 仍只有 React DevTools info，没有新的 error；对应窄桌面错误态切换截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-request-failed-switching-after-v08.png`。
- 2026-06-13 修改者 subagent 第十轮：`cd Web && npm test` 通过 14 项；新增 mounted DOM smoke 在 `?__tritonkit_mock_host_targets=request-failed` 下从 iOS 切到 Android、Harmony 再回 `DXY iPhone 15`，确认 `丁香园`、`cn.dxy.iDxyer`、`/v1/home/feed` 与 `Selected host iOS target and paired embedded runtime` 会恢复，且错误态 fallback notice 不消失。
- 2026-06-13 修改者 subagent 第十轮：`cd Web && npm run build` 通过；`git diff --check -- Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第十轮：在同一个 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 浏览器会话里，按 `Android -> Harmony -> iOS` 往返切回 `DXY iPhone 15`；`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，toolbar 副标题仍是 `QA mock fallback`，错误态 notice 仍显示 `Host bridge 请求失败，正在展示 QA mock fallback` 与 `Host targets request failed: 502`。
- 2026-06-13 主控复核第十轮：切回 iOS 后页面 DTO 明确回正，当前应用恢复为 `丁香园`，bundle 恢复为 `cn.dxy.iDxyer`，network evidence 再次显示 `/v1/home/feed`、`/v1/search/query` 与 `/assets/config.json`，logs 恢复为 `Selected host iOS target and paired embedded runtime` 与 `Fetched framebuffer through simctl in 42 ms`，且不再残留 Android / Harmony 的 `ADB target ready: emulator-5556` 或 `HDC target discovered from plain list fallback`。
- 2026-06-13 主控复核第十轮：同一错误态往返会话缩到 `960 x 820` 后，`scrollWidth = clientWidth = 960`，当前 target 仍是 `DXY iPhone 15`，当前应用仍为 `丁香园`，bundle 仍为 `cn.dxy.iDxyer`；浏览器 console 全程只有 React DevTools info，没有新的 error。第十轮专属截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-request-failed-roundtrip-ios-after-v09.png`。
- 2026-06-13 主控复核第十一轮：`cd Web && npm test` 通过 15 项，新增 mounted DOM smoke `keeps target switching available inside view-tree panel during request-failed fallback round-trip`；`cd Web && npm run build` 通过；`git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md docs-linhay/memory/2026-06-13.md` 通过。
- 2026-06-13 主控复核第十一轮：真实浏览器在同一个 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 会话里切到左侧 `视图树` 面板后，`1200 x 820` 下 `scrollWidth = clientWidth = 1200`，面板内可见 3 个 target chip：`DXY iPhone 15`、`Pixel API 35`、`DevEco Local`；toolbar 副标题仍是 `QA mock fallback`，错误态 notice 仍显示 `Host bridge 请求失败，正在展示 QA mock fallback` 与 `Host targets request failed: 502`。
- 2026-06-13 主控复核第十一轮：在 `视图树` 面板内切到 Android `Pixel API 35` 后，树标题切为 `Overloaded`，树节点文案切为 `DecorView / AndroidComposeView / settingsList`；同时当前应用切为 `Overloaded`、bundle 切为 `overloaded.cn.debug`，network evidence 切为 `/api/catalog`，logs 切为 `ADB target ready: emulator-5556`。
- 2026-06-13 主控复核第十一轮：继续在 `视图树` 面板内切到 Harmony `DevEco Local` 后，树标题切为 `Triton Smoke`，树节点文案切为 `UIAbilityWindow / Column / settingsContent`；同时当前应用切为 `Triton Smoke`、bundle 切为 `com.tritonkit.demo`，network evidence 切为 `/capabilities`，logs 切为 `HDC target discovered from plain list fallback`。
- 2026-06-13 主控复核第十一轮：再切回 iOS `DXY iPhone 15` 后，树标题回到 `丁香园`，树节点文案回到 `UIWindowScene / UIStackView / questionList`；当前应用回到 `丁香园`、bundle 回到 `cn.dxy.iDxyer`，network evidence 回到 `/v1/home/feed`、`/v1/search/query`、`/assets/config.json`，logs 回到 `Selected host iOS target and paired embedded runtime` 与 `Fetched framebuffer through simctl in 42 ms`，错误态 notice 全程未消失。
- 2026-06-13 主控复核第十一轮：同一 `视图树` 错误态会话缩到 `960 x 820` 后，`scrollWidth = clientWidth = 960`，3 个 target chip 仍可见，当前 active tab 仍为 `视图树`，树标题仍为 `丁香园`；浏览器 console 仅有 Vite debug 与 React DevTools info，没有新的 error。第十一轮专属截图已归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260613/20260613-web-request-failed-view-tree-switching-after-v10.png`。
- 2026-06-13 修改者 subagent 第十一轮：`cd Web && npm test` 通过 15 项；新增 mounted DOM smoke 在 `?__tritonkit_mock_host_targets=request-failed` 下先切到 `视图树`，再通过面板内 target 入口按 `iOS -> Android -> Harmony -> iOS` 往返点击，确认 `UIStackView / questionList`、`AndroidComposeView / settingsList`、`Column / settingsContent` 会随 target 改变，同时 app、bundle、network evidence、logs 与 `QA mock fallback` notice 保持同步。
- 2026-06-13 修改者 subagent 第十一轮：`cd Web && npm run build` 通过；`git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 修改者 subagent 第十二轮：`cd Web && npm test` 通过 16 项；新增 mounted DOM smoke 在 `?__tritonkit_mock_host_targets=request-failed` 下先用 `Overloaded` 过滤 `设备` 面板，确认只剩 `Pixel API 35` 且当前选中 iOS 未被搜索偷改；随后切到 `视图树` 用同一搜索框改搜 `DXY`，确认 target chip 只剩 `DXY iPhone 15`、当前选中 Android 仍保留，点击后 app / bundle / network evidence / logs 恢复到 iOS；最后清空搜索，`设备` 与 `视图树` 再次恢复完整三端 target。
- 2026-06-13 修改者 subagent 第十二轮：`cd Web && npm run build` 通过；`git diff --check -- Web/src/App.tsx Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md` 通过；`docs-linhay/scripts/check-docs.sh` 通过。
- 2026-06-13 主控复核第十二轮：真实浏览器在 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed` 下补完搜索验收。`1200 x 820` 视口先在 `设备` 面板输入 `Pixel`，列表只剩 `Pixel API 35`；切到 `视图树` 后输入 `DevEco`，target chip 只剩 `DevEco Local`；再输入 `DXY`，chip 只剩 `DXY iPhone 15`；清空搜索后，`视图树` 与 `设备` 两个面板都恢复 `DXY iPhone 15 / Pixel API 35 / DevEco Local` 三个 target。
- 2026-06-13 主控复核第十二轮：较窄桌面 `960 x 820` 下再次验证 `Pixel` 过滤与清空恢复，过滤时设备列表只剩 `Pixel API 35`，清空后恢复三端 target，且 `scrollWidth = width = 960`，没有横向溢出。
- 2026-06-13 主控复核第十二轮：搜索过程中当前选中 target 不会被隐式改写，这一行为与 mounted DOM smoke 一致；搜索只负责过滤左侧入口，target DTO 切换仍由显式点击决定。第十二轮浏览器截图沿用过滤态 `20260613-web-request-failed-search-filtered-after-v11.png`，恢复态为 `20260613-web-request-failed-search-restored-after-v12.png`。
- 2026-06-15 主控复核第十三轮：先补 mounted DOM smoke 后确认红灯成立，旧实现会在新 smoke 上超时；随后接入 `isSearching` 后 `cd Web && npm test` 通过 17 项，`cd Web && npm run build` 通过，`git diff --check -- Web/src/App.tsx Web/dev/appFallbackDom.test.mjs docs-linhay/spaces/20260613-web-triad-qa/README.md docs-linhay/memory/2026-06-15.md` 通过。
- 2026-06-15 主控复核第十三轮：真实浏览器打开 `http://127.0.0.1:34127/?__tritonkit_mock_host_targets=request-failed`，`1200 x 820` 下输入 `zzzz-no-target` 后，`设备` 面板与 `视图树` 面板都显示 `未找到匹配 target`，不再出现 `暂无运行中的仿真器`；当前应用仍为 `丁香园`，bundle 仍为 `cn.dxy.iDxyer`，`QA mock fallback` notice 仍保留。
- 2026-06-15 主控复核第十三轮：清空搜索后，`视图树` 恢复 `DXY iPhone 15 / Pixel API 35 / DevEco Local` 三个 chip，切回 `设备` 后恢复三个 device row；同一流程在 `960 x 820` 下再次成立，`scrollWidth = width = 960`，console error 为空，仅有 Vite debug 与 React DevTools info。
- 2026-06-15 主控复核第十三轮：第十三轮截图归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260615/`：空态为 `20260615-web-request-failed-search-empty-after-v13.png`，清空恢复为 `20260615-web-request-failed-search-empty-restored-after-v13.png`。
- 2026-06-15 主控复核第十三轮：收尾补跑 `docs-linhay/scripts/check-docs.sh` 与 `docs-linhay/scripts/qmd-sync.sh` 均通过，文档结构与 qmd 索引已同步。
- 2026-06-15 主控复核第十四轮：先补 `lets users tune live preview fps without changing selected host target state` 后确认红灯成立，旧实现缺少 `调整实时预览帧率` / `提高实时预览帧率` 控件；实现后 `cd Web && npm test` 通过 18 项。
- 2026-06-15 主控复核第十四轮：`cd Web && npm run build` 通过，`git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs` 通过。
- 2026-06-15 主控复核第十四轮：真实浏览器打开 `http://127.0.0.1:34127/`，`1257 x 963` 下用真实点击 `提高实时预览帧率` 14 次，从 `1 fps` 调到 `15 fps`；live badge 显示 `实时 15 fps`，range value 为 `15`，右侧 `帧率` Metric 为 `15`，当前 app 仍为 `前台 App 未暴露 · iPhone 17`，bundle 仍为 `Target 60667794-96F8-40E6-8664-85538EC4663E`。
- 2026-06-15 主控复核第十四轮：同一浏览器会话切到 Harmony `127.0.0.1:5555` 后，iOS 的 `15 fps` 不污染 Harmony；切回 iOS 后仍恢复 `15 fps`，证明 fps 设置按 target id 隔离。
- 2026-06-15 主控复核第十四轮：`960 x 820` 下再次确认 `rangeValue = 15`、badge 为 `15 fps`、Metric 为 `15`，`scrollWidth = width = 960`，没有横向溢出；console error 为空，仅有 Vite debug 与 React DevTools info。
- 2026-06-15 主控复核第十四轮：第十四轮截图归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260615/`：桌面调节后为 `20260615-web-live-fps-adjusted-after-v14.png`，窄桌面调节后为 `20260615-web-live-fps-adjusted-narrow-after-v14.png`。
- 2026-06-15 主控复核第十五轮：`cd Web && npm test` 通过 18 项，新增断言确认 live preview 调节条默认隐藏、点击状态胶囊后才出现；`cd Web && npm run build` 通过，`git diff --check -- Web/src/App.tsx Web/src/styles.css Web/dev/appFallbackDom.test.mjs` 通过。
- 2026-06-15 主控复核第十五轮：应用内浏览器后台 tab 在本轮验证时崩溃，但 dev server `127.0.0.1:34127` 正常返回 `200 OK`；改用独立浏览器自动化验收同一 URL。`1257 x 963` 下默认仅出现 `展开实时预览帧率控制` 胶囊，无滑杆；点击后出现滑杆和升/降帧按钮，调到 `15 fps` 后 badge、range、右侧 Metric 均为 `15`。
- 2026-06-15 主控复核第十五轮：独立浏览器缩到 `960 x 820` 后 `scrollWidth = width = 960`，无横向溢出，console error 为 0。
- 2026-06-15 主控复核第十五轮：第十五轮截图归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260615/`：收起态为 `20260615-web-live-fps-collapsed-after-v15.png`，展开调节态为 `20260615-web-live-fps-expanded-after-v15.png`。
- 2026-06-17 主控复核第十六轮：先运行 `cd Web && npm test` 得到红灯，问题为 `Web/src/App.tsx` 中 `??` 与 `||` 混用导致 SSR transform 失败，且 `/web/host-input` POST 实际返回 `502`，未满足固定只读 `405` 预期。
- 2026-06-17 主控复核第十六轮：实现后 `cd Web && npm test` 通过 21 项；`cd Web && npm run build` 通过；`git diff --check -- Web/src/App.tsx Web/src/data/iosSimulatorClient.ts Web/src/types.ts Web/dev/iosSimulatorBridge.mjs` 通过。
- 2026-06-17 主控复核第十六轮：搜索确认 `dispatchHostInput`、`HostInputResponse`、`dispatchHostInputThroughTritonServe`、`readJSONBody`、`ensureTritonServeAvailable`、`runtimeBaseUrl`、`web/input` 已不再出现在 `Web/src` 与 `Web/dev` 的运行代码中，仅保留 `/web/host-input` 只读 route 与对应测试。
- 2026-06-17 主控复核第十六轮：真实 dev server `127.0.0.1:34127` 下用 Node-side `fetch` 向 `/web/host-input` POST tap payload，返回 `405`，body 为 `ok=false`、`error.code=web_host_input_readonly`、message 为 `TritonKit Web mock is readonly; use CLI or HTTP runtime contracts for host input.`。
- 2026-06-17 主控复核第十六轮：浏览器页面 `1200 x 820` 下 title 为 `TritonKit 设备中心原型`，当前 target 为 `iPhone 17` / `iOS 26.5`，`实时 N fps` 胶囊可见且调节条默认不展开；`960 x 820` 下 `scrollWidth = width = 960`，console error 为空。
- 2026-06-17 主控复核第十六轮：第十六轮截图归档到 `docs-linhay/spaces/20260613-web-triad-qa/screenshots/20260617/20260617-web-host-input-readonly-after-v16.png`；本轮 Browser 原生截图接口出现 `Page.captureScreenshot` 超时，因此截图采集改用 Playwright，契约判断仍以 dev server POST 与浏览器状态读取为准。
