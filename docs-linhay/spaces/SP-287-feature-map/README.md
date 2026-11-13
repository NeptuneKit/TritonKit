# SP-287 — 当前功能地图与关联图

## 状态与边界

- 需求：用 stack-diagram 绘制 TritonKit 当前支持的功能及其联系。
- 影响层：文档与独立静态图表；不改 CLI、HTTP、SDK、Web 或桌面产品行为，不启动产品服务、不操作设备。用户后续明确授权整理、沉淀与本地提交；未授权推送/发布。
- 绘图事实基线：2026-11-12，原采样 `main@6467b413` 加当时本地 WIP；不是安装版或全平台现场验收证明。整理基线为 `5a10d269`，原 SP-281/SP-286 产品修改已由其他收口提交纳入，不重写历史图为新的现场证明。
- 维护面：本 space、SP-287 索引与当日 memory 段、内部 ops skill 及经验索引；保留其他历史段落。
- 单一图表入口：[功能地图 HTML](./feature-map.html)；浅/深色 PNG 由该 HTML 经 Chromium 截图导出。

## BDD 与验收

1. Given 当前命令入口、公开指南和 provider 契约，When 查看地图，Then 能区分入口、核心闭环、扩展能力与平台适配器，并读取关键关联。
2. Given Web / DSH / SDK / Runner / 模型能力各有边界，When 查看节点说明，Then 不把只读展示当控制面，不把 host 与 embedded 混同，不把模型配置当启用或 ACK 当业务成功。
3. Given 本地未提交增强，When 查看事实基线和节点详情，Then 明示源码/WIP 与发布、运行就绪、真实验收的区别。
4. Given 离线 HTML，When 点击/键盘选择节点或切换主题，Then 可查看命令族、关联、来源和限制；资源全部内联，不依赖 CDN。
5. Given 导出的浅/深色 PNG，When 实际查看图片，Then 无文字重叠、裁切或箭头穿越节点文字。

## 事实来源

- [根命令注册](../../../Sources/TritonKitCLI/TritonKitCLI.swift)
- [本地 HTTP 路由与 runtime 通道](../../../Sources/TritonKitCLI/CLIServeCommand.swift)
- [公开接入与能力说明](../../../README.md)
- [当前跨平台实现与限制](../../../TritonKit.skills/tritonkit-emulator-cli-takeover/references/current-implemented-surface.md)
- [DSH 四工具边界](../../../DSH/README.md)
- [当前只读 Web 写入拒绝](../../../Sources/TritonKitCLI/CLIPackagedWebRuntime.swift)
- [App-map 命令与投影](../../../Sources/TritonKitCLI/CLIAppMapCommands.swift)
- [显式事件录制入口](../../../Sources/TritonKitCLI/CLITestRecorderCommands.swift)

## 交付与验证

- 已完成：4 层、22 个功能族节点、26 条关键调用/数据/产物关联；交互详情包含命令、限制、相邻功能和源码链接。
- 交付：[离线交互 HTML](./feature-map.html)、[浅色 PNG](./screenshots/20261112-features-overview-light-v3.png)、[深色 PNG](./screenshots/20261112-features-overview-dark-v3.png)。PNG 为 3600×3120，由同一 HTML 在 Chromium 2× 截图，不另绘图片。
- 通过：22 个节点详情与 source 数量、键盘选择、主题切换；900px 窗口无横向页面溢出；0 失效图片、0 外部资源请求、0 节点文字溢出、0 箭头/节点文字或分组标题交叉。
- 已实际查看浅/深色 v3 完整图片；v1 为布局修正前证据，v2 的最终复导出出现裁切/残留选中态，均不是交付版本。
- [结构模型](./plans/20261112-feature-model.json)、[构建脚本](./plans/20261112-build-diagram.py)、[浏览器验证](./plans/20261112-browser-validation.json)、[验收记录](./plans/20261112-validation.md)。
- 文档门禁通过：`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`；本次不执行 Swift/CLI/设备/模型/发布验收，不沿用历史产品测试计数。
- 经验沉淀：导出 context/viewport/DSF、未选中态、绘制等待、复导出后实际看 PNG，以及“功能实现不等于 public skills 全覆盖”的核对已写入内部 ops skill 与经验索引；未改变 AGENTS 或 public skills 的产品使用契约。

## Skills 覆盖与整理

- [2026-11-12 逐节点核对](./plans/20261112-skills-coverage.md)是补齐前历史：当时 DSH 无直接 public 指南，HTTP、租约、Lookin details/3D、testrec 和部分 map/VLM 为部分覆盖。
- 2026-11-13 用户已明确要求补齐，由 [SP-288](../SP-288-public-skills-completion/README.md)新增八类使用指南并接入22功能族导航；原图与历史核对不反写为新的发布或现场验收。
- 当前 public 源码 bundle 仍为四个 skill：dev-feedback、emulator-cli-takeover、real-project-regression、update；补齐既有入口/references，不为每个命令新增skill。安装副本与发布资产不因源码文档变化自动更新。
- 版本中只保留正式 v3 PNG、唯一 HTML、模型、可移植构建/渲染脚本和结构化证据。v1/v2 与含个人路径的原始渲染日志保留本机并由本 space 的 `.gitignore` 精确排除。
- 构建脚本可通过 `STACK_DIAGRAM_SKILL_DIR` / `TRITON_FEATURE_MAP_ASSETS_DIR` 选择 stack-diagram 与图标缓存；只打开成品 HTML 不需要这些依赖。渲染脚本使用已打开的任务专属 loopback 页面和相对输出路径，不绑定个人目录或固定服务端口。
- 本轮本地提交仅包含文档/图表/内部经验资料；验证与提交结果以 [验收记录](./plans/20261112-validation.md) 和 Git 回读为准，不推送。
