# Web Rhine 迁移验收

## 候选、边界与顺序

2026-10-30；根基线 main `30185dc277ed305483aa789cb2d8c8b06fa21fe4` 加开工时已有 SP-244/SP-245 Web WIP，独立 SP-246 worktree。先建立 StreamPanel / InspectorPanel / WorkspaceCanvas / WorkspaceShell 和官方 review 场景，类型检查及浏览器评审通过后才将旧 Card/AppCanvas/App 入口接回。未修改 CLI/HTTP/设备协议；产品仍为现有只读 Web 原型。根 AGENTS 既有设计闭环规则足够，本轮不重复添加。

固定消费 `@linhey/rhine-design@0.11.3`，npm tarball/SHA512/随包skill摘要见 [制品记录](../../../../design/rhine-artifact.json)。Node24.21.0，React19。移除 AntD 及孤立传递依赖共63条 lock 记录；相对开工快照：新增依赖0，保留包版本变化0，Rhine未升级、随包skill未改。npm audit仍报告既有7项（5high/1moderate/1low），未在皮肤迁移中升级无关依赖。

## 实现与语义

- 设备：公开 Select/SegmentedControl/Button/Badge/Notice，保留三平台设备发现、FPS存储、连接意图、可见性暂停、取消/StrictMode ref恢复、真实首帧判断、图像比例和overlay选择。新图像失败/重试基于真实img事件。固定标注只读；无设备写操作。
- 层级：公开 Tabs/Dialog/CopyButton/表单控件/KeyValue/Notice；保留来源差异、跟随/固定、展开/选择/hover、属性草稿与DTO/patch复制。常驻语义树是 #117 最小临时适配，未复制库私有CSS。焦点/选择分离、更新提示1秒与清理。
- 外壳：同一主题根默认arknights；保留TRITON品牌、布局存储与3卡片。窗格动作归正常流Menu，卡片选择为键盘按钮；小于880px的局部布局视觉转上下，存储方向不变。分隔条pointer capture/cancel与键盘箭头/Home/End，关闭/更换有焦点恢复。
- 修复：旧分隔条每move重复累加总delta（旧反例0.06≠0.04），改相邻增量；缩放下命中改用实际bounding rect与client坐标统一换算；固定“服务运行中”改准确“只读工作台”。保留任务意图，去除无事实支撑的装饰状态。

## 已通过

- 全部Web测试125/125；新增候选测试先红后绿，覆盖三平台来源、只读属性、语义树导航、流生命周期接口与分隔算法。现有HTTP取消、host targets、inspect/session/draft/hitTest模型测试继续通过。
- 生产 `npm run build`、设计 `npm run design:build`（均含TypeScript）。官方production guard正负例；生产产物不含新设计fixtures/review入口。
- [54组长文布局](20261030-browser-matrix.json)：3新场景 × 400/520/880 × 100%/200% CSS zoom × 3主题。相关窗格未横向溢出，另查看窄屏Dialog截图及实际菜单可达性；不只依赖整页scrollWidth。
- [三平台状态](20261030-browser-states.json)：层级ready/empty/loading/error与真实来源文案；画面离屏时paused符合可见性规则，该矩阵内paused不算图像错误通过。另将画面置于可见880宽/100%验证[真实img error与retry](20261030-browser-errors.json)：错误提示、换新img、旧src释放。
- [双向选择/键盘/busy/隐藏释放恢复](20261030-browser-interactions.json)、[目标固定/跟随、Dialog与动画](20261030-browser-pinDialog.json)、[200%命中](20261030-browser-zoomHit.json)。Dialog Escape 后焦点回到“节点详情”；异步复制reject显示失败。
- 动画实际时间约33ms→183ms，1秒后清理；系统reduced与[手动reduced](20261030-browser-manualReduced.json)均关闭动画保留短时标记。未声明全场景full/paused，不以CSS暂停假冒计时器暂停。
- 实际鼠标拖动分隔条改变比例，释放后pointer capture清理；Menu四动作与空白三卡片选择可用，400宽Menu在画布内。刷新后更换为Inspector与63%布局持久化。生产单主题根、400/520/880无窗格横溢，无review资源、无浏览器console错误。
- 浏览器证据为Chrome真实DOM/输入/动画；截图在本space screenshots。评审工具自身有sandbox allow-scripts+same-origin浏览器提示，按其公开同源隔离协议使用，没有产品console错误。

## 验证失败与修复

首次候选typecheck发现KeyValue缺required key，已补齐后两构建通过。首次125项测试均绿但SSR server退出时dep-scan报outdated request：默认扫描了新增dist-review HTML，已在SSR测试禁用依赖发现、正常Vite限定index.html，复跑125项通过且无该噪音。浏览器初次同路径切构建命中旧canvas缓存，ignoreCache reload后重测；Menu脚本click未触发Radix pointerdown，不当作产品失败，已用真实点击验证。

## 未执行与剩余边界

本轮未运行Swift全量/`verify.sh --local`（其主体为Swift/CLI/native smoke，未改该层且有独立并行WIP）、真实MJPEG/native/iOS/Harmony/Wails设备运行、浏览器原生200%缩放。CSS zoom与合成SVG/内存请求不能替代它们。真实首帧/断连的历史证据仍归SP-244；本轮仅保留实现并回归其Web测试。Run/Atlas仍原mock DTO，没有新增正式后端。设备发现现有client把网络失败收为无目标，本轮不改接口成功语义。

## 上游与回接

[#117](https://github.com/linhay/rhine-design/issues/117) 新建并回读；[验证评论](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515132468) 已回读，完整脱敏草稿与JSON回执同目录。阶段：已反馈、本项目局部方案已验证；未宣称上游接受/实现/发布。后续同主题或授权升级检查实际导出、规范、展台与固定制品，验证等价再移除树适配。#66/#74/#76等closed不等于npm0.11.3包含，不擅自升级。

集成：按开工文件快照逐文件三方比较，保留主目录并行变更；不提交、不推送、不合并分支、不发布。主目录复验结果见下方。


## 主目录最终复验

已同步67个相对开工快照变化文件（含本地截图），共享INDEX/路线README三方合并保留并行SP-244状态；其余当前主目录文件与快照一致才覆盖。主目录 `main` 未切分支、未创建Git提交；独立worktree保留未提交候选与开工快照。

主目录 Node24 `npm ci`、Web125/125、生产build、design:build、verify --ci-docs、check-docs（246 spaces）与git diff --check均通过。主目录生产静态预览实际加载验证：单主题、保存的Inspector/63%比例重载保持、400宽视觉上下重排且无横溢；[smoke结果](20261030-product-smoke.json)。生产资源没有review/新fixtures，console无error/warn。

最终设计预览由主目录dist-review启动在 `http://127.0.0.1:34128/#scene=workspace&theme=arknights&width=880`，4场景目录回读确认。`design:dev` 尝试被strictPort拒绝，因为34127由另一既有Web进程占用；没有抢占该进程，改用固定34128设计preview，停止了自己临时的生产preview。浏览器布局/动效验收来自相同源文件候选，主目录构建产物复验未替代真实设备证据。
