# 20260622 Test Recorder Replay

## Space 目标

定义一个面向测试的 TritonKit 产品面：录制一端真实执行中的动作、网络数据和页面状态，经过 LLM / VLM 辅助编译后生成测试合同，再在多端回放并产出可审计证据。

核心一句话：**一端录制合同，多端证据化回放**。

## 当前产品判断

1. 录制产物不是最终测试，而是原始流；必须先编译成测试合同。
2. 测试合同不是死脚本；跨端回放时需要 VLM / LLM 辅助迁移。
3. VLM 可以按界面元素生成页面匹配指纹，作为 page-level replay evidence。
4. Fingerprint 匹配度由 deterministic matcher 评分；LLM 只做边界解释和候选映射，不能直接判 pass。
5. Web 主体验不是无限画布，而是 test plan workspace + rendered surface + page-level inspector + evidence drawer。
6. Web 只做只读展示和分析；业务控制仍优先通过 CLI / HTTP 管理 API。
7. 本需求已经暴露出下一层抽象：Agent Runtime / Semantic Contract；但 P0 不提前抽 Runtime，先把 Test Recorder 的 `.tritontestcase`、inspect、compile、replay 打通。
8. Action Map、Page Map、Network Map 暂作为 Test Recorder 内部合同能力落地；等 replay 真实跑通后，再新开 `2026xxxx-agent-runtime` space 抽象 Triton Runtime Contract。

## 文档索引

- [Product Requirements v01](./plans/20260622-product-requirements-v01.md)：竞品观察、测试合同、LLM / VLM 编译、VLM 页面指纹、CLI / HTTP route、Web 信息架构、BDD、验收标准。

## 产品范围

Include：

- 动作流录制与回放合同。
- 网络流 capture、map、fixture、mock / passthrough / block / throttle 策略。
- 页面流 route、AX / DOM / semantic snapshot、screenshot、VLM fingerprint。
- LLM / VLM 辅助合同编译与跨端回放迁移。
- `.tritontestcase` 目录包、`.tritonevidence` 回放证据、run report。
- 独立 CLI namespace：`triton testrec ...`。
- 独立 HTTP route：`/v1/test-recorder/...`。
- 可选只读 Web mock route：`/test-recorder`。

Exclude：

- 不做云端设备农场、远端 agent、多人协作平台或 SaaS Dashboard。
- 不要求首期支持真机。
- 不绕过 TLS pinning、QUIC、自定义 socket、私有加密协议或系统安全策略。
- 不默认注入业务 App 网络 interceptor。
- 不用 Web/Wails UI 定义业务控制契约。
- 不让 LLM / VLM 单独决定测试是否通过。

## P0 建议切片

1. 定义 `.tritontestcase` schema。
2. 定义 `contract-capabilities.json`，提前表达 action / page / network 能力矩阵，为未来 Runtime Capability Model 留接口。
3. 实现或先设计 `triton testrec inspect <case> --json`。
4. 实现或先设计 `triton testrec compile <case> --json`，把原始流编译成合同。
5. 实现或先设计 `triton testrec replay <case> --platform <target> --json` 的最小单端回放合同。
6. Web mock 暂不进入 P0 主线；如需展示，只做只读 DTO mock，不阻塞 CLI / HTTP 合同打通。

## 当前停止点

产品需求讨论到此冻结。下一步不继续扩需求，直接进入 P0 schema / DTO 设计、`inspect` focused tests 和最小实现验证。

## 当前实现进度

- replay dry-run 与 replay-result 已新增 contractRef：记录 compiled-contract.json 的 path、byteCount、digestAlgorithm 与 deterministic digest；写入 evidence bundle 的 run/replay-result.json 保持同一 contractRef，后续真实 executor 可以证明“本次回放跑的是哪一份合同”。
- replay evidence events 已同步 contractRef：run/events.jsonl 中 started / page / network / step / finished 每条事件都写入同一 contractRef，单独审计事件流时也能证明事件属于同一份 compiled contract。
- evidence manifest artifacts 已同步 contractRef metadata：manifest.json 中 replay-result / events / run 三个 artifact 都带同一 contractRef，manifest、result、events 三方可交叉验证合同身份。
- testrec command schema 已补 artifacts：tritontestcase、contract-capabilities、compiled-contract、action-map、page-map、network-map、compile-proposals、evidence-bundle 均可从 schema 发现；start / event / stop / compile / replay 子命令也声明各自会写的主要 artifact。
- replay dry-run 已补 executorProfiles[]：当前 local-simulated 标记为 available，local-device 标记为 unsupported，并把真实设备回放缺失的 live-target-device / device-action-execution / evidence-artifact-capture / network-policy-application requirement 明确暴露给 agent；这保证 dry-run 能先回答“哪些 executor 可用、哪些 executor 只是未来能力”，而不是让 agent 误以为 non-dry-run 已经具备真实设备执行。
- schema output contract 已固定 executor requirement status taxonomy：satisfied / missing / optional / not-required / simulated / not-present / not-requested。dry-run executorProfiles 与 replay-result execution.executorRequirements 使用同一组状态词，后续真实 executor 只能扩字段或新增版本，不能让 agent 依赖分叉语义。
- 已新增独立 CLI namespace：`triton testrec start/event/stop/inspect/compile/proposals/replay`。
- 已新增 P1 源端录制 MVP 的显式事件闭环：`triton testrec start --platform <platform> --case <name> --output <case.tritontestcase> --json` 初始化 case 与本机 session，`testrec event --session <id> --kind <kind> --payload-json <json> --json` 追加 action / network / page JSONL，`testrec stop --session <id> --json` 汇总 artifact presence；当前不做全局输入监听、不连接设备、不调用 HTTP server。
- 已新增本机 HTTP 管理 API 的显式事件与 case 操作薄封装：`POST /v1/test-recorder/sessions`、`POST /v1/test-recorder/sessions/{sessionId}/events`、`POST /v1/test-recorder/sessions/{sessionId}/stop`、`POST /v1/test-recorder/cases/inspect`、`POST /v1/test-recorder/cases/compile`、`POST /v1/test-recorder/cases/proposals`、`POST /v1/test-recorder/cases/match-page`、`POST /v1/test-recorder/cases/replay-dry-run`、`POST /v1/test-recorder/cases/replay`，与 CLI 共享同一 .tritontestcase/session/compile/page-match/replay dry-run / local-simulated replay 逻辑；当前只接收调用方提交的结构化事件、target-side fingerprint 或本机 case path，不做系统级动作监听、设备自动采集、case registry 或 run registry。
- 已落地 `.tritontestcase` P0 最小目录合同：`manifest.json` + `contract-capabilities.json`。
- 已新增 `triton testrec compile <case.tritontestcase> --json` 的离线 deterministic compiler：读取原始流并输出 action / network / page 计数、status 与 warnings；当输入完整时写入 `compiled-contract.json`，其中包含 semantic actions、network requests、page routes、page fingerprints，并标记 `llmUsed=false`、`vlmUsed=false`，不执行设备动作。
- compile 已新增 deterministic Action Map 产物：当存在 `actions.jsonl` 时写出 `actions/action-map.json`，按 source action 生成 semantic target、strategy、review / redaction flags 与 evidence；该文件是后续跨端 replay executor 的动作映射输入，当前不执行设备动作，也不让 LLM 直接改写 action contract。
- compile 已新增 deterministic Page Map 产物：当存在 page route 或 fingerprint 时写出 `pages/page-map.json`，按 route / pageId 合并页面身份，记录 `routeSourcePath`、`fingerprintSourcePath`、`fingerprintHash` 与 evidence 列表；该文件面向只读 Inspector / agent 消费，不定义 Web 控制面。
- compiled contract 已包含 page fingerprint match policy：`scorer=deterministic-fingerprint-matcher-v1`，阈值为 `matched=0.82`、`assistedMatched=0.70`、`needsReview=0.55`；`llmDecisionAuthority=false`，明确 LLM 只能解释边界样本和生成 alias/proposal，不能直接判定页面匹配 pass/fail。
- 已新增 `triton testrec match-page <case.tritontestcase> --page <page> --candidate-json <json> --json`：读取 `compiled-contract.json` 中的 source page fingerprint，用 deterministic matcher 对 target-side candidate fingerprint 评分，输出 `score`、`decision`、component evidence、`llmUsed=false` 和 `llmDecisionAuthority=false`；当前只做 page-level matching evidence，不执行真实回放，也不调用 LLM/VLM。
- compile 已新增 deterministic Network Map 产物：当存在 `network/capture.ndjson` 时写出 `network/map-rules.json`；普通业务请求先标记为 `mock-candidate` 且 `redactionRequired=true`，偶发/analytics 请求标记为 `passthrough` 且 `nonBlocking=true`；当业务请求带 response body 时，会写出 `network/fixtures/<id>.json` 脱敏 fixture，并通过 rule.fixturePath 引用。 `compiled-contract.json` 不编码原始 response body。
- compile 已新增 deterministic quality findings：对隐私候选值、偶发/analytics 网络请求、弱 selector、固定等待输出 warning，并写入 `compiledContract.qualityFindings[]`；后续 LLM / VLM proposals 只在这些机器可读发现基础上辅助生成候选修复，不直接决定 pass / fail。
- compile 已新增 `compile-proposals.jsonl`：当存在 quality findings 时，将每条 finding 转成 `status=proposed` 的候选建议，覆盖 `contract.redaction`、`contract.network`、`contract.selector`、`contract.wait`；proposal 是审查输入，不会自动修改 `compiled-contract.json`。
- 已新增 `triton testrec proposals <case.tritontestcase> --json`：只读检查 `compile-proposals.jsonl`，输出 `proposalCount`、候选建议和下一步 inspect 命令；当前不提供 apply / approve / reject，避免模型或启发式建议直接改写合同。
- inspect 已新增 lifecycle summary：根据 artifact presence 输出 `raw / compiled / proposed` 三种 stage，以及 `needs-compile / ready / review-proposals` health，便于 agent 判断下一步是 compile、replay dry-run 还是 proposal review。
- 已新增 `triton testrec replay <case.tritontestcase> --platform <platform> --dry-run --json` 的离线 replay plan：从 `compiled-contract.json` 生成 `pageChecks[]` 与 `plannedSteps[]`，其中 `pageChecks[]` 通过 `triton testrec match-page ... --candidate-json <target-fingerprint-json>` 明确目标端页面指纹证据检查，`plannedSteps[]` 生成 planned Triton action argv、workflow categories、expected artifacts、stop conditions 与 blockers；当前不执行设备动作，缺少 compiled contract 时返回 `missing_compiled_contract`。
- 已新增 `triton testrec replay <case.tritontestcase> --platform <platform> --executor local-simulated --target-fingerprints-json <json> --evidence-dir <dir.tritonevidence> --json` 的离线本机模拟 executor：消费 dry-run plan，输出 `triton.testrec.replay-result`、`execution`、`pageResults[]`、`networkResults[]` 与 `steps[]`；`execution` 固定声明 `mode=offline-simulated`、`requiresDevice=false`、`deviceCommandsExecuted=false`、`llmUsed=false`、`vlmUsed=false`、`networkPolicyMode=simulated-projection` / `not-present`，以及 step status taxonomy：`executed / failed / skipped / blocked / not-run / simulated-passed`，作为后续真实 executor 的 side-effect 边界合同。当提供 target-side fingerprints 时复用 deterministic matcher 生成 `matched / assisted-matched / needs-review / not-matched`、`matchScore` 与 evidence，`not-matched` / `needs-review` 会阻断 action steps；Network Map 会被投影为 `simulated-mock-candidate` / `simulated-passthrough` 等网络结果，并在 evidence JSONL 中写入 `testrec.replay.network` 事件，保留 `redactionRequired`、`nonBlocking` 与 strategy evidence，保留 fixturePath；但当前仍不执行 fixture body 或真实 network policy。未提供 target fingerprints 时才保留 `simulated` 页面状态。所有 action step 仍只标记为 `simulated-passed`，并在 step result / `testrec.replay.step` event 中固定输出 `deviceCommandExecuted=false`、`artifactRefs=[]`、`failure=null` 与 `no-device-command-executed` evidence；后续真实 executor 必须把每步实际执行状态、实际 evidence artifact refs 和 `failure{code,message,path,artifactRefs,recoveryCommands,retryable}` 写回同一字段。当传入 `--evidence-dir` 时写出 `manifest.json`、`run/replay-result.json`、`run/events.jsonl` 和 `run/run.json`，用于固定 replay result / evidence bundle 合同；该 executor 不连接真实设备、不调用动作命令。
- 当 local-simulated replay 提供 `--target-fingerprints-json` 且请求 `--evidence-dir` 时，会把 caller-provided target-side fingerprints 写入 `pages/target-fingerprints.json`，并在 `manifest.json.artifacts[]` 以 `testrec.page.target-fingerprints` 索引；该 artifact 明确 `modelCallsExecuted=false`、`llmUsed=false`、`vlmUsed=false`，用于证明本次离线 executor 没有现场调用模型，而是消费调用方提供的页面指纹证据。
- page replay evidence 已形成可追溯链路：`pageResults[].artifactRefs` 与 `testrec.replay.page.artifactRefs` 会指向 `pages/target-fingerprints.json`，agent 可以从 page match result 直接追到本次用于判定的 target-side fingerprint artifact。
- replay evidence JSONL 已统一基础 event envelope：`testrec.replay.started/page/network/step/finished` 均输出 `schemaVersion`、`event`、`runID`、`timestamp`、`category`、`subjectID`、`status`、`artifactRefs` / `failureCode`（按事件类型可空）与 `evidence`；`category` 当前限定为 `run / page / network / step`。这让后续真实 executor 可以流式写入同一 `run/events.jsonl`，不需要为 page / network / step 另起事件结构。
- local-simulated replay 已将 Network Map 的 fixturePath 透出到 `networkResults[].fixturePath`、`networkResults[].artifactRefs` 和 `testrec.replay.network.artifactRefs`；请求 `--evidence-dir` 时，会把被引用的 `network/fixtures/*.json` 复制进 evidence bundle，并在 `manifest.json.artifacts[]` 以 `testrec.network.fixture` 索引，保证 result / events / manifest / fixture file 四方可审计；当前仍不执行真实 network policy。
- HTTP `POST /v1/test-recorder/cases/replay` 已与 CLI local-simulated replay 对齐：请求 `evidenceDir` 时同样返回 `networkResults[].fixturePath` / `artifactRefs`，并在 evidence bundle 的 `run/events.jsonl` 与 `manifest.json.artifacts[]` 中写入同一 network fixture artifact。
- replay result 已新增 `evidenceSummary`：声明 `expectedEventCount`、page / network / step event count、`blockerCount` 与 `statusConsistent`；写入 evidence bundle 时，`manifest.json.run.eventCount` 与 `run/events.jsonl` 行数必须和 `expectedEventCount` 对齐，避免后续真实 executor 产生 “result passed 但 events / manifest blocked 或缺事件” 的矛盾证据。
- `evidenceSummary` 已继续补齐 artifact refs 自审计字段：`artifactRefCount`、`pageArtifactRefCount`、`networkArtifactRefCount` 与 `stepArtifactRefCount`，用于让 agent 同时校验 replay result 顶层 artifactRefs、page / network / step 结果与 evidence bundle manifest 是否存在引用缺口。
- replay evidence manifest 已写入通用 `run.summary`：`runID` 与 `run/run.json` 对齐，`verdict` 映射为 `success / blocked`，`stepCount` 与 replay steps 对齐，`frictionCount` 与 blockers 对齐；通用 evidence/report 工具无需解析 testrec 专用 result 也能读取本次回放结论。
- HTTP replay 与 CLI replay 已共同覆盖 `manifest.run.summary` parity：`POST /v1/test-recorder/cases/replay` 写出的 evidence bundle 同样校验 `runID / verdict / stepCount / frictionCount`，避免本机 HTTP 管理 API 与 CLI 在证据合同上分叉。
- replay result 的 `execution.executorRequirements[]` 已拆出 executor capability requirements：当前 `local-simulated` 明确 `compiled-contract=satisfied`、`live-target-device=not-required`、`device-action-execution=not-required`、`network-policy-application=simulated`、`evidence-artifact-capture=satisfied/not-requested`；请求未实现的 `local-device` executor 会返回 `unsupported_replay_executor`，hint 中保留 `live-target-device`、`device-action-execution`、`evidence-artifact-capture` 和 `network-policy-application`，让 agent 知道真实设备回放还缺哪些能力。
- 已把 `testrec-session-start` / `testrec-event-ingest` / `testrec-session-stop` / `testrec-inspect` / `testrec-compile` / `testrec-proposals-inspect` / `testrec-page-match` / `testrec-replay-dry-run` / `testrec-replay-local-simulated` 接入 `triton schema --command testrec --json` 与 capabilities matrix，agent 可以通过 schema / capabilities 发现该能力。
- 已验证 unsupported capability 只进入 `unsupportedCapabilities`，不被当成 pass。
- 尚未实现系统级动作监听、完整合同 compiler、真实 VLM fingerprint 生成、LLM / VLM proposals 与真实设备 `testrec replay` 执行；当前 non-dry-run 只允许 `--executor local-simulated`，Network fixture 只生成脱敏 artifact，不应用到真实网络层。

## 验收标准

- 需求和后续实现先走 BDD / TDD。
- CLI / HTTP 输出必须是机器可读 JSON / JSONL。
- 失败输出为单个 JSON error envelope。
- Web mock 不承载业务控制入口。
- 文档调整后运行 `docs-linhay/scripts/check-docs.sh`。
