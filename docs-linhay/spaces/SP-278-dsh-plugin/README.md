# SP-278 · TritonKit DSH 插件

## 状态与边界

2026-11-09：0.1.1实现、复验、提交、合并及推送完成；远端main合并提交 `f4efd202` 的DSH plugin/主CI均通过。当前profile已更新生效。原主目录15条无关提交及WIP保持原状，本地主目录main未被强行同步；真实设备动作和GUI展示未验边界保持。

- 基线：`main@d94213c4`；独立分支 `feat/SP-278-dsh-plugin`，同级 worktree `../TritonKit-worktrees/SP-278-dsh-plugin`。主目录既有 WIP 不动。
- 影响层：新增 `DSH/` Host-only Cordis bundle；复用已安装 macOS `triton` CLI，不改 Swift core、HTTP、Web/Wails、设备 provider。
- 当前机器 CLI 0.2.42；DSH API 通过 live Inspect 的 tools/subprocess/workingDirectory/sandboxPolicy 契约核对。
- 不提供任意 shell、任意 argv、外部工具路径参数、远端服务地址、长期服务管理、安装/卸载、删除、重放、自动设备操作或 UI 控制页。
- 所有工具要求 DSH `danger-full-access`，每次执行读取会话实际权限；低权限 fail closed，不自动申请升级。
- 动作显式目标、固定参数映射，串行运行；ACK 不代表业务成功；不会自动重试超时动作。

## BDD / 验收

1. Given 已安装 CLI，When 查询 version / 指定命令 schema，Then 返回单个原始 JSON 与退出事实，不执行 shell。
2. Given 明确 platform/target，When 查询现状或调用 tap/type/press/swipe，Then 仅生成白名单 argv；未知字段、缺失目标、恶意选项值及非法数值在 spawn 前拒绝。
3. Given 低权限、取消、超时、缺少 CLI、非 JSON、截断或非零退出，Then 返回可机器读取失败，保留原始 payload / code 与进程退出信息，不伪造成功或重试。
4. Given 插件加载/卸载，Then 注册/释放工具；卸载取消活跃请求；配置默认值、环境变量覆盖、非法值有测试。
5. Given 完整 bundle，When 本地安装，Then DSH 发现四个工具和中英 metadata / 原创 SVG；真实 version/schema/status smoke，不触发 mutation。

## 验证计划

先失败测试再最小实现；新Node插件/分发与匹配契约验收，真实设备动作与Swift全量另行声明。首轮基线只登记到255，编号失败日志保留为历史；本轮重放到最新远端main后已有完整登记，278个space和ci-docs通过，没有放宽校验或回灌其他WIP。

## 交付与证据

- [使用与安装](../../../DSH/README.md)：`@neptunekit/dsh-tritonkit-host@0.1.1`，四个受限工具；当前profile已正式重装，application=applied，新namespaced目标guard真实无派发负例与版本读取通过。
- [当前整合验收](plans/20261109-integration-validation.md)：Node **32/32**、278个space结构、完整ci-docs及分类/版本/skill/release/Homebrew契约通过；精确合并提交f4efd202已推送远端main，两条CI通过，见报告链接。
- [首轮历史报告](plans/20261109-validation.md)：0.1.0的Node29/经验28、只读接线与原始编号失败记录，不作为0.1.1候选结论。
- [当前包hash](plans/20261109-package-v0.1.1-verification.json)：实际npm pack/tar恰含8文件；源码资源与files声明均有回归。
- 本地可安装归档为 `DSH/dist/neptunekit-dsh-tritonkit-host-0.1.1.tgz`（构建产物，不随Git提交）；profile为目录link安装，保留本worktree，勿删除或移动。
- [架构与经验](../../dev/dsh-plugin-integration.md)：权限重检、range退出、命名空间目标、严格后端null参数、CLI错误与副作用边界。GUI认证限制及真实动作/Swift全量未验边界保持。
