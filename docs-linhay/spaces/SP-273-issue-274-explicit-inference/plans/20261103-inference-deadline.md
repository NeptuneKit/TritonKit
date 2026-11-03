# SP273 inference deadline implementation handoff

## Requested

Issue #274 的明确启用之后的模型调用仍须有界：覆盖在线 POST 总时限、helper 超时/资源错误/管道 EOF。仅隔离 URLProtocol 与本机脚本 stub，不调用真实模型、在线推理或模型下载。

## Observed

- 新共享 `postAIJSON` 保留生产 30 秒总 wall deadline，超时 cancel；回调结果用 NSLock 保护，即使调用返回后 late callback 到达也不读取无锁共享变量。VLM 调用已替换；workspace owner 独立替换 LLM，保留各自 HTTP 状态码错误。没有 retry/fallback。
- MLX ground/download 复用 `runHostCommand`，并发 drain、stdout/stderr 各 1 MiB 缓冲，拒绝截断 stdout；typed launch/generation/download 错误保持。未增加进程组 kill 或私有后代扫描。
- 默认启用/配置/runner 旁路由另一 owner 处理。本子任务不改 CLIWorkspace*、版本、文档或设备现场。

## Evidence

- 基线：`9578782a7cbfd855228f8e996b07d93437725870`。独立源码审计在 `../SP272/issue274-independent-audit.md`。
- RED 等价抽取旧 POST（只有 session/deadline 参数用于fixture，仍无总waitdeadline）+原 helper 源码：`inference-red-reliable-pid.log`，9 tests / 8 issues。慢滴 0.661s 超过 0.15s预算；大日志堵管道；忽略TERM的直接 helper 在 timeout 返回后 PID 仍存活；ground/download inherited pipe分别约2.05/2.26s。
- 首轮 RED 的 TERM fixture 用0.15s短于Perl启动，PID文件未生成，不计为产品证据；原记录 `inference-red.log` 保留。改0.6s后可靠RED证明真实存活。所有stub自结束，另有外层watchdog及owned PID finally清理，watchdog未触发。
- GREEN：`inference-green.log`，28 tests / 7 suites passed（含9新增与19既有VLM/cache/compare/MLX用例）。慢滴0.154s、TERM-ignore2.611s且directPID退出、ground EOF0.312s、download EOF0.540s；日志大于pipe容量成功，resource stderr/exit42保持失败。
- 命令：`swift test --package-path CLI --scratch-path <SP271>/CLI/.build --skip-build --no-parallel --filter 'InferenceDeadlineTests|InferenceHelperDeadlineTests|VLMMlxSwiftLMProviderTests|VLMModelCacheTests|VLMProviderComparisonTests|VLMGroundingTests'`，`TRITON_CLI_PATH=<same scratch>/out/Products/Debug/triton`。
- 先由 workspace owner 独占构建同联合候选并完成其focused GREEN，再交本agent执行上述测试。scratch全程串行。已交还主控构建锁。
- `git diff --check`通过。精确6文件内容绑定 `inference-candidate-hashes.json`，fileSetSHA256=`8bb528b68e1cb00fd08c8c6d8b0b934a515ab44ad835d882e1256506a283e9c4`。冻结后未改源码/tests，不创建Git提交。

## Gaps

完整CLI/发布preflight/CI/制品验收由主控继续；本结果仅为上述聚焦层通过。未进行真实模型推理、实际下载、真实在线API或低内存设备验收。

## Remaining risk

- helper execution timeout仍ground120s/download3600s，其后另有最多4s TERM/KILL收尾与0.25s EOF drain预算；不能将execution timeout等同全部返回时间。
- 仅直接helper经既有termination流程；任意未知后代不会全局终止。测试自己fork的后代由fixture清理，不等于产品接管所有进程树。
- 在线transport沿用URLSession dataTask响应buffering，没有新增流式总响应容量上限；总时限通过不证明任意响应体低内存安全。
- 经验已交host_plan/主控写回既有MLX skill及CLI契约，重点是inactivity≠wall deadline、wait-before-drain/EOF与直接进程退出需分别验收。本agent没有越权改共享文档。
