# Round 11: Doctor Recovery Checks

## 目标

将 `triton doctor --json` 从复用 capabilities 输出改成独立诊断响应，使 agent 能按顺序读取当前阻塞点、稳定诊断码、恢复命令和关联能力。

## 完成结果

- 新增 `TKDoctorCheck` 与 `TKDoctorResponse` 共享模型。
- `doctor` 输出模型切换为 `TKDoctorResponse`，核心字段为 `ok/serverReachable/connected/runtime/nextStep/checks[]/error`。
- `checks[]` 每项包含 `id/status/code/message/hint/nextAction/relatedCapabilities`。
- 新增 `buildDoctorResponse`，基于 capabilities 生成恢复检查：
  - server 不可达：`start-server` fail + `serve --host ... --port ...`。
  - server 可达但 runtime 未连接：`connect-target` fail + `target list --json`。
  - runtime 已连接：server、target、runtime pass。
  - action surface 受限：当前 `press` unsupported 时返回 warn，并指向 `capabilities --json`。
  - plan readiness：返回 `plan` pass。
- 更新 `triton schema --command doctor --json` 的 output contract，显式暴露 `doctor` selector 与 `checks[]` 字段。
- 更新 dev 文档与 public skills，明确 doctor 负责有序恢复诊断，capabilities 负责环境能力矩阵。

## 验收场景

1. 无 server 时，`triton doctor --json` 返回合法 JSON、`nextStep=start-server`、`checks[0].code=server_unavailable`、`nextAction.command=serve`。
2. connected capabilities 下，doctor 返回 server / target / runtime pass，并对当前 unsupported `press` 给出 action surface warn。
3. schema 能发现 doctor 输出契约，不再把 doctor 描述成 capabilities response。

## 已运行验证

- `swift test --package-path CLI --filter SchemaFactSourceTests` 通过，11 个 Swift Testing 用例通过。
- `swift test --package-path CLI` 通过，82 个 Swift Testing 用例通过。
- `swift test` 通过，126 个 Swift Testing 用例通过。
- `swift run --package-path CLI triton doctor --json` 通过，无 server 环境下返回合法 JSON、`nextStep=start-server`、`checks[]` 和 `nextAction.command=serve`。

## 后续队列

- Round 12：继续收敛 `action` 层，优先让 action schema / capabilities / doctor 的 unsupported 与恢复建议保持一致。
- 后续可把 `doctor` 的 host tool / artifact output / project defaults 检查继续细化，但不引入 Web 或服务端新产品面。
