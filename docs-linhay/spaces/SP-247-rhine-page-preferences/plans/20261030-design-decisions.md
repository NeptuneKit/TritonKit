# 设计偏好对照与调整

消费事实：registry `@linhey/rhine-design@0.11.3`，依赖声明/lock/随包skill不变（manifest仅追加测试入口）。上游2026-10-30 main `3b213d5403ff09109801fc3633970309ff06235a`；#117常驻树与#96 ResponsiveActions已在源码验收，均未npm发布。不导入preview私有路径，不复制源码，不把同version字段候选当registry制品。

## 对照

| 设计指南 / 产品偏好 | 原问题 | 本轮决策与保留边界 |
| --- | --- | --- |
| INTERACTION_PATTERNS：同一导航行的标题/说明/动作 | 每个窗格独立44px菜单空行，随后又一行页面标题 | 窗格菜单通过headerActions合并到真实页面标题；普通流布局，操作不覆盖状态，菜单仍保留分割/更换/关闭 |
| COMPACT_ACCOUNT_PATTERNS：任务优先、只读无框组合 | 嵌套Surface和多层padding占空间；Run身份/状态重复 | 外层pane唯一边界、页面内部单层内距；运行身份仅一处；核心任务、异常、目标和恢复路径常显 |
| 渐进展示：低频机制信息按需阅读 | FPS、来源解释、详细索引全部占首屏 | FPS/目标关联设置与来源帮助采用公开Popover；Run低频事实用Disclosure；实际选值、来源类型、未知/失败不得消失 |
| 局部宽度与命中区 | 固定表格最小宽度给少量路径信息造成横滚 | 路径改无框响应式列表与详情折叠，完整ID、状态、源run、全部建议命令可达；不覆盖DataTable私有CSS |
| 弹窗滚动与内容高度 | 属性Dialog固定height制造分区滚动 | 由实际内容决定高度，保留原属性页签、草稿与复制；窄窗关闭/焦点/最后字段需验证 |
| #117源码规范：层级所有权与焦点 | 原常驻树为扁平treeitem，刷新焦点恢复不足 | 产品语义树按嵌套group完善；方向键只移焦点、Enter/Space选择；外部焦点不抢、Home/End可见行、更新文字与动画保留 |
| 保留产品辨识度与权限 | 深色工作台、设备画布、分屏与更新提示有明确用途 | 保留arknights默认主题/TRITON、geometry/流取消/FPS存储/布局模型；不改设备写入、请求结果或成功语义 |

不新增搜索/分页：本轮是设备/树/只读运行DTO展示，没有服务端筛选需求，不能为了使用ListFilterBar添加无效输入。低频窗格结构动作固定使用Menu是产品任务优先取舍，不声称实现完整三级ResponsiveActions；高频刷新保留显式可访问入口。

## 顺序与验证证据

独立worktree候选先供官方review真实组件场景，主目录保持原版本；浏览器通过后按开工快照三方同步。旧设计1280画布/1600×1050外窗测量：设备viewport top333px、height403px；树top517px；两个独立菜单工具栏。新候选同条件viewport top206.3/height539、树top329.3；详细证据见验收报告。

测试与验收记录另见本space验收报告；未通过时继续修复，不将候选代码写成主目录已生效。


## 已验证实现对应

- `WorkspaceCanvas.tsx` 的 `renderCard` 通过第三参数注入窗格 `headerActions`，`AppCanvas.tsx` 与 `RunWorkbenchCard.tsx` 逐层传递；空白窗格的“添加视图”标题也承接同一 Menu。外层 Surface 保留唯一边界，Stream/Inspector/Run 根使用语义 section，不叠加主题装饰或覆盖组件私有 CSS。
- `StreamPanel.tsx` 在标题动作区提供公开 Popover 的预览设置入口，保留实际 FPS、目标选择和画面状态；`InspectorPanel.tsx` 将跟随/固定与来源机制收入对应 Popover，保留真实选择值和错误/旧快照提示，属性 Dialog 不再指定固定高度。
- `InspectorHierarchyTree.tsx` 根据实际树关系渲染嵌套 `role=group`，保留 roving focus、选择、展开、hover、可见行 Home/End；刷新删除当前焦点节点时按可见祖先恢复，外部焦点不抢。常驻树仍消费原 DTO，来源不是复制上游组件。
- `RunWorkbenchView.tsx` 将 `goal`、唯一 Run 身份/状态、应用与当前目标、Atlas 覆盖/计数、暂停和 Provider 未就绪保留在页签前；当前运行保留恢复/启动建议正文，低频标识、Provider 开关、Map ref、Path IDs 与证据按需展开。路径改公开 Stack/Inline/Disclosure 无框组合，避免 DataTable 固定 500px 最小宽度；全部路径状态、确认/回放/VLM 要求、来源和命令均可达。建议命令包括 blocked 路径和后续可回放路径，复制仍由真实 Promise 决定结果，不执行命令。

`#117` 当前为 closed / accepted，revision `3b213d5403ff09109801fc3633970309ff06235a` 的规范采用不等于 npm 发布；`InspectorHierarchyTree` 保留 Temporary design adaptation 标记和 issue 链接。后续同主题或授权升级时按实际制品复核，满足原交互与动态验收才移除。`#96` 未发布的 ResponsiveActions 不直接导入；本轮窗格低频结构动作使用已有 Menu，不宣称实现完整三级收纳 API。

最终候选142/142 Web测试、设计构建与浏览器验证通过，详见[验收报告](20261030-validation.md)。
