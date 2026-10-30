# 2026-10-30 Rhine 接入验收

## 候选与阶段

独立 worktree `SP-245-rhine-design-adoption` 从 `30185dc2` 建立；本次仅 Web 展示与设计规则。设计验证后同一 View 接回原 RunWorkbenchCard，再将本轮精确文件同步主目录；不提交、推送或发布。主目录原有设备资源、预览暂停和参考采用 WIP 保留。

固定制品与 skill 摘要见 [rhine-artifact.json](../../../../design/rhine-artifact.json)。npm 0.11.3、React 19、Vite 7.3.5、Node 24.21.0；新增 @types/node 用于独立 Vite 配置的 Node URL 类型检查。默认 Node 25 首次安装产生 engine warning，后续使用受支持 Node 24 验证。未变更原有已锁定包版本。

## 已通过

- TDD：先出现缺失 catalog/View 失败，再实现；8 项设计/展示测试通过，包含加载/错误/旧 DTO、未知覆盖率、空路径/命令、长身份文字、URL 参数回退，以及真实构建正负例（正式 guard 拒绝 fixture 和 review 模块）。macOS 临时测试目录先 realpath，避免路径别名造成精确文件匹配误判。
- 工作树 Web 完整原有测试 78/78 通过。首次缺少局部 Triton 二进制导致 11 个 suite 初始化失败；绑定现有 `TRITONKIT_TRITON_BIN` 后通过，未执行设备动作。集成后新增设计测试一并纳入默认 npm test，主目录完整默认 npm test 108/108 通过（包含并行预览任务新增测试和本次8项测试）；TypeScript、正式构建、独立设计构建均通过。
- `npm run build`：TypeScript 与应用构建通过，官方 production guard 通过；移除原工作台孤立 AntD CSS。`npm run design:build`：独立目录 TypeScript 与官方评审构建通过。
- 真实 Chromium：三主题 × 400/520/880 画布 × 100%/200% CSS zoom × 六场景，108 组单主题根、iframe 保持与文档无横溢检查通过，见 [矩阵](20261030-review-matrix.json)。另外 36 组路径/命令页签组合通过；400×200% 时表格500px在约149 CSS px局部滚动容器可达，不裁列。
- Overview/Atlas paths/Commands 方向键切换、键盘焦点 2px outline、主题/尺寸变化保持已选页签。运行失败、读取失败、加载保留旧记录、空结果 unknown 的浏览器正文核对通过。
- 系统 prefers-reduced-motion 与手动 reduced 均传入单主题根；本页面无持续动画、Canvas/WebGL或定时播放，未声明 full/paused。静态截图不是设备流或树动效验收。
- 产品静态构建实际运行：原 DTO 内容保持，单 Rhine 根与旧 AntD 区域共存；未连接设备。发现 pane 工具条与状态 badge 在1280宽时重叠666.56平方像素，宿主预留40px操作行后交集为0；只改宿主布局，不覆盖组件私有CSS。400外窗根无横溢，原分屏会让单卡宽约158px，整应用移动布局仍属后续外壳切片。

## 反馈与回接

- [#116 新增消费验证](https://github.com/linhay/rhine-design/issues/116#issuecomment-6514620059)：只读诊断快照的任务状态/读取状态分离、命令复制不等于执行；已提交并回读。
- [#40 新增官方 review 消费证据](https://github.com/linhay/rhine-design/issues/40#issuecomment-6514632554)：同组件设计→业务接回、单主题根、隔离与排除反例；已提交并回读。
- #14 紧凑只读组合、#19 筛选、#100 持续反馈已有覆盖，沿用规范，不重复发单。
- #66/#74/#76 已有源码改善但不在 npm0.11.3；本轮不依赖其新增能力，不复制工具壳私有CSS。后续同主题或已授权升级再核对制品并回接。
- 新增建议仅处于“已反馈”，不宣称上游已接受/实现/发布。已有官方0.11.3入口处于“已发布、本项目已验证”。本轮无 Temporary design adaptation；宿主布局为产品组合。

## 限制和未执行

- 本项目原 Run/Atlas 仍使用已有 mock DTO，未新增真实后端；仅这一现有页面完成设计与展示实现闭环。其余四类页面见根 DESIGN_SYSTEM 迁移矩阵。
- 未跑原生 UIKit/Wails、真实设备或 Swift 全套：本轮未改相应代码/契约，浏览器不能替代这些验收。iOS 上游 main 仅规范，UIKit draft PR 尚未合入且未发布，因此不强行安装。
- 200% 是官方 CSS zoom；浏览器原生缩放、WebKit/Firefox、屏幕阅读器语音未执行。页面没有模态/浮层，不为验证添加无需求弹窗；官方壳自身继承现有版本边界。
- npm audit 返回7项（5 high / 1 moderate / 1 low），全部属于升级前已锁定依赖记录：vite、esbuild、baseline-browser-mapping、browserslist、nanoid、postcss、source-map-js；本次未自动更新无关依赖。主目录应用约885KB JS（gzip286KB）仍有>500KB分块提示，共存阶段保留，非失败。
- local Swift/CLI/设备总门禁未运行；本轮匹配门禁是完整 Web 测试/两构建、docs fast gate、check-docs、diff检查。没有将局部验证称为整体发布验收。

## 主目录收口复验

- `npm ci` 使用Node24按lock重装通过；原有锁定包版本无漂移，随包skill五个文件摘要匹配。
- 默认 Web 测试108/108、正式 build、design:build、`verify.sh --ci-docs`、`check-docs.sh`（245 spaces）、`git diff --check`通过。文档初次因路线链接显示名不等于space key失败，修正登记显示名后通过；未放宽校验器。
- 浏览器真实点击复制：注入隔离 Clipboard adapter 拒绝后显示alert“复制失败，请重试”，异步resolve后仅记录对应命令并显示“已复制”；未写系统剪贴板、未执行命令。
- 两条公开反馈均回读确认；#40追加宿主工具条几何发现，规范已同步本项目workflow/经验索引。
- 未运行Swift/CLI/设备总门禁，原因与适用范围见上节。既有依赖扫描与大包提示保留。

- 主目录正式产物浏览器回读：三个页签、单主题根、宿主工具条交集0、文档横溢0；[产品截图](../screenshots/20261030-workbench-product-passed-v1.png)。评审预览已从主目录构建在34128启动，属当前本地进程，停止后按design/README重启。
