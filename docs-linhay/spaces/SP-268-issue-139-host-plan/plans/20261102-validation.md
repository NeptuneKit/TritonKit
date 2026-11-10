# SP-268 验证记录

## 影响层与事实

CLI plan 路由和 schema；不改变 app.open-url / smoke / wait 的执行实现。原 #139 general host 修复不自动覆盖 open-url；#31 deferred 参数反例在本切片使用已有 host smoke 合约解决。

- RED：未改实现的 warm CLI，`plan open-url --platform harmony --device __audit_no_device__ --bundle com.example.audit --ability EntryAbility --hap '/fixture/candidate file.hap' --url 'example://audit?id=1&mode=2' --text Ready --evidence '/fixture/evidence dir' --host 127.0.0.1 --port 28771 --json`。
- 实际返回 `nextStep=start-server`，主步骤含 `xcode run`，afterRecoverySteps 为 iOS `app go`/runtime wait/verify/evidence，未保留 Harmony lifecycle 参数。断言 `nextStep == device-doctor` exit 1。原始 JSON 保留 worktree `.build/sp268/baseline-harmony.json`。
- 最小实现：显式 Android/Harmony open-url 在 embedded bootstrap 之前路由。Harmony 可选 HAP install + 一次 host smoke，保留 argv；Android 提供已有 host open-url/wait/screenshot，请求 evidence 时返回明确 unsupported_capability，不能猜 package，也不能用 embedded evidence 伪装完成。
- `git diff --check`：通过。
- Swift RED/GREEN 与真实 CLI 候选 smoke：交由主控串行 warm 构建验证，尚未回报。

## 可重复验证

- `swift test --package-path CLI --no-parallel --filter HostGoalWorkflowPlanTests`
- `python3 docs-linhay/spaces/SP-268-issue-139-host-plan/plans/verify-readonly-plan.py <candidate-triton> .build/sp268/candidate`
- 既有 workflow/plan/schema 契约回归由主控合并门禁执行。

只读 CLI 脚本使用保留但不监听的临时 loopback port，覆盖 general/open-url × Harmony/Android，不启动服务、不操作设备、不执行生成命令；所有 command 与独立 argv 经 shlex round-trip。server reachable true/false 矩阵由纯构造器单测覆盖，不将 fixture 当真实 App 完成。

## 能力边界与经验

Plan 成功表示命令序列构造成功，不证明 target.ready、安装成功或业务完成；placeholder 必须执行前替换。Android plan 没有 package 参数，iOS bundle-id 与 Harmony bundle/ability 不得猜作 Android 包名。host plan 必须按目标执行链选择 primitive，不能仅修 general 分支而漏 goal-specific 路径。原私有 App 验收不在本切片范围，已有未知证据不改写。

本切片无 Git 写入、无共享构建、无设备操作。索引/memory 由主控统一写回。

## 主控整合验证

8 项 HostGoalWorkflowPlanTests 通过，日志 `archives/SP264/issue139-green.log`。实际 CLI 对 Harmony/Android × general/open-url 四场景均通过（`.build/sp268/candidate-rerun/`），保留无监听端口、独立 argv、禁止执行生成命令的边界。初次 fixture 误用显式 `plan general` 返回 validation_failed 的原始记录保留 `.build/sp268/candidate/`；修正为无 action 入口后复验，不计为产品缺陷。

独立最终审阅未发现P1/P2；PR264精确head `84b591600b00e602835f70c5df62679bc4519945` CI通过，合入main `8d897df399002b7cb341ff8fe40a6f9d66a316e2`。
