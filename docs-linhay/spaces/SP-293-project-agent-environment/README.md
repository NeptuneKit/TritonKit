# SP-293 项目 Agent 环境整理

## 边界

依据用户级 AGENTS 整理仓库的维护规则、客户端接线、内部 skill 和现行资料。沿用 [SP-198](../SP-198-agent-experience-loop/README.md) 的经验闭环与门禁。仅在当前 `main` 改项目资料与离线文档检查，保留已有 DSH 与共享文档差异。开工基线 `af4da24f25ba5b6a73a9213a16b016bd35c33767`。

## BDD 与验收

1. Given 已读取使用者自己的 AGENTS 和个人偏好，When 打开仓库规则，Then 能直接定位项目约束、内部 skill、契约和经验索引，回复规范与个人偏好各只维护一份。
2. Given 从普通 Git checkout 启动 Claude Code，When 解析根 `CLAUDE.md`，Then 读取同目录 `AGENTS.md`。文档门禁对缺失、Finder Alias 二进制和无效导入分别失败。
3. Given 按内部治理 skill 选择 HTTP、Swift 或发布检查，When 对照 manifest 和现行 CI，Then 入口和适用范围与真实实现一致，归档仍可追溯。

## 状态

2026-11-16，在当前 `main` 完成本地整理与验收。按用户要求独立提交，四份共享文档只纳入本 Space 的段落。

- [项目 AGENTS](../../../AGENTS.md) 保留项目规则，把全局回复与个人偏好交回全局入口。旧跨项目通用规则表改为权威入口链接。资料归属、客户端接线与 [内部 skill 入口](../../../.agents/skills/README.md) 已归入 [项目治理](../../dev/20260619-agent-workflow-skill-governance.md)。
- [CLAUDE.md](../../../CLAUDE.md) 从 Finder 别名改为一行 `@AGENTS.md`。旧文件在第 42 字节 UTF-8 解码失败，原文档检查仍放行。现有文档门禁覆盖缺失、二进制、越界 symlink、错误导入及代码块示例五类负例，这些负例在旧校验逻辑上均触发了断言失败。
- [治理 skill](../../../.agents/skills/tritonkit-ops-governance/SKILL.md) 与 [发布契约](../../dev/20260519-github-ci-release-artifacts.md) 对齐 HummingbirdTesting、根包串行测试、只读 Device Hub 及 arm64/SwiftPM 发布。Xcode 引用改指已有研究，历史发布记录保留。

## 验证

- macOS 27.0.1，Python 3.14.3。文档门禁覆盖 293 个 Space 和 33 个入口用例。`verify.sh --ci-docs`、独立 `check-docs.sh` 和 `git diff --check` 通过。12 个内部 skill 的元数据及索引链接、12 个 Codex 角色 TOML、项目配置与 Claude 本地 JSON 均通过解析检查。
- Claude Code 2.1.312 使用两个独立临时 Git 目录、独立配置和本地模型响应桩启动，命令为 `claude --setting-sources project --strict-mcp-config --tools '' --no-session-persistence --model claude-haiku-4-5 --print 'Offline import probe.'`。文本入口产生一条 `AGENTS.md/include` 事件，父文件为 `CLAUDE.md`，loopback 请求中的规则全文逐字匹配且仅出现一次。旧 Finder 别名对照同样退出 0，产生零条 AGENTS 导入事件，请求中无规则内容。未调用真实模型。
- 本轮核对范围是项目资料、入口和离线门禁。产品测试、远端 CI 和发布未执行。Claude 本地覆盖仍采用现有受跟踪配置，未迁移应用权限。
