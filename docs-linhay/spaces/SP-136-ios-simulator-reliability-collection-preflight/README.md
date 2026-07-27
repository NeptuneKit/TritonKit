# SP-136 iOS Simulator Reliability Collection Preflight

## 状态

- 状态：已完成（本地 checkpoint）。
- 负责人：Codex。
- Branch：`feat/SP-136-ios-simulator-reliability-collection-preflight`。
- Worktree：`../TritonKit-worktrees/SP-136-ios-simulator-reliability-collection-preflight/`。
- 基线：`feat/SP-135-testrec-compatibility-guidance@107eac45`。

## 裁决

**Adopt：先冻结真实 3 flow × 20 collection 的前置合同，不自动采样。**

SP-134 已提供只读 reliability gate，却没有可安全复用的生产采样器；SP-135 又明确 simulated testrec 输出不能成为 reliability sample。本 space 新增 `triton test reliability-preflight --collection <private.json> --json`，只验证 operator 私有 collection 是否已经冻结为可受控采集的布局。

成功的 `ready_to_collect` 只表示离线输入合同完整，固定声明它不是 reliability gate verdict，也不表示任何 Simulator、server、App、reset 或 evidence 已实际执行。真实 3 × 20 收集仍需另立 live harness space，并持有专用 Simulator、self-managed loopback server、逐样本 reset receipt 和全新私有 evidence。

## 边界

包括：

- 仅离线读取 private collection JSON 与三条 `.tritontest.yaml`；验证 imported provenance、`ios-simulator`、retry=0、冻结 normalized-plan digest、canonical `triton:ios-simulator:<UDID>/app:<bundle>` target tuple/binding digest、每 flow 20 个独立 slot、一个 plan digest 不得复用 supported flow 的独立 negative control，与尚未创建的新鲜 evidence root。
- 输出只含匿名 flow alias、digest、计数、status 和稳定契约，不回显私有路径、UDID、bundle、selector、flow ID、reset recipe 或 visible text。
- 为 `test reliability-preflight` 增加 CLI/schema/output contract/capability/next-action，并补齐既有 reliability-gate capability 与 output-kind taxonomy 的连接缺口。

不包括：

- 启动或查询 server、Simulator、Xcode、target、App、`test run`、testrec replay 或任何真实 device action。
- 创建、删除、重置、写入或伪造 `.tritonevidence`、sample manifest、reset receipt 或 passed gate。
- 新增 collection runner、workspace 接入、第二 executor、Android/Harmony/Web/Wails/真机能力，或读取/修改 #164 WIP。

## BDD 验收

1. Given 私有 collection 声明三条带 `triton.testrec.compiled-contract` provenance 的 `ios-simulator` plan、每条 20 个唯一 slot、一个独立 negative control、显式 canonical `triton:ios-simulator:<UDID>/app:<bundle>` tuple/binding digest 和尚未创建的 evidence root，When 运行 `test reliability-preflight`，Then 只返回 `ready_to_collect`、匿名 flow alias、冻结 plan digest 与计数；它明确不是 reliability gate verdict。
2. Given `local` / `booted` / alias target、binding digest 不匹配、非 imported/non-Simulator/retry plan、plan digest 漂移、少于或多于三条 flow、非 20 slot、重复 ID/slot/evidence、negative control 复用 supported plan、既存或非直接布局的 evidence output、缺 reset/initial-state/negative-control contract，When 预检，Then 单一 JSON failure envelope fail closed，不回显私有输入，也不写文件。
3. Given collection 内含私有路径、UDID、bundle、selector、flow ID、reset recipe 与 negative-control ID，When 编码成功或失败 JSON，Then stdout 中都不出现它们；preflight 不创建任何 evidence 或 receipt。
4. Given `triton schema --command test --json` 与 `triton capabilities --json`，When agent 查询能力，Then `test-reliability-gate` 和 collection-preflight 都是 offline test capabilities，并指向只含占位符的下一步，而不是启动 runtime。
5. Given 既有 `triton test reliability --samples <private.json>`，When 新命令加入，Then 旧 report schema、gate 计算和 `--samples` 入口不改变。

## 验证与停止条件

- 先写 collection parser/privacy/schema/capability 的失败测试；最小实现后运行新 suite、`TestReliabilityRuntimeTests`、schema/capability focused suites、release CLI/schema、`git diff --check` 与 docs gate。
- 只使用本 space 独立 Swift scratch；不运行 `verify.sh --local`，因为它会进入与本 slice 不相干的动态 lane。
- 若需要自动 boot/reset/选择 Simulator、启动/复用 server、写 evidence、扩展 test runner 或把 `ready_to_collect` 当成 gate pass，立即停止并新建 live harness space。

## 完成证据

- TDD：先补齐 collection/private-output/schema/capability 的失败测试；终审发现的 negative-control plan 复用与 error-envelope schema 形状缺口，也分别以失败测试复现后最小修复。
- focused green：`TestReliabilityCollectionRuntimeTests` 4/4、`TestValidationTests` 14/14、`TestReliabilityRuntimeTests` 25/25、`TestImportTests` 11/11、`SchemaFactSourceCapabilityTests` 22/22、`FailureDiagnosticsTests` 13/13。
- release：独立 release scratch 成功构建 `triton`；`test reliability-preflight --json` 缺 `--collection` 时只输出一个 `missing_required_field` JSON envelope 且 exit 1；release `schema --command test --json` 已断言 subcommand、output selector、capability 与两类 failure shape。
- 文档与格式：`git diff --check`、`docs-linhay/scripts/check-docs.sh`、`docs-linhay/scripts/verify.sh --ci-docs` 通过。
- 已知非本 slice blocker：广义 `SchemaFactSourceContractTests` 仍有 6 个既有 `device/sim` registry failure，`SchemaFactSourceWorkflowTests` 仍有 4 个既有 `device/network-proxy` argv failure；本 slice 新增的 output-kind、capability 与 subcommand 检查均通过，未在此离线 collection slice 扩修。
