# SP-152 · Issue #172 iOS embedded runtime re-registration

## 状态

- 阶段：已完成（总集成候选，待 PR/CI）
- Issue：#172
- Branch：`feat/SP-152-issue-172-runtime-reregistration`
- Worktree：`../TritonKit-worktrees/SP-152-issue-172-runtime-reregistration/`
- 影响层：iOS embedded Swift runtime WebSocket 生命周期、CLI serve 兼容诊断、CLI doctor 机器可读恢复建议

## 问题与边界

现有 embedded runtime 的 reconnect 延迟任务没有被保存到 `reconnectTimer`，因此 stop、重新 start 或新连接都无法取消旧任务；WebSocket receive completion 也没有绑定连接代次，旧 task 的迟到失败可能把新连接改回 disconnected，并再次调度重连。0.2.15 与 0.2.16 tag 上这段实现相同。

本期只修复 embedded WebSocket 连接代次、重连调度与 server/doctor 诊断契约。默认只使用 fixture/unit tests，不启动或停止共享 server、Simulator 或私有 App。不触碰 Xcode workflow、real-device parser、Web UI 或 release/tag。

## BDD 场景

### 场景 A：重装或 App 新进程重新注册

- Given 旧进程的连接及延迟重连尚可能回调
- When 新进程调用 `start` 并建立新的连接代次
- Then 新代次可独立进入 connecting/connected
- And 旧代次的 receive、ping 或重连回调不能覆盖新代次状态

### 场景 B：断连后有界重连

- Given 当前连接发生 receive 或 ping failure
- When auto reconnect 开启
- Then 同一时刻最多保留一个 pending reconnect
- And stop、manual restart 或成功连接会取消 pending reconnect
- And 重连回调只对创建它的连接代次有效

### 场景 C：0.2.15 embedded SDK 对 0.2.16 server

- Given 0.2.15 runtime 没有单独 registration frame，但能响应既有 `ping`、`appInfo`、`hierarchy` 与 `runtimeManifest`
- When 0.2.16 server 接受 WebSocket 并执行兼容探测
- Then server 保持 legacy-compatible，不以缺少新 registration frame 拒绝旧 SDK
- And 兼容状态或稳定拒绝原因可通过机器可读诊断模型测试

### 场景 D：server 可达但没有 runtime target

- Given server reachable 且 target count 为零
- When agent 运行 doctor
- Then doctor 明确无法仅凭 server 事实证明 App 是否已启动
- And 同时给出 target list、runtime connection diagnostics 与 App DEBUG bootstrap/endpoint 核对动作，而不是只建议“启动 App”

## 验收

1. 用 deterministic lifecycle tests 证明新连接代次不受旧 task/timer completion 影响。
2. 用 unit tests 证明 reconnect 单飞、可取消、代次有界。
3. 用 CLI server compatibility fixture 证明 legacy 0.2.15 行为被接受，未知/不兼容协议返回稳定机器码和原因。
4. 用 doctor contract test 证明 no-target 诊断包含“无法证明 App 已启动”的边界与多条恢复检查。
5. focused tests、相关 package tests 与 `git diff --check` 通过；docs 检查若受并行 space 编号尚未集成影响，记录原始失败与集成条件。若不运行真实 App/Simulator，明确保留动态风险。

## 当前证据

- `git diff v0.2.15..v0.2.16 -- Sources/TritonKit/TritonKit.swift`：连接/重连实现无变化。
- 当前 `scheduleReconnect()` 使用未持有的 `DispatchQueue.main.asyncAfter`，而 `reconnectTimer` 从未赋值。
- 当前 receive completion 直接读写共享 `task`/`state`，没有 connection generation/token 检查。

## 实现结果

- embedded runtime 新增线程安全的 connection generation 生命周期；旧 receive、ping、send completion 和 pending reconnect 只能作用于创建它们的连接代次。
- reconnect 改为可取消的单飞 `DispatchWorkItem`；`stop()`、manual restart 或新连接建立会使旧重连失效。
- server 在 WebSocket 建连后主动请求既有 `runtimeManifest`，并以稳定的机器码接受 legacy manifest 或记录拒绝原因；没有引入 0.2.15 不认识的新 registration frame。
- `/runtime/registrations` 返回稳定 envelope；没有观测到 runtime 时返回 `runtime_registration_unobserved`，有效 legacy runtime 返回 `runtime_registration_available`。
- doctor 的 no-target 检查明确区分“server 可达”和“App/runtime 已注册”，建议依次核对 target list、DEBUG bootstrap、runtime enablement 与 host/port。

## 验证结果

- red：`swift test --scratch-path .build/sp152-root-red --filter TKRuntimeConnectionLifecycleTests` 因 `RuntimeConnectionLifecycle` 不存在而编译失败。
- red：CLI fixture 首次编译因 `runtimeRegistrationDecision` 不存在而失败。
- green：root lifecycle focused tests 3/3 通过；root 全量 236 tests / 28 suites 通过。
- green：`ServeCommandTests|ServerTargetSelectionTests` 13/13 通过（含 legacy runtime 不响应 manifest 仍保持 accepted）；doctor recovery contract 定向 1/1 通过。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 未通过：当前隔离分支从 `SP-141` 直接登记 `SP-152`，检查器要求编号连续。`SP-142` 至 `SP-151` 属并行 space 集成依赖，本分支不越界创建或迁移它们。
- `SchemaFactSourceTests` 中 doctor 新用例通过；该 suite 仍有与本期无关的既有 schema contract 基线失败（12 个失败测试、13 个 issue），本期未修改对应契约。

## 保留风险

- 0.2.15 wire manifest 将 `sdkVersion` 固定报告为 `0.1.0-dev`，因此只能验证 legacy contract 兼容，无法仅凭 wire payload 证明二进制确切来自 0.2.15；响应中以 `versionSource` 显式标记未验证版本来源。
- 按隔离约束未启动真实 server、Simulator 或私有 App；真实重装/进程重启的动态证据需在主线集成后用公开 fixture App 或授权环境补充。

## 停止条件

- 必须依赖私有 App/设备才能确定协议语义；
- 修复需要越界修改 Xcode、real-device parser、Web UI 或其它 issue 文件；
- 同一验证命令连续失败三次且无法从本地 fixture 定位。
