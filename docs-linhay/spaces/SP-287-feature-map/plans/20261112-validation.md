# SP-287 功能地图验收

## 事实口径与影响面

- 日期：2026-11-12；仓库 main HEAD `6467b413`，读取当前源码与既有 SP-281/SP-286 等本地 WIP。
- 绘图阶段只修改 SP-287 图表/资料、两份 space 索引与当日 memory 任务段；当时未提交。用户随后明确授权整理、沉淀和本地提交，当前基线 `5a10d269`；本轮另更新内部 ops skill/经验索引与 skills 覆盖核对，不修改产品、全局配置、锁文件或发布资产，不推送/发布。
- 图中“已接入”仅表示命令/实现/契约存在，并附平台/权限/provider 前提；不是全平台、安装版或今日设备实测声明。未完成统一 owner、全局 Stop、通用自动删除、设备云、多租户、正式 Wails 控制面不画成已支持。
- 主线：能力发现 → 目标绑定 → 页面观察 → 动作执行 → 业务验证 → 证据归档。扩展层连接设备/App、WebView/网络、UI 检查、构建、测试/回放与 Workspace/Atlas/App-map；平台层分别表示 iOS Host、iOS embedded、iOS Runner、Android 与 Harmony。

## 构建与资源

- 按 stack-diagram 的模板、坐标与图标规范生成[唯一 HTML](../feature-map.html)，所有图标和 Geist/JetBrains Mono 字体内联；中文使用系统 SC 字体回退。
- 图标来源：svgl 的 Apple/Swift/Android、devicon 的 Xcode、Lucide 功能图符。Harmony 以通用设备图符表示，不伪造品牌标志。
- Python 系统环境没有 Playwright；未安装依赖。ego-browser 完成交互/布局检查；最终采用已安装 Playwright CLI 的独立无头 Chrome context 导出同一 HTML。临时 loopback 静态文件服务仅用于图表导出，不是产品或 DSH GUI 替代服务；无模型调用，未另绘图片。
- 构建脚本：`python3 docs-linhay/spaces/SP-287-feature-map/plans/20261112-build-diagram.py`。需已安装 stack-diagram 的模板/字体并按 icons 清单准备 `<assets>/icons`，通过 `STACK_DIAGRAM_SKILL_DIR` / `TRITON_FEATURE_MAP_ASSETS_DIR` 明确指定依赖位置；离线 HTML 成品不需要这些构建输入。
- 源数据：[模型](./20261112-feature-model.json)；浏览器检查：[JSON](./20261112-browser-validation.json)。交付 PNG 为浅色/深色 v3，3600×3120。

## BDD / 浏览器验证

| 检查 | 结果 | 证据范围 |
| --- | --- | --- |
| 节点/边身份与引用 | 通过 | 22 unique nodes、26 edges，所有 source 文件存在 |
| 节点详情 | 通过 | 全部 22 节点的标题、选中态、source 数量 |
| 键盘 | 通过 | focus + Enter 触发动作节点详情 |
| 主题 | 通过 | UI 按钮切换深色，浅/深 PNG 实际查看 |
| 缩放 | 通过 | 900px viewport，850px 画布适配容器，无页面横向溢出；1:1 可切回 |
| 文字/连线 | 通过 | 0 节点文字溢出；逐条 path 2px 采样与节点文字/分组标题矩形无交叉；人工看图复核 |
| 离线资源 | 通过 | 0 broken images；0 HTTP(S) resource requests |
| 文档门禁 | 通过 | `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`；日志保留于本目录 |
| Swift/CLI/设备实测 | 未执行 | 纯文档与静态图，不用历史绿色测试代替现场验收 |

第一版渲染发现 3 处 role 文本溢出，并在人工看图时发现垂直入线穿过分组标题。已缩短角色文案、Workspace 主标题和调整左侧入线，第二版 DOM 检测为零，但最终复导出的 PNG 曾出现 scroller 裁切及残留选中态，故 v2 不作为交付。第三版用独立 headless context 明确固定 1900×1800 viewport / DSF=2，canvas 原点归零，禁用 transition/animation 并等待双 requestAnimationFrame，以 element screenshot 输出完整 3600×3120 PNG；两张成图已重新实际查看。Browser.getVersion 在 ego TaskSpace CDP 不可用，仅保留 userAgent；Playwright file: 导航被默认策略拒绝，未修改策略，使用任务专属临时 loopback 静态入口。该修正没有改变产品行为。

## 经验检查

沿用已有经验“命令名/字段存在不等于产品闭环；fixture/源码、provider readiness、运行验收与发布须分开”。已在节点详情、图头基线及页脚记录。导出经验：DOM 矩形完整不等于 PNG 完整；每次复导出后都需实际看图，显式固定导出 context、viewport、DSF、裁切与绘制状态，并用 PNG IHDR 验证尺寸。证据保留在本原文、浏览器 JSON 与渲染脚本/本机原始日志。后续用户明确要求沉淀，本轮已将通用检查写入内部 ops skill 与经验索引；不修改 AGENTS 或 public skills，不扩大成产品需求。

## 2026-11-12 整理提交检查

- 新增 [skills 覆盖核对](./20261112-skills-coverage.md)：按 22 个功能族分别记录主要流程、部分覆盖和无直接入口，当前 bundle 为四个 public skill。没有把命令/关键词存在误当完整操作指南，也没有修改/安装/发布 public skills。
- 构建脚本去除个人绝对路径，改用环境变量/用户默认 skill 位置与临时缓存；渲染脚本改为当前选中的任务专属 loopback 页面及相对导出路径。仅作可移植化，不更改 HTML/模型或最终 PNG 内容。
- 正式版本只提交 v3 图像、唯一 HTML、模型、脚本、结构化验证与文档日志。v1/v2 及含宿主路径的原始渲染 log 保留本机，明确 ignore；早先临时 DOM 快照归档为相对路径证据后清理自有临时副本。
- 提交前已重跑 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`、Python AST 与 `node --check`；22节点/26边及来源存在、最终 HTML/PNG SHA-256 和 3600×3120 尺寸通过。指定实际图标缓存后，可移植构建输出与原 HTML 字节一致，无需重绘或挪用旧设备验收。首次直接采用 macOS 临时目录时因缓存不在该处而 exit 1，门禁链停止；显式选择原缓存后通过，不能把临时目录存在误当资源齐备。本轮未安装新依赖，未重跑产品/设备验收。实际命令结果见同目录 docs-gate/check-docs 日志与 Git 回读。
