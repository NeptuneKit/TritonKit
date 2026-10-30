# SP-245 Rhine Design 接入

状态：实现及设计验收完成，已按文件同步主目录，整合复验通过；本地提交收口；未推送、发布。

设计预览：`npm --prefix Web run design:preview`（先 `design:build`），本地 `http://127.0.0.1:34128/`；[运行说明](../../../../design/README.md)。

开发分支：`feat/SP-245-rhine-design-adoption`；worktree：`../TritonKit-worktrees/SP-245-rhine-design-adoption/`。主目录保持原 main 与已有 WIP。

## 边界

影响层为 Web React/Vite 只读展示与开发设计入口；保持 CLI/HTTP、Swift SDK、Wails 状态流和既有未提交工作。选择现有 Run / Atlas Workbench 作为唯一迁移范例，其他页面仅盘点。不发布、不提交推送、不修改设计库源码。设计反馈已由用户明确授权。

## BDD 与验收

- Given 固定可恢复的 Rhine 制品，When 安装构建，Then manifest/lock/摘要/随包 skill 一致且 React 19 兼容。
- Given 合成 Run/Atlas DTO，When 打开设计入口，Then 官方 review 壳可切换场景、尺寸与主题，复用实际工作台组件；不访问设备或业务写接口。
- Given 设计阶段通过，When 原工作台接回相同组件，Then 概览、路径、命令保持原始 DTO 语义，未知/失败不伪造成功。
- Given 正式 build，Then 不含设计入口、场景和 review 壳。
- Given 窄屏/长文本/空/加载/错误，Then 信息可达、键盘焦点可见，浮层及减少动态符合实际包契约。
- Given 新反馈，Then 查重、脱敏提交并回读；关联版本与后续移除条件。

## 记录

- 设计入口与页面目录：[design](../../../../design/README.md)
- 产品设计体系：[DESIGN_SYSTEM.md](../../../../DESIGN_SYSTEM.md)
- [验收与反馈](plans/20261030-validation.md)；[固定制品与 skill 摘要](../../../../design/rhine-artifact.json)。

## 整理提交

2026-10-30 用户授权整理、沉淀与本地提交。SP-245～247 的规则、固定制品、设计稿、页面实现、测试与合成证据统一归档；此前“未提交”是阶段记录，当前提交边界与验证见[收口记录](../SP-247-rhine-page-preferences/plans/20261030-commit-recap.md)。未推送或发布，保留其他任务WIP。

远端此前的仅编号登记由本次完整整合接替；登记历史保留于 `e6258339`，不将占位资料解释为当时已交付。
