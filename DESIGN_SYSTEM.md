# TritonKit 产品设计体系

本文件维护产品边界、页面迁移范围和本项目偏好；执行步骤见[设计开发流程](docs-linhay/dev/rhine-design-workflow.md)，页面角色、状态、预览入口和验收见 [design/](design/README.md)。初次接入与 Run/Atlas 范例见 [SP-245](docs-linhay/spaces/SP-245-rhine-design-adoption/README.md)；其余 Web 页面接入见 [SP-246](docs-linhay/spaces/SP-246-rhine-web-migration/README.md)；四页设计偏好与验收见 [SP-247](docs-linhay/spaces/SP-247-rhine-page-preferences/README.md)。

## 来源与兼容边界

| 层 | 事实与采用范围 |
| --- | --- |
| Web | React 19、TypeScript、Vite 7；固定消费 npm `@linhey/rhine-design@0.11.3`，来源仓库 [linhay/rhine-design](https://github.com/linhay/rhine-design)。React 19 peer 匹配；Node 支持 `^22.12.0 \|\| ^24.0.0 \|\| >=26.0.0`，项目验证使用 Node 24，默认 Node 25 不属于支持范围 |
| 评审工具 | 0.11.3 实际导出 `/review`、`/review/vite`，使用随包 `docs/REVIEW_TOOL.md` 和生成式评审壳；不复制通用工具栏、场景路由或 iframe 协议 |
| Web 组件与主题 | SP-246 已将设备预览、层级检查、分屏画布和外壳接回 Rhine；App 使用单一 ThemeProvider，已移除 Ant Design 依赖、reset、ConfigProvider 与旧样式。SP-247 仅调整产品组合，不升级 npm 制品；主目录142项测试、两套构建及浏览器复验通过 |
| iOS | 对应 [linhay/rhine-design-ios](https://github.com/linhay/rhine-design-ios)，以 UIKit 为主，独立规范、组件、版本与原生验收；本轮未安装；2026-10-30 核对其 README：main 仅规范，UIKit 包在 draft PR #1 尚未合入且未发布，不把 Web 组件套入 Swift |
| Swift SDK / CLI / HTTP | 无 React 组件适用面；只复用适用的语义、可访问性与信息层级原则，不增加 npm 或 UIKit 依赖 |
| Wails / 桌面壳 | 本轮未恢复或改造其产品面，浏览器评审不能替代桌面或原生运行证据 |

安装版本与来源以 [manifest](Web/package.json)、[lockfile](Web/package-lock.json) 和 SP-245 制品记录为事实源。随包规范入口位于 `Web/node_modules/@linhey/rhine-design/`：`README.md`、`docs/DESIGN_SYSTEM.md`、`docs/INTERACTION_PATTERNS.md`、`components/COMMON_COMPONENTS.md`、相关组件契约及 `skills/rhine-design/SKILL.md`。这些安装路径是读取入口，不是可修改源码。全局 skill 或上游最新偏好可能更新更快，不替代当前包导出。

通用规范、tokens、组件、组合配方与展台归设计库；页面组合、权限、数据、业务规则、设计稿和验收归 TritonKit。Web 保持只读 DTO 展示，设计迁移不改变 CLI/HTTP 的事实入口。

## 产品原则与既有辨识度

- 从当前用户任务保留身份、必要信息、操作结果和恢复路径；删除重复状态提示、装饰与无决策价值说明。操作区只放操作，时间等元信息随相关内容展示。
- 紧凑操作区按文字按钮、图标按钮、更多菜单顺序收纳；可访问名称、权限、顺序、busy 与焦点不变。
- 列表搜索筛选优先实际版本提供的 `ListFilterBar`，最多两个常显条件，其余收入更多筛选，保留摘要和请求反馈。现有工作台是 DTO 事实展示，本轮不为了采用组件而新增搜索或分页。
- 搜索和分页继续服务端处理；需要输入时由产品实现防抖、IME 组合、取消与过期响应保护。权限与成功语义来自真实接口，不从配色、动效或 mock 推断。
- 保留深色开发者工作台、可分割卡片、设备镜像几何与树更新高亮的意图。SP-245 首个迁移页与 SP-246 其余页面均复用 Rhine 公共主题与语义 tokens；设备画布保留几何与只读选择语义，树更新保留 1 秒高亮。偏好与平台约束、明确产品决定冲突时记录场景和理由。

## 页面迁移范围

| 页面 / 文件 | 用户任务与既有状态 | 本轮范围 / 后续缺口 |
| --- | --- | --- |
| `Web/src/components/RunWorkbenchCard.tsx` | 查看 Run、Atlas 路径和建议 CLI 命令；保留概览/路径/命令分区与原 DTO 语义 | SP-245 已接入 `RunWorkbenchView`；SP-247 已改为任务/异常常显、低频详情折叠、路径响应式列表与完整建议命令，不新增真实 Run 后端 |
| `Web/src/components/StreamCard.tsx` | 只读设备预览、目标/FPS、刷新/暂停等本地视图状态 | SP-246 已接入 `StreamPanel`；SP-247 已合并标题/窗格动作，FPS 用 Popover，保留取消链、可见性、图像比例与坐标映射；真实设备未验证 |
| `Web/src/components/InspectorCard.tsx` | 层级树、属性、选择和证据阅读 | SP-246 已接入 `InspectorPanel`；SP-247 已收纳关联/来源帮助、Dialog 随内容增高、树嵌套所有权与焦点恢复；三平台、只读草稿/复制保持，临时树关联 #117 |
| `Web/src/components/AppCanvas.tsx` | 卡片选择、分割布局与恢复入口 | SP-246 已接入 `WorkspaceCanvas`；SP-247 已将 Menu 注入页面标题行，Surface 为唯一窗格边界；保留布局模型、持久化、增量拖动与键盘分隔条 |
| `Web/src/App.tsx` / `styles.css` | 应用外壳、深色品牌和主题 | SP-246 已接入 `WorkspaceShell` 与单一 Rhine ThemeProvider；SP-247 保留 TRITON/深色工作台，页面根改语义 section，结果见 SP-247 验收记录 |

## 临时方案／待规范复核

本轮不以私有 CSS 补写评审壳。上游 [#66](https://github.com/linhay/rhine-design/issues/66)（场景目录滚动）与 [#74](https://github.com/linhay/rhine-design/issues/74)（画布优先布局）是后续版本核对项；issue 关闭不证明 npm 0.11.3 已包含修复。当前是否满足使用场景以实际评审验证为准。

当前临时适配：`Web/src/components/InspectorHierarchyTree.tsx`、`inspectorTree.css` 与 `inspectorPanel.css` 中的产品层级树，消费 npm 0.11.3。包仅导出 TreeSelect，不能替代常驻浏览树；适配保留 ARIA treeitem、上下/左右/Home/End、展开/选择/hover、长文本与 1 秒更新高亮。[缺口 #117](https://github.com/linhay/rhine-design/issues/117) 及[消费端验证补充](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515132468) 已提交并在 SP-246 留存；SP-247 核对 #117 已 closed / accepted，上游 revision `3b213d5403ff09109801fc3633970309ff06235a` 已接受常驻树规范，但 registry 0.11.3 未发布对应能力。产品临时组合继续保留，不能把源码接受写成消费端升级完成。后续同主题或授权升级时复核正式制品；仅在公开能力或配方可等价覆盖上述交互、三平台 DTO 联动及动态验收后移除，不能根据 issue 关闭直接删除。

新增临时适配时在此记录：差异与原因、代码文件/适用场景、制品版本、issue/comment、已验证证据、复核触发和移除条件。代码只用最小英文注释 `Temporary design adaptation` 加 issue URL；工程标记不进入产品界面。升级后先验证等价行为，再清理被覆盖部分，未覆盖项继续保留原因。

## 验收与持续共建

用户于 2026-10-30 明确授权本项目任务内的设计反馈。流程、失败草稿和回接条件见[设计开发流程](docs-linhay/dev/rhine-design-workflow.md#持续反馈与临时适配)；具体反馈链接及“已反馈/已接受/已实现/已发布/本项目已验证”阶段写回对应 space。页面状态与实现结果以当前验收记录为准，不以本文件的迁移计划宣称已完成。

SP-246 历史浏览器设计验证：三新增场景 × 400/520/880 宽度 × 100%/200% CSS zoom × 三主题，共 54 个长文本布局组合未见横向溢出；三平台状态、跟随/固定、双向选择、键盘、Dialog 主题/Escape/焦点、复制失败、预览隐藏释放与恢复均已检查；高亮动画进度由约 33ms 推进至 183ms，1 秒后标记清理，系统减少动态通过。手动减少动态通过；Web全套125/125与生产构建通过；真实设备、UIKit/Wails 和浏览器原生缩放未执行。设计环境的合成图像与内存刷新不构成真实后端验收。

SP-247 已完成四页设计偏好调整并同步主目录，142/142 Web测试、生产/设计构建、72组布局与最终深树36组复验通过。标题与操作合并、低频详情渐进展示、属性弹窗及树焦点/连续高亮已验证；固定 registry0.11.3与随包skill不变。[验收记录](docs-linhay/spaces/SP-247-rhine-page-preferences/plans/20261030-validation.md)区分真实浏览器、合成数据与未执行边界；[#14组合反馈](https://github.com/linhay/rhine-design/issues/14#issuecomment-6515899375)、[#117焦点发现](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515924782)已提交回读，未提交发布。
