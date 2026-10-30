# SP-246 其余 Web 页面 Rhine 迁移

状态：设计验证后已接回主目录并完成复验。本地提交收口，未推送或发布。影响层：Web 展示/交互与设计入口。固定 npm0.11.3。

## 范围与顺序

设备预览、层级检查、分屏画布、应用外壳；保留 DTO、设备流取消/可见性/帧率、视图/AX切换、选择/展开/复制、属性草稿只读、布局持久化及拖动。先建立共享实际视图的合成设计稿，验证后接回生产组件。CLI/HTTP与设备控制不改；不提交推送或发布。

## BDD

- Given 原有流控制器，When 迁移控件和设备选择，Then目标/FPS/连接意图/可见性生命周期不变，仍只读。
- Given 合成三平台层级，When 展开/选择/切换检查模式，Then同一DTO与模型决定展示，键盘焦点和更新高亮保留。
- Given 已持久化布局，When 分割/拖动/卸载/关闭/恢复，Then原布局模型语义保持，窄屏操作可达。
- Given 官方review，When切场景/主题/尺寸，Then无真实网络或设备副作用，已验证视图接回同一实现。
- Given生产构建，Then无review/新合成场景，通用控件只消费Rhine公开API。

## 验收

现有与新增Web测试、类型检查、两套构建、浏览器400/520/880及200%CSS zoom、三主题/长文本/空/加载/错误/键盘/焦点/浮层、动态高亮与减少动态；真实设备未验证须明确，不把fixture等同native。上游反馈查重提交回读。

分支：`feat/SP-246-rhine-web-migration`；worktree：`../TritonKit-worktrees/SP-246-rhine-web-migration/`。基线为主目录当前Web候选（包含SP-244/SP-245未提交改动），集成以该快照三方比较保留他人工作。


## 证据与交付

- [验收报告](plans/20261030-validation.md)：固定制品、功能保持、125项Web测试、54组布局与交互/动态证据、未执行边界。
- 设计入口：`npm --prefix Web run design:dev` → `http://127.0.0.1:34127/#scene=workspace&theme=arknights&width=880`，4个真实组件场景，全部合成数据。
- [上游树反馈](https://github.com/linhay/rhine-design/issues/117)、[验证补充](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515132468)，均已回读。该阶段仅已反馈；SP-247已核对规范接受，仍不代表npm发布。
- 文档与经验：根DESIGN_SYSTEM、design目录与Web mock skill。无新增根AGENTS规则，无Git提交/推送/发布。

## 整理提交

2026-10-30 用户授权整理、沉淀与本地提交。SP-245～247 的规则、固定制品、设计稿、页面实现、测试与合成证据统一归档；此前“未提交”是阶段记录，当前提交边界与验证见[收口记录](../SP-247-rhine-page-preferences/plans/20261030-commit-recap.md)。未推送或发布，保留其他任务WIP。
