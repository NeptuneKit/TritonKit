# Three Platform Network Takeover Plan v01

## 规划原则

1. Contract first：先统一 schema、DTO、capabilities、doctor 和 plan，再做单平台 adapter。
2. Three-platform skeleton first：P0 同时让 iOS / Android / Harmony 在 `capabilities` 和 `doctor` 中可见，避免做成 iOS-only。
3. Host proxy first：默认走 host-side proxy，App-internal SDK 只作为 explicit opt-in lane。
4. Evidence first：每个 start/status/export/stop 都要能进入 `.tritonevidence`。
5. Honest limitations：有限可见就说有限，不伪装全量接管。

## P0：三端契约骨架

### 交付

- 新增 `device proxy` schema：
  - `doctor`
  - `start`
  - `status`
  - `export`
  - `stop`
- 新增 DTO：
  - `NetworkProxySession`
  - `NetworkProxyStatus`
  - `NetworkProxyCertificateStatus`
  - `NetworkProxyLimitation`
  - `NetworkProxyRestoreSummary`
- 新增 capability：
  - `device-proxy-ios`
  - `device-proxy-android`
  - `device-proxy-harmony`
  - `network-capture-export`
- 新增 failure codes：
  - `proxy_tool_not_found`
  - `proxy_start_failed`
  - `proxy_not_running`
  - `proxy_config_failed`
  - `proxy_restore_failed`
  - `proxy_cert_untrusted`
  - `proxy_visibility_limited`
  - `proxy_unsupported_transport`
  - `proxy_export_failed`
  - `proxy_platform_not_supported`

### 测试

- `TKCLISchemaTests` 覆盖 `device proxy` command inventory。
- 安全 CLI skeleton 覆盖三端 `doctor/status/start/export/stop` 参数解析、输出 envelope 和失败错误码。
- capabilities 测试保证三端 capability name 唯一、group 非 `misc`、evidence 非空。

### 验收

```bash
triton schema --command device --json
triton capabilities --json
triton device proxy doctor --platform ios --json
triton device proxy doctor --platform android --json
triton device proxy doctor --platform harmony --json
```

### 2026-06-09 状态

已完成：

- `device` schema 暴露 `proxy doctor/start/status/export/stop` usage forms、examples、failure codes 和 `host.device-proxy` output contract。
- capabilities matrix 暴露 `device-proxy-ios`、`device-proxy-android`、`device-proxy-harmony`、`network-capture-export`，并提供 `group/requiredBy/nextAction/evidence`。
- schema taxonomy 增补 `network-capture`、`proxy-restore`、`host-device-proxy`，并允许 `network-capture-export` 使用 `device proxy export --platform <platform>` 作为跨三端 evidence nextAction。
- 真实 `device proxy` ArgumentParser command / safe runner 已落地：
  - `doctor`：三端返回 `ok=true`、`surface=host.device-proxy`、`lane=host-proxy`、limitations。
  - `status`：三端返回未运行状态，不伪装已接管。
  - `export` 普通路径：可解析并返回单个 JSON error envelope，当前稳定失败为 `proxy_platform_not_supported`，非 0 退出。
  - `start/stop` 普通路径：先进入 break-glass policy envelope；缺少 `--confirm --audit-record <id> --execute-runner` 任一项返回 `destructive_action_requires_policy`，iOS / Android 三项策略齐备后才调用真实 runner，Harmony policy 已接受但平台代理命令未验证时返回 `proxy_unverified_platform_proxy`。
- 执行期 proxy DTO 已拆入 `CLIHostDeviceProxyRuntime.swift`，作为后续真实 adapter 的输出基础。
- `triton sim proxy doctor/start/status/export/stop --simulator <udid|booted> --json` 已作为 iOS alias 接入 `sim` 命令树和 schema，复用 `host.device-proxy` output contract；当前 `status` 返回未运行状态，`start/export/stop` 的 alias 仍保持安全失败路径，后续需要跟随 `device proxy` 的 policy-gated 形态继续补齐。
- 测试通过：`swift test --package-path CLI --filter DeviceCrossPlatformTests`、`swift test --package-path CLI --filter SchemaFactSource`、`swift test --package-path CLI`。
- CLI smoke 已覆盖 `doctor/status/start` 的成功与安全失败输出。

未完成，进入后续切片：

- 平台代理配置、证书状态、capture export、restore snapshot。
- `doctor` 实际检查代理服务、证书和平台配置能力。

## P1：iOS Simulator host proxy

### 交付

- `triton device proxy start/status/export/stop --platform ios`
- `triton sim proxy ...` 作为 iOS alias。
- 证书状态、host proxy 状态、simulator target、artifact path、restore snapshot。
- Rockxy 参考点：proxy override / restore、证书 trust、bypass、redaction、HAR / session export。

### 2026-06-09 状态

已完成：

- fake iOS proxy adapter 覆盖 `start/status/export/stop`，使用内存态 session 和临时 artifact，不触碰本机系统代理。
- fake `start` 写入 `restore-state.json` 和 `requests.ndjson` 占位 artifact，返回 `ok=true`、`configured=true`、`proxyEndpoint=127.0.0.1:19431`、`visibility=partial`。
- fake `export` 写出 bounded NDJSON artifact；未 start 时返回 `ok=false`、`error.code=proxy_not_running` 和可执行 `nextAction`。
- fake `stop --restore` 清理 session 并返回 restore summary。
- iOS host proxy `networksetup` command planner 已完成纯函数：
  - start override：`-setwebproxy`、`-setwebproxystate on`、`-setsecurewebproxy`、`-setsecurewebproxystate on`、`-setsocksfirewallproxystate off`。
  - restore：先关闭 HTTP / HTTPS / SOCKS state，再按 snapshot 恢复 HTTP / HTTPS / SOCKS 和 bypass domains。
- 验证通过：`swift test --package-path CLI --filter SimulatorAdvancedControlsTests`、`swift test --package-path CLI --filter DeviceCrossPlatformTests`、`swift test --package-path CLI --filter SchemaFactSource`、`swift test --package-path CLI`。

未完成，进入下一切片：

- 将 fake adapter 替换为受策略保护的真实 iOS adapter。
- 真实读取 network service / proxy snapshot。
- 真实执行 `networksetup` 需要显式 break-glass / audit policy，不默认执行。
- 证书安装 / trust 探测、HAR 导出和真实 Simulator smoke。

### 2026-06-10 状态

已完成：

- fake proxy adapter 已扩展为三端通用测试 adapter，`start/status/export/stop` 按 request 写入和返回 iOS / Android / Harmony 的 `platform` 与 `target`，只使用临时 artifact，不触碰 host 或 emulator 代理设置。
- fake restore snapshot 固定 schema 为 `triton.proxy.restore.v1`，但 `platform` / `target` 动态来自 request。
- fake export artifact 固定 schema 为 `triton.network.v1`，并动态写入 `platform` / `target`，测试不再依赖硬编码 byte count。
- `device proxy start --plan-only --json` 已返回三端 command ledger：`sourceCommands[]`、`configured=false`、`proxy_plan_only:not_executed`。
- `device proxy stop --restore --plan-only --json` 已返回三端 restore command ledger：`sourceCommands[]`、`configured=false`、`restore.restored=false`、`proxy_plan_only:not_executed`。
- `device proxy export --plan-only --json` 已返回三端 artifact plan：`artifacts[].kind=network-capture`、显式 `output` path、`configured=false`、`proxy_plan_only:not_executed`、`proxy_export_plan_only:artifact_not_written`；该路径不读取 session capture，也不写 HAR / NDJSON 文件。
- `device proxy start/stop --confirm --audit-record <id> --json` 已进入 execution policy envelope：缺少 `--execute-runner` 时仍返回 `destructive_action_requires_policy`，并通过 `error.nextAction` 指向带完整 policy 的命令形态。
- `device proxy start/stop --platform ios|android ... --confirm --audit-record <id> --execute-runner --json` 已接入真实 command runner；该路径会调用 iOS `networksetup` 或 Android ADB planner 产出的 host command ledger，成功时返回 `proxy_runner_executed:break_glass`，失败时返回 `proxy_start_failed` / `proxy_restore_failed`。
- 已在真实 command runner 前增加 endpoint preflight：`device proxy start --platform ios|android ... --execute-runner` 先尝试连接 `--proxy <host:port>`；若不可达，返回 `proxy_endpoint_unreachable`，保留 `sourceCommands[]` 供审计，但不得执行 `networksetup` 或 ADB mutation。Android preflight 检查 Mac host endpoint，实际 ADB ledger 仍可将 loopback 改写为 `10.0.2.2:<port>`。
- 已补 iOS / Android 原值 restore snapshot：`start --execute-runner --output <dir>` 在 mutation 前写出 `<dir>/restore-state.json`，schema 为 `triton.proxy.restore.v1`，包含 `platform`、`target`、`proxyEndpoint`、`auditRecord`、`snapshotCommands`、`startCommands`、`restoreCommands`、`snapshotSourceCommands[]`、`sourceCommands[]` 和 `restoreSourceCommands[]`；iOS 记录 `serviceSnapshots[]`，Android 记录 `androidOriginalHTTPProxy`，`stop --restore-snapshot <path> --execute-runner` 优先执行 snapshot 中按原值生成的 restore ledger。
- 验证通过：`swift test --package-path CLI --filter DeviceCrossPlatformTests`。
- P1 runner 抽象已补上并接 CLI 显式执行路径：`NetworkProxyCommandRunner` 可注入 fake runner 验证 iOS / Android start 与 stop restore command ledger 的顺序执行，成功时返回 `ok=true`、`configured=true/false`、`proxy_runner_executed:break_glass`、audit limitation 与 restore 状态；runner 失败时返回稳定 `proxy_start_failed` / `proxy_restore_failed` envelope，并保留 `sourceCommands[]`。Harmony 仍走 `proxy_unverified_platform_proxy` probe-only。
- `sim proxy start/export/stop` 已对齐 iOS alias：支持 `--plan-only`，`start/stop` 支持 `--confirm --audit-record <id> --execute-runner`；缺少 `--execute-runner` 不会调用 `networksetup`；`sim proxy stop --restore-snapshot <path>` 可消费 start 写出的 restore snapshot。
- iOS start snapshot 已接只读原值查询：`networksetup -getwebproxy Wi-Fi`、`-getsecurewebproxy`、`-getsocksfirewallproxy`、`-getproxybypassdomains`。query 失败会走 `proxy_start_failed`，不得继续执行代理 mutation。
- `stop --restore-snapshot <path> --execute-runner` 的失败路径已输出 restore failure artifact：runner 返回 `proxy_restore_failed` 时，会在 snapshot 同目录写出 `restore-failure.json`，schema 为 `triton.proxy.restore-failure.v1`，并把 `artifacts[].kind=proxy-restore` 暴露给 agent 做 evidence/archive recovery。该路径只覆盖已有 iOS / Android break-glass restore snapshot，Harmony 仍保持 probe-only。
- 验证通过：`swift test --package-path CLI --filter DeviceCrossPlatformTests` 通过 42 tests；`swift test --package-path CLI --filter SimulatorAdvancedControlsTests` 通过 16 tests；`swift test --package-path CLI --filter SchemaFactSource` 通过 107 tests。
- `start --execute-runner --output <dir>` 已写出文件态 proxy session：`<dir>/session-state.json` 使用 schema `triton.proxy.session.v1`，记录 platform、target、captureMode、proxyEndpoint、configured、cert、visibility、limitations、artifacts、restoreSnapshotPath 与 sourceCommands；同时写 `<dir>/requests.ndjson` 作为 `triton.network.v1` 占位 capture artifact。`status/export --session` 会恢复 session-state 中持久化的 cert；旧 session 若缺少 cert 字段，则按平台保守证书状态回退。
- `device proxy status --platform <platform> --device <selector> --session <dir> --json` 与 `sim proxy status --simulator <udid|booted> --session <dir> --json` 已能跨 CLI 调用读取 session-state，校验 platform / target 后返回同一 session 状态。
- `device proxy export --platform <platform> --device <selector> --session <dir> --output <path.ndjson> --json` 与 `sim proxy export --simulator <udid|booted> --session <dir> --output <path.ndjson> --json` 已能从 session artifacts 复制 capture 文件并返回 `network-capture` artifact；当前导出的仍是占位 NDJSON，不代表真实 proxy listener 已写入请求事件。
- 验证通过：`swift test --package-path CLI --scratch-path /tmp/triton-cli-test-session-6F89318E-90E3-36EFFFD4649A --filter DeviceCrossPlatformTests` 通过 43 tests；同 scratch 下 `--filter SchemaFactSource` 通过 107 tests；`--filter SimulatorAdvancedControlsTests` 通过 16 tests。
- 新增三端共享本地 capture / mock / block / throttle proxy 服务：`device proxy serve --listen <host:port> --output <dir> --mode record|mock|block|throttle --jsonl` 会启动 HTTP proxy listener，写 `<dir>/requests.ndjson`，并输出 `proxy.serve.ready`、`proxy.serve.request`、`proxy.serve.connection-failed` 和最终 `proxy.serve.summary` JSONL。
- `device proxy serve` 支持普通 HTTP proxy request 的 metadata capture 与 HTTPS `CONNECT` tunnel metadata capture；当前只保存 method、url、host、port、path、tunnel 和 header names，默认不保存 header values / body，不做 TLS 解密。
- `device proxy serve --mode record` 会记录 metadata 后尝试透传 upstream；`--mode mock` 会记录 metadata、写 `policyAction=mocked`、`responseStatus=200`、`responseStatusText="TritonKit Proxy Mock"`，并直接向 client 返回固定 JSON mock 响应；`--mode block` 会记录 metadata、写 `policyAction=blocked`、`responseStatus=502`、`responseStatusText="TritonKit Proxy Blocked"`，并直接向 client 返回 `502 TritonKit Proxy Blocked`，不连接 upstream；`--mode throttle` 会记录 metadata、写 `policyAction=throttled`、`responseStatus=429`、`responseStatusText="TritonKit Proxy Throttled"`，并直接返回 `429 TritonKit Proxy Throttled` 与 `Retry-After: 1` 合成限流响应。mock / block / throttle 能力属于三端共用 host-side proxy policy，不依赖 App 内 SDK，也不代表 Harmony 平台代理 mutation 已验证；当前 throttle 不是带宽整形或真实延迟注入。
- `device` schema 已暴露 `proxy serve --listen <host:port> --output <dir> --mode record|mock|block|throttle --jsonl` usage、`--listen` / `--mode` / `--jsonl` option、example、`jsonlEvents[]`、`finalEventKind=proxy.serve.summary` 和 `host.device-proxy-serve` output contract；该 contract 包含 `responseStatus` / `responseStatusText`，让 agent 可直接从 NDJSON 判断 mock / block / throttle 的本地策略响应。该入口是 iOS Simulator、Android Emulator、Harmony / DevEco Emulator 共用的 host proxy endpoint。
- 已补 command-level smoke：测试直接运行 `DeviceProxyServe.run()`，捕获 stdout JSONL，并验证 `proxy.serve.ready`、`proxy.serve.connection-failed`、`proxy.serve.request` 与最终 `proxy.serve.summary`；同时确认 capture artifact 不写 final summary。
- `device proxy export --session <dir> --output <path.har>` 与 `sim proxy export --session <dir> --output <path.har>` 已支持从 `requests.ndjson` 中的 `proxy.serve.request` events 生成 HAR 1.2 metadata-only skeleton；`.ndjson` 输出仍原样导出 capture artifact。
- HAR skeleton 只包含 method、URL、query、header names redacted 为 `<redacted>`、CONNECT tunnel metadata 和策略响应状态；forwarded request 的 response 仍是 `status=0/not captured`，mock / block / throttle request 会写入 `200 TritonKit Proxy Mock` / `502 TritonKit Proxy Blocked` / `429 TritonKit Proxy Throttled`，但不包含 header values、request/response bodies、TLS decrypted content 或真实 response payload。
- `device proxy export --session` 现在会在 JSON envelope 中返回导出摘要：`requestCount`、`redaction`、`truncation`。占位 capture 返回 `requestCount=0`、`redaction=default`、`truncation=none`；真实 `proxy.serve.request` 事件按 metadata-only capture 统计请求数并返回 `redaction=headers-names-only`。capture artifact 缺失、不可读或写入失败时返回稳定 `proxy_artifact_write_failed`，`error.nextAction.category=archive`。
- `device proxy doctor/status` 现在会返回保守证书状态：`cert.installed=false`、`cert.trusted=false`，iOS scope 为 `simulator`，Android / Harmony scope 为 `emulator`；这只是 agent-facing 可见性判断，不执行证书安装、不声明 TLS 解密可用。
- `triton evidence --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` 与 `triton capture --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` 已可把文件态 proxy session 导入 `.tritonevidence`：导入 `<dir>/session-state.json` 为 `network.proxy-session`，导入 declared `network-capture` artifact 为 `artifacts/network/requests.ndjson`，并将二者标记为 sensitive。`network-capture` 现在进入 evidence primary artifact 排序，方便 agent 优先检查网络证据；新增三端 fixture 验证 iOS / Android / Harmony 的 `platform` 与 `target` 会保留到 evidence manifest，并新增 `evidence` / `capture` 真实 CLI argv smoke，避免该能力只被内部函数测试覆盖。若 capture artifact 缺失或不可读，导入仍保留 `network.proxy-session`，并只把 `network-capture` 写入 `skipped[]`。
- `triton plan network-proxy --platform <platform> --device <selector> --proxy <host:port> --mode <mode> --output <proxy-session-dir> --certificate <path.cer> --evidence <dir.tritonevidence> --json` 已补 task plan 层：即使 embedded server 不可达也返回 host-only plan，步骤覆盖 `target resolve`、`device proxy doctor`、`device proxy probe --plan-only`、`device proxy cert plan`、`device proxy serve --jsonl`、`device proxy start --plan-only`、`device proxy export --plan-only`、`evidence --include network.proxy-session` 和 `device proxy stop --restore-snapshot <restore-state-json> --plan-only`。当 `--output` 是具体目录时，`<restore-state-json>` 会解析为该目录下的 `restore-state.json`；该入口不执行真实 mutation。
- `.tritonplan` replay 已支持 proxy 审计 step：`action=evidence` 可声明 `include: "network.proxy-session"` 与 `proxySession: "<proxy-session-dir>"`，`plan inspect` 与 `replay --dry-run` 都会在 `steps[].argv` 中暴露 `--proxy-session`，并把 `network.proxy-session` / `network-capture` 放进 `expectedArtifacts[]`。`action=proxy-probe|proxy-serve|proxy-start|proxy-export|proxy-stop` 会在 inspect / dry-run 中生成对应 `triton device proxy probe --plan-only`、`serve --jsonl`、`start --plan-only`、`export --plan-only`、`stop --restore --plan-only` argv，并暴露 proxy lifecycle 的 expected artifacts。`plan inspect` 还会用 `validationErrors[]` 静态检查 missing platform、missing device selector、missing output path、stop without restore policy 与 export before start。真实 replay 执行 evidence step 时会把 session 交给 `.tritonevidence` 导入路径；真实 replay 遇到 proxy lifecycle step 会返回 dry-run-only / unsupported，不启动 proxy listener，也不执行平台代理 mutation。
- 验证通过：新增 `device proxy serve parses proxy requests into redacted capture events`、`device proxy serve listens locally and writes NDJSON capture events`、`device proxy serve command emits ready request and summary JSONL events`、`proxy session export returns stable artifact write failure when capture is missing`、`device proxy status returns conservative certificate state before a session exists`、`task workflow plans expose executable command sequences` 中的 `network-proxy` case；`swift test --package-path CLI --filter DeviceCrossPlatformTests` 通过 54 tests；`swift test --package-path CLI --filter SchemaFactSource` 通过 107 tests。
- `.tritonplan` proxy replay 验证通过：`swift test --filter TKReplayPlanModelsTests` 通过 25 tests；`swift test --package-path CLI --scratch-path /tmp/triton-cli-proxy-replay-lifecycle-20260611 --filter ReplayCommandTests` 通过 11 tests；`swift test --package-path CLI --filter SchemaFactSourceTests/taskWorkflowPlansExposeExecutableCommandSequences` 通过 1 test。
- 三端证书信任准备契约已补齐为 plan-only：
  - `device proxy cert doctor --platform ios|android|harmony --json` 返回保守 `NetworkProxySession.cert` 状态，不执行任何信任变更。
  - `device proxy cert plan --platform ios|android|harmony --device <selector> --certificate <path.cer> --json` 返回 `proxy.cert.plan` ledger、`proxy-certificate` artifact 和 `proxy_cert_untrusted` limitation。
  - iOS ledger 声明 `xcrun simctl keychain <target> add-root-cert <path.cer>`；Android ledger 声明 `adb push` 与 `android.credentials.INSTALL` 用户安装 intent；Harmony 继续 `proxy_cert_harmony_probe_only`，不编造未验证证书安装命令。
  - capabilities / schema 同步新增 `network-certificate-plan`、`--certificate`、`proxy cert doctor/plan` usage 和 `proxy_cert_untrusted` recovery 分类。
  - 验证通过：`swift test --package-path CLI --scratch-path /tmp/triton-cli-proxy-cert-20260611 --filter DeviceCrossPlatformTests` 通过 56 tests；`--filter SchemaFactSource` 通过 107 tests；完整 `swift test --package-path CLI --scratch-path /tmp/triton-cli-proxy-cert-20260611` 通过 274 tests。
- 三端证书信任执行入口已补为 break-glass runner：
  - `device proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` 只有在策略三件套齐备时执行已审阅 ledger；缺任一项仍返回 `destructive_action_requires_policy`。
  - iOS fake runner 覆盖 `simctl keychain add-root-cert` 成功 envelope，并标记 `cert.installed=true` / `cert.trusted=true`；Android fake runner 覆盖 `adb push` + install intent，仅标记用户安装提示已打开，仍保持 `cert.trusted=false`。
  - Harmony 即使显式执行仍返回 `proxy_unverified_platform_proxy` 与 `proxy_cert_harmony_probe_only`，不伪造 DevEco / Harmony 证书信任命令。
  - 失败 envelope 稳定为 `proxy_cert_install_failed`，保留 `sourceCommands[]` 与 `proxy-certificate` artifact，便于 agent 诊断和归档。
  - capabilities / schema 同步新增 `network-certificate-install`，`nextAction` 指向带 `--confirm --audit-record <id> --execute-runner` 的 break-glass install 入口。
- 三端 `network-proxy` 任务计划已接入证书准备审计步骤：
  - `triton plan network-proxy ... --certificate <path.cer> --json` 会在 `proxy-probe-plan` 后、`proxy-serve` / `proxy-start-plan` 前插入 `proxy-cert-plan`。
  - `proxy-cert-plan` 的 argv 为 `triton device proxy cert plan --platform <platform> --device <selector> --certificate <path.cer> --json`，expected artifact 为 `proxy-certificate`。
  - 该步骤仍是 plan-only，不安装 CA、不配置 trust、不声明 TLS decrypted visibility；Harmony 仍只表达 `proxy_cert_harmony_probe_only`。
- 三端 `network-proxy` 任务计划已把最后一步改为 restore snapshot 审计：
  - `proxy-stop-plan` 的 argv 为 `triton device proxy stop --platform <platform> --device <selector> --restore-snapshot <restore-state-json> --plan-only --json`；有具体 `--output` 时使用 `<output>/restore-state.json`。
  - `device proxy stop --restore-snapshot <path> --plan-only` 会读取 snapshot 中的 `restoreCommands`，返回原值恢复 ledger、`restore.snapshotPath` 和 `proxy_restore_snapshot_plan:original_value_ledger` limitation，不执行 runner。
  - 真实 iOS / Android 恢复仍必须另行使用 `--confirm --audit-record <id> --execute-runner`；Harmony 在真实代理 mutation 验证前仍无 snapshot restore runner。
- 三端网络接管的 target 范围已固化为 simulator/emulator-only：
  - 若 `HostDeviceTarget.scope=real` 或 `kind=real-device`，`start/stop/status/export/cert plan` 与 break-glass executed helper 统一返回 `proxy_real_device_not_supported`。
  - 该拒绝路径返回 `configured=false`、空 `sourceCommands[]` / `artifacts[]`，不会生成 `networksetup`、ADB 或 HDC 代理 mutation ledger，也不会调用 runner。
  - CLI planner 看到 `ios-real:` / `android-real:` / `harmony-real:` selector 前缀时保留 real-device target，不再伪造成 simulator / emulator plan target。
  - schema 同步新增 `proxy_real_device_not_supported` failure code；recovery 分类为 diagnose / prepare-target / plan。
- 三端 `device proxy --device <selector>` 已对齐 workspace selector：
  - `iphone15`、`android-a`、`harmony-a` 等 alias 会从 `.triton/host-targets.json` 解析为真实 target，再生成 `networksetup`、ADB 或 HDC probe ledger。
  - `current` 会复用 `device use` / `target use` 写入的当前 alias 或 target。
  - alias 中的 `sim:`、`android:`、`harmony:` 前缀会归一化，避免 `android:android:emulator-5554` 或 `sim:sim:<udid>` 这类失真 id。
  - 指向 real-device 的 alias 继续进入 `proxy_real_device_not_supported`，保持 simulator/emulator-only 边界。
- iOS `sim proxy --simulator <selector>` 已对齐同一套 workspace selector：`start/status/export/stop` 的 CLI argv 路径会解析 `iphone15` / `current` 为真实 Simulator id，避免把 friendly alias 写进 `host.device-proxy` target 或 command ledger。

### 测试

- fake `xcrun` / proxy runner 覆盖 start/status/stop。
- restore 失败时输出 evidence artifact：已完成 `restore-failure.json` + `proxy-restore` artifact，并已纳入 `network.proxy-session` 的 `.tritonevidence` 自动归档路径；即使 `network-capture` 缺失，manifest 仍会保留 `network.proxy-session` 与 `proxy-restore`，只把缺失的 capture 写入 `skipped[]`。
- session-state 支持跨 CLI 调用 status/export；`status --session` 会在存在 `restore-failure.json` 时补充 `proxy-restore` artifact，`device proxy serve` 已能写 metadata-only NDJSON，`export --session --output <path.har>` 已能生成 metadata-only HAR skeleton；证书 trust / TLS 解密与真实 smoke 证据作为后续切片。

### 真实 smoke

- booted iOS Simulator。
- 启动 proxy record。
- 打开 URL 或 Debug App 发起请求。
- 导出 network artifact。
- stop --restore 后状态干净。

## P2：Android Emulator host proxy

### 交付

- `triton device proxy start/status/export/stop --platform android`
- Android emulator proxy 配置 adapter。
- Android 证书信任能力探测。
- 对 Android 7+ 用户 CA / network security config 限制输出 `proxy_visibility_limited`。

### 测试

- fake adb fixture：
  - emulator ready
  - proxy setting success
  - proxy setting denied
  - certificate not trusted
  - export artifact write failure

### 2026-06-10 状态

已完成：

- 新增 Android ADB proxy command planner：
  - override：`adb -s <serial> shell settings put global http_proxy <host>:<port>`。
  - restore / clear：`adb -s <serial> shell settings delete global http_proxy`。
- Android proxy planner 标记为 `break-glass`，并要求 `.target`、`.timeout`、`.auditRecord`，为后续真实执行器保留审计和恢复边界。
- Android `--proxy` 语义是 Mac host 代理监听地址；当 agent 传入 `127.0.0.1:<port>`、`localhost:<port>` 或 `::1:<port>` 时，planner 会在 ADB ledger 中改写为 emulator 访问 host 的网关 `10.0.2.2:<port>`。`proxyEndpoint` 仍保留原始 host endpoint，`sourceCommands[]` 才是实际写入 emulator global proxy 的地址。
- 当前已接入 CLI 显式真实执行器；Android 普通 start/stop 仍进入 break-glass policy envelope，只有 `--confirm --audit-record <id> --execute-runner` 三项策略齐备时才执行 ADB `settings put/delete`。
- Android start snapshot 已接只读原值查询：`adb -s <serial> shell settings get global http_proxy`。若原值为 `null` 或空，restore ledger 继续 delete；若原值为 `<host>:<port>`，restore ledger 生成 `settings put global http_proxy <host>:<port>`，避免覆盖用户原本的 emulator 代理状态。
- `device proxy start --platform android --device <serial> --plan-only --json` 已可执行，输出 ADB `http_proxy` command ledger，作为后续 break-glass executor 的输入。
- `device proxy stop --platform android --device <serial> --restore --plan-only --json` 已可执行，输出 ADB `settings delete global http_proxy` restore ledger，不执行真实恢复。
- `device proxy export --platform android --device <serial> --output <path> --plan-only --json` 已可执行，输出 network-capture artifact plan，不读取或写入 capture 文件。
- `device proxy start/stop --platform android --device <serial> --confirm --audit-record <id> --execute-runner --json` 已从泛化 unsupported 收敛为显式 break-glass runner，按 ADB ledger 执行 `settings put/delete`；缺少 `--execute-runner` 时不执行真实 mutation。
- 验证通过：`swift test --package-path CLI --filter DeviceCrossPlatformTests`。

### 真实 smoke

- ready Android Emulator。
- 设置 proxy record。
- 用 Settings / browser / debug APK 发起 HTTP 请求。
- HTTPS 如不可解密，必须返回 limitation，不判失败。
- stop --restore。

## P3：Harmony / DevEco Emulator host proxy

### 交付

- P3.0：`doctor/status` 先实测 HDC / 系统设置能力。
- P3.1：如果有稳定系统代理设置命令，再实现 `start/stop`。
- P3.2：证书状态、capture artifact、restore summary。

### 测试

- fake hdc fixture 覆盖：
  - HDC 可用 / 不可用
  - target ready / offline
  - proxy capability unknown
  - start unsupported
  - status limited

### 2026-06-10 状态

已完成：

- 新增 Harmony proxy probe-only command planner：
  - `hdc -t <target> shell param get bootevent.boot.completed`
  - `hdc -t <target> shell echo triton-shell-ready`
  - `hdc -t <target> shell param ls -r proxy`
  - `hdc -t <target> shell param ls -r http`
- 当前不实现、不声明任何未实测的 DevEco / Harmony 系统代理设置命令；`device proxy start --platform harmony` 仍保持安全 unsupported。
- `device proxy probe --platform harmony --device <selector> --json` 已可执行，返回 `probeResults[]`；`param ls` 命中 proxy 候选时只输出 `proxy_harmony_candidate_parameters_found:manual_verification_required`，不把候选参数升级为 mutation 命令。
- `device proxy start --platform harmony --device <target> --plan-only --json` 已可执行，输出 HDC readiness / shell probe command ledger，明确用于能力探测而非代理配置。
- `device proxy stop --platform harmony --device <target> --restore --plan-only --json` 已可执行，继续输出 HDC readiness / shell probe ledger，并返回 `proxy_restore_probe_only:no_verified_harmony_proxy_mutation`。
- `device proxy export --platform harmony --device <target> --output <path> --plan-only --json` 已可执行，输出 network-capture artifact plan；Harmony 仍不声明真实平台代理接管或 export 已支持。
- `device proxy start/stop --platform harmony --device <target> --confirm --audit-record <id> --execute-runner --json` 已从泛化 unsupported 收敛为 `proxy_unverified_platform_proxy`，返回 HDC probe ledger 和 `proxy_harmony_probe_only:no_verified_proxy_mutation`，即使显式请求 runner 也不编造 DevEco / Harmony 代理设置命令。
- Harmony target discovery 已补 HDC list 兼容层：解析 verbose stdout + stderr，verbose 无可解析 target 时 fallback 到 plain `hdc list targets`，并把 plain 单列 target 归类为 connected DevEco emulator。真实本机验收确认 `triton device list --platform harmony --json` 可发现 `127.0.0.1:5555`。
- 验证通过：`swift test --package-path CLI --filter DeviceCrossPlatformTests`。

### 真实 smoke

- ready DevEco Emulator。
- 先跑 doctor。
- 如果平台代理配置可用，再跑 start/export/stop。
- 若不可用，输出 `proxy_unverified_platform_proxy` 或 `proxy_platform_not_supported`，并提供 probe-only / App-runtime opt-in lane 的计划建议。

## P4：App 内 opt-in runtime network lane

### 交付

- `triton runtime network status/export --target <runtime-target> --json`
- provider manifest 字段：
  - `networkProvider.enabled`
  - `networkProvider.captureKinds`
  - `networkProvider.redaction`
  - `networkProvider.limitations`
- 三端 opt-in 方向：
  - iOS：Atlantis-style URLSession / WebSocket 参考，但必须由 App 显式接入。
  - Android：OkHttp / Retrofit / Apollo interceptor 参考，默认不注入。
  - Harmony：ArkTS / native network wrapper provider，默认不注入。

### 测试

- runtime manifest 无 provider -> `proxy_runtime_provider_unavailable`。
- provider 已注册 -> status/export 返回 bounded NDJSON。
- secure headers / body redaction 测试。

## P5：Plan / replay / evidence

### 交付

- `triton plan network-proxy` 任务规划：
  - host-only，server 不可达也能生成
  - `device proxy probe --plan-only`
  - `device proxy serve --jsonl`
  - `device proxy start --plan-only`
  - `device proxy export --plan-only`
  - `evidence --include network.proxy-session`
  - `device proxy stop --restore --plan-only`
- `.tritonplan` 支持 proxy dry-run / inspect steps：
  - `proxy-serve` -> `device proxy serve --jsonl`
  - `proxy-start` -> `device proxy start --plan-only`
  - `proxy-export` -> `device proxy export --plan-only`
  - `proxy-stop` -> `device proxy stop --restore --plan-only`
  - 真实 replay 不自动执行 proxy lifecycle step
- `capture/evidence` 纳入：
  - proxy session status
  - capture artifact
  - restore summary
  - limitations
  - redaction status

### 验收

- replay dry-run 能静态检查：
  - missing platform
  - missing device selector
  - missing output path
  - stop without restore policy
  - export before start
- replay 真跑失败时停止后续业务 assertion，并归档 proxy state。

### 2026-06-11 状态

已完成：

- `TKReplayPlanSummary.steps[].validationErrors[]` 已覆盖 proxy lifecycle 静态检查。
- `proxy-probe` / `proxy-start` / `proxy-export` / `proxy-stop` 会检查 `platform` 与 `device`；`proxy-serve` / `proxy-start` 会检查 `proxy` endpoint；`proxy-serve` / `proxy-start` / `proxy-export` 会检查 `output` path；`proxy-stop` 要求 `restore=true`。
- `proxy-export` 若出现在同一 plan 的首个 `proxy-start` 之前，会标记 `proxy_export_before_start`，让 agent 在执行 dry-run 或真实 replay 前就能修正计划顺序。
- 真实 replay 在失败步骤停止后，会查找后续显式声明 `include: "network.proxy-session"` 与 `proxySession` 的 evidence step，并只执行 proxy-only archive：归档已有 `session-state.json` / `requests.ndjson`，跳过夹在中间的业务 action / assertion，不启动 proxy listener，也不执行平台代理 mutation。
- 这些能力只影响 inspect / dry-run 审计元数据和失败后的 proxy-only evidence archive，不启动 proxy listener，不执行 iOS / Android / Harmony 代理 mutation。

## 风险

1. 三端代理配置命令差异大，必须先用 doctor 暴露能力，不要假设全部可自动配置。
2. HTTPS 解密受证书 trust 与 App 网络安全策略影响，尤其 Android 7+ 与 pinning 场景。
3. Harmony proxy 设置需要真实 DevEco Emulator 验证，不能只凭类比进入 P0 start。
4. App-internal lane 可能改变业务 App 行为，必须 opt-in、DEBUG-only、可关闭、可脱敏。
5. network artifact 容易包含 token、cookie、账号和内部域名，默认必须 redaction。
