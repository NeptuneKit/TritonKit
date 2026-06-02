# Round 180 - short app go deeplink entry（2026-06-02）

## 背景

- 真实使用中，iOS deep link 验证命令过长：`triton app open-url <url> --device <selector> --wait-ready --snapshot --json`。
- 对 agent 来说，`wait-ready + snapshot + json` 是常用安全模式，不应要求每次显式拼出。

## 变更

- 新增短入口：`triton app go <url>`。
- `app go` 默认执行 iOS `open-url + wait-ready + snapshot`，并保持 JSON 为默认输出。
- `app go` 的 target 选择顺序：显式 `--device/--simulator`、当前 target、唯一 ready iOS target。
- `triton plan open-url` 和 capability `nextAction` 首选 `triton app go <url>`，不再推荐长 `open-url --wait-ready --snapshot --json`。
- `--json` 可省略：schema 默认 `--format=json` 被纳入机器可读门禁，不再强制对默认 JSON 命令追加显式 `--json`。

## 用户可用命令

```bash
triton device use sim:60667794-96F8-40E6-8664-85538EC4663E
triton app go "dxy-jobmd://nativejump/test/talentMoreFilter"
```

若不想写 current target，也可保留显式 selector：

```bash
triton app go "dxy-jobmd://nativejump/test/talentMoreFilter" --device sim:60667794-96F8-40E6-8664-85538EC4663E
```

## 验证

- `swift build --package-path CLI --product triton` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityGroupsKeepMachineReadableNextActionOutputFlags` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/capabilityNextActionsStayAlignedWithCommandSchemas` 通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlansExposeExecutableCommandSequences` 通过。
- `swift test --package-path CLI --filter DeviceCrossPlatformTests/appAndSmokeSchemasExposeUnifiedDeviceSelector` 通过。
