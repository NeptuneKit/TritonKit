# SP-278 · TritonKit DSH 插件

## 状态与边界

2026-11-09：首版实现与本地安装验收完成。13:02用户追加授权“验证，提交，合并，推送”；正在以最新远端main独立整合，仅纳入本插件，不夹带本地主目录15条无关提交或原有WIP。首轮旧基线文档编号失败、真实动作与GUI展示未验的边界见验收报告，后续提交/整合证据另行写回。

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

先 Node 内置 test runner 失败测试，再最小实现；不新增外部依赖。验证包含配置、argv 安全、JSON/退出语义、取消/超时、串行与 unload、manifest 打包面、真实只读 CLI 和已安装 DSH 工具。文档运行 `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`。既有索引只登记至 SP-255，而其他注册 worktree 占用 SP-256～277；本轮使用 SP-278，不回灌其他 WIP 或放宽连续编号门禁，若因此阻断如实记录。

## 交付与证据

- [使用与安装](../../../DSH/README.md)：`@neptunekit/dsh-tritonkit-host@0.1.0`，四个受限工具；当前 profile 最终 `application=applied`。
- [验收报告](plans/20261109-validation.md)：Node **29/29**、经验测试 **28/28**、语法/diff通过；已安装工具真实version/schema/status及未知schema错误透传通过，均cleanup confirmed。
- [包与来源hash](plans/20261109-package-verification.json)：tarball恰含8个预期文件，无依赖/安装脚本；中英metadata/原创SVG静态校验通过。
- 本地可安装归档位于 `DSH/dist/neptunekit-dsh-tritonkit-host-0.1.0.tgz`（构建产物，不随Git源码提交）；当前profile是目录link安装，保留本worktree，勿直接删除或移动。
- [架构与经验](../../dev/dsh-plugin-integration.md)：权限重检、range退出、动态目标、严格后端null参数、CLI错误与副作用边界。
- 文档结构和ci-docs均因255→278编号缺口exit1，未放宽检查；主目录既有WIP未混入。GUI认证限制、真实动作及未运行Swift全量门禁详见报告。
