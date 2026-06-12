# 20260609 Three Platform Network Takeover

## 结论

本需求规划三端本机模拟器/仿真器网络接管：iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator 都通过 TritonKit 的机器可读 CLI 进入同一套发现、启动、状态、导出、停止、证据和限制表达。

默认产品主线是 **host-side proxy takeover**，即 TritonKit 在 Mac host 上启动或连接本地代理，并通过平台 adapter 配置本机 emulator/simulator 的代理、证书、capture/mock/block/throttle 规则和恢复动作。

App 内流量接管只作为 **explicit opt-in runtime lane** 参考，借鉴 Atlantis 这类 SDK 方案。它不能覆盖或削弱当前 iOS Simulator proxy 主线，也不能默认注入业务 App 的 `URLProtocol`、method swizzling、SDK interceptor 或 network provider。

## 背景

用户已经明确两个参考方向：

- Rockxy：host-side macOS HTTP debugging proxy，适合作为 Simulator / Emulator proxy 接管参考。
- Atlantis：App-embedded traffic capture SDK，适合作为应用内 opt-in 流量接管参考。

当前 TritonKit 三端 emulator takeover 边界仍保持：

- Include：本机 iOS Simulator、Android Emulator、HarmonyOS / DevEco Emulator、本机 CLI、JSON/JSONL、`.tritonevidence`、`.tritonplan`。
- Exclude：真机、远端 agent、设备云、Web/Wails 产品面、对外 HTTP 产品面、多租户、内置 VLM loop。

## 参考

- Rockxy 索引：`docs-linhay/references/rockxy.md`
- Rockxy 快照：`docs-linhay/references/rockxy/`
- Atlantis 索引：`docs-linhay/references/atlantis.md`
- Atlantis 快照：`docs-linhay/references/atlantis/`
- iOS Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Android Emulator support：`docs-linhay/spaces/20260605-android-emulator-support/README.md`
- Harmony Emulator alignment：`docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- ai-phone emulator CLI：`docs-linhay/spaces/20260521-ai-phone-emulator-cli/README.md`
- AI CLI 契约：`docs-linhay/dev/ai-cli-readable-control.md`

## 目标

1. 三端统一网络接管入口：agent 优先使用 `triton device proxy ... --platform ios|android|harmony --json`。
2. 保留 iOS 便捷别名：`triton sim proxy ...` 映射到 `triton device proxy ... --platform ios`。
3. 代理接管全过程机器可读：doctor、start、status、export、stop 均返回稳定 JSON，长任务使用 JSONL。
4. capture/mock/block/throttle 都能进入 `.tritonevidence` 和 `.tritonplan`，并记录 command ledger。
5. 明确区分 host-side proxy lane 和 App-internal opt-in lane，不混用运行时边界。
6. 对证书 pinning、不走系统代理、自定义 socket、私有加密协议、QUIC、平台证书策略等限制给出稳定 warning / error code。
7. 三端能力差异通过 `capabilities`、`doctor`、`schema` 和 `plan` 暴露，不让 agent 猜平台行为。

## 非目标

1. 不支持真机网络接管。
2. 不新增 Web/Wails UI 或设备大盘。
3. 不默认修改业务 App 代码。
4. 不绕过证书 pinning、系统安全策略、root / jailbreak / debug-only 限制。
5. 不承诺捕获所有自定义 socket、私有加密协议、QUIC 或 native C/C++ 网络栈。
6. 不把 host 命令成功视为业务验证成功；仍必须通过 wait/assert/evidence 验证业务状态。
7. 不把 App-internal opt-in SDK 作为三端 proxy 接管的前置条件。

## 术语

- `host-proxy`：TritonKit host 启动或连接本地 HTTP/HTTPS proxy，通过平台 adapter 让 emulator/simulator 流量经过代理。
- `app-runtime`：业务 App 显式接入 Debug runtime / SDK / interceptor 后主动上报网络事件。
- `captureMode`：`record`、`mock`、`block`、`throttle`、`passthrough`。
- `visibility`：当前接管对目标流量的可见程度，取值 `full`、`partial`、`none`、`unknown`。
- `restore`：恢复代理、证书、规则、进程和临时 artifact 的动作与结果。

## CLI Surface

### 当前 P0 契约骨架状态

截至 2026-06-09，已落地机器可读发现层与安全 CLI 命令骨架，不包含真实代理配置执行器：

- `triton schema --command device --json` 已暴露 `proxy doctor/start/status/export/stop` usage forms。
- `triton capabilities --json` 已暴露 `device-proxy-ios`、`device-proxy-android`、`device-proxy-harmony`、`network-capture-export`、`network-certificate-plan` 与 `network-certificate-install`。
- `device` schema 已声明 `host.device-proxy` output contract，模型名为 `NetworkProxySession`。
- `triton device proxy doctor --platform ios|android|harmony --json` 已可执行，返回 `ok=true`、`surface=host.device-proxy`、`lane=host-proxy` 和 limitations。
- `triton device proxy probe --platform ios|android|harmony --device <selector> --json` 已可执行，返回只读平台代理能力探测结果：`action=proxy.probe`、`configured=false`、`probeResults[]` 与 `sourceCommands[]`。iOS / Android 复用只读 snapshot ledger；Harmony 只运行 HDC readiness、shell probe 与 `param ls -r proxy|http`，用于收集候选参数证据，不执行、不声明任何 DevEco / Harmony 代理 mutation。
- `triton device proxy status --platform ios|android|harmony --device <selector> --json` 已可执行，当前返回未运行状态。
- `triton device proxy export ... --json` 普通执行路径仍返回 `ok=false`、`error.code=proxy_platform_not_supported`，避免误报真实 capture export 成功。
- `triton device proxy start/stop ... --json` 普通执行路径已进入 break-glass policy envelope：缺少 `--confirm --audit-record <id> --execute-runner` 任一项时返回 `destructive_action_requires_policy`；iOS / Android 三项策略满足后才调用真实 command runner，返回 `proxy_runner_executed:break_glass` 或稳定 `proxy_start_failed` / `proxy_restore_failed`；Harmony 即使带 `--execute-runner` 仍返回 `proxy_unverified_platform_proxy`，只暴露 HDC probe ledger，不执行未验证的 DevEco / Harmony 代理设置。
- `triton device proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` 已接入 break-glass runner：iOS 执行已审阅的 `xcrun simctl keychain <target> add-root-cert <path.cer>` ledger，成功后 `cert.installed=true`、`cert.trusted=true`、scope 为 `simulator`；Android 执行 `adb push` 与 `android.credentials.INSTALL` intent，只能证明安装提示已打开，仍返回 `cert.trusted=false`，需要用户在 emulator 内确认。失败统一返回 `proxy_cert_install_failed`，并保留 `sourceCommands[]` 与 `proxy-certificate` artifact。Harmony 即使带三件套也保持 `proxy_unverified_platform_proxy` / `proxy_cert_harmony_probe_only`，不编造未验证证书信任命令。
- `device proxy` takeover 当前只接受 iOS Simulator、Android Emulator、Harmony / DevEco Emulator target。若 target 为 `scope=real` 或 `kind=real-device`，`start/stop/status/export/cert plan/cert install` 与 break-glass runner helper 都返回 `ok=false`、`error.code=proxy_real_device_not_supported`、`configured=false`、空 `sourceCommands[]` / `artifacts[]`，避免从真实设备 target 生成任何平台代理 mutation ledger。CLI planner 看到 `ios-real:`、`android-real:` 或 `harmony-real:` selector 前缀时必须保留 real-device 语义并走该拒绝 envelope，不能把它们伪造成 simulator / emulator id。
- `device proxy ... --device <selector>` 已对齐 workspace host target 选择器：会读取当前工作目录 `.triton/host-targets.json`，解析 `device use` / `device alias` 写入的 alias 与 `current`，并在 plan-only、status、export、cert plan、break-glass helper 入口中使用解析后的真实 simulator / emulator target。`sim:`、`android:`、`harmony:` 前缀会归一化为平台实际 id；若 alias 指向 `scope=real`、`kind=real-device` 或 `*-real:` selector，仍走 `proxy_real_device_not_supported`，不会生成平台代理 mutation ledger。
- `triton sim proxy doctor/start/status/export/stop --simulator <selector> --json` 已作为 iOS Simulator alias 接入，复用同一个 `host.device-proxy` output contract；`--simulator` 支持 `booted`、裸 UDID、`sim:<udid>`、workspace alias 与 `current`，并与 `device proxy --platform ios --device <selector>` 共用 real-device 拒绝语义。`start/stop/export` 已支持 `--plan-only`，`start/stop` 只有在 `--confirm --audit-record <id> --execute-runner` 齐备时才调用 iOS `networksetup` runner。
- 新增稳定 failure codes：`proxy_visibility_limited`、`proxy_platform_not_supported`、`proxy_real_device_not_supported`、`proxy_runner_not_configured`、`proxy_unverified_platform_proxy`、`destructive_action_requires_policy`、`proxy_cert_install_failed`、`proxy_start_failed`、`proxy_restore_failed`。
- `network-capture-export` 保持 evidence 能力语义，执行入口为 `device proxy export --platform <platform> ...`。
- `network-certificate-plan` 保持 host-side 证书信任准备语义，执行入口为 `device proxy cert plan --platform <platform> --device <selector> --certificate <path.cer> --json`，只返回 command ledger，不执行证书安装、信任配置或 TLS 解密。
- P1 的 iOS fake adapter 和 `networksetup` command planner 已有测试覆盖：fake adapter 能在临时目录中完成 start/status/export/stop/restore artifact 闭环；command planner 能生成 start override 与 restore 命令序列，但当前 CLI 还没有启用真实系统代理修改。
- 2026-06-10 继续收敛为三端一致测试面：fake proxy adapter 已从 iOS-only 扩展为 iOS / Android / Harmony 通用内存态 adapter，restore snapshot 与 export artifact 按 request 动态写入 `platform` / `target`，不再硬编码 iOS。
- Android 已新增 ADB proxy command planner：`settings put global http_proxy <host>:<port>` 与 `settings delete global http_proxy`，命令标记 `break-glass`，要求 target / timeout / auditRecord；当前仍只是可测试计划器，不在 CLI 中静默执行。`--proxy` 表示 Mac host 上代理服务监听地址；当输入 `127.0.0.1:<port>`、`localhost:<port>` 或 `::1:<port>` 时，Android Emulator 的 `sourceCommands[]` 会改写为 `10.0.2.2:<port>`，因为 emulator 内部的 loopback 指向 emulator 自身，不是 Mac host。
- Harmony 已新增 probe-only command planner：使用 HDC `bootCompleted`、`shellProbe` 与只读 `param ls -r proxy|http` 验证 target / shell 可用性并收集候选 proxy 参数；在真实 DevEco Emulator 代理设置命令完成验证前，不声明 `start` 可用，不伪装 host proxy 已配置。
- Harmony target discovery 已加固 HDC 输出兼容性：`triton device list --platform harmony --json` 会解析 `hdc list targets -v` 的 stdout + stderr；若 verbose 输出没有可解析 target，则 fallback 到 plain `hdc list targets`；plain 单列 target 如 `127.0.0.1:5555` 视为 `Connected`，并按 DevEco emulator scope 分类。真实验收已确认本机 `127.0.0.1:5555` 返回 `ready=true`、`scope=emulator`、`transport=TCP`。
- `triton device proxy start --platform ios|android|harmony --device <selector> --mode record --output <dir> --plan-only --json` 已接入三端 CLI 可执行面，返回 `ok=true`、`configured=false`、`sourceCommands[]` 和 `proxy_plan_only:not_executed`。这是 agent-facing command ledger，不会修改 host 或 emulator 代理设置。
- `triton device proxy stop --platform ios|android|harmony --device <selector> --restore --plan-only --json` 已接入三端 restore command ledger：iOS 输出关闭 HTTP / HTTPS / SOCKS 的 `networksetup` 命令，Android 输出删除 `global http_proxy` 的 ADB 命令，Harmony 继续只输出 HDC probe 并带 `proxy_restore_probe_only:no_verified_harmony_proxy_mutation`。
- `triton device proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson> --plan-only --json` 已接入三端 artifact plan，返回目标 `network-capture` artifact path、`configured=false`、`proxy_plan_only:not_executed` 和 `proxy_export_plan_only:artifact_not_written`，不会读取或写入 capture 文件。
- P1 runner 抽象已补齐可注入测试面并接入显式 CLI execution path：`NetworkProxyCommandRunner` 可执行 iOS `networksetup` / Android ADB command ledger 并返回 `ok=true`、`configured=true/false`、`sourceCommands[]`、audit limitation 与 restore 状态；fake runner 覆盖成功、`proxy_start_failed` 与 `proxy_restore_failed`。CLI 默认路径仍不会静默接真实 `runHostCommand`，必须额外带 `--execute-runner`。

P1 已补上 iOS / Android 原值 restore snapshot：`start --execute-runner --output <dir>` 会在 mutation 前写出 `<dir>/restore-state.json`，记录平台、target、host proxy endpoint、auditRecord、只读 snapshot ledger、start ledger 和 restore ledger；iOS 读取 `networksetup -getwebproxy/-getsecurewebproxy/-getsocksfirewallproxy/-getproxybypassdomains` 生成 `serviceSnapshots[]`，Android 读取 `settings get global http_proxy` 生成 `androidOriginalHTTPProxy` 并在 stop 时恢复原值或 delete。`stop --restore-snapshot <path> --plan-only` 会读取 snapshot 中的 restoreCommands 做非破坏审计；`stop --restore-snapshot <path> --execute-runner` 会优先执行同一组 restoreCommands。若 restore runner 失败，会在 snapshot 同目录写出 `restore-failure.json`，schema 为 `triton.proxy.restore-failure.v1`，并在失败 envelope 的 `artifacts[]` 中返回 `kind=proxy-restore`，保留 auditRecord、restoreSourceCommands 和错误摘要。后续 P1 继续实现证书/代理服务进程、真实 capture export 与 smoke 证据；Harmony 需要先验证真实 DevEco / Harmony 代理设置命令，不能从 Android 或 iOS 类推。

已补 `proxy endpoint preflight`：iOS / Android 只有在 `--proxy <host:port>` 可由 Mac host 建连时，才允许 `--execute-runner` 进入 `networksetup` / ADB mutation；不可达时返回稳定 `proxy_endpoint_unreachable`，保留计划 ledger，但不修改 host 或 emulator 代理状态。Android 的 preflight 检查 Mac host endpoint，ADB ledger 仍按 emulator 可访问地址写入，例如 host `127.0.0.1:19431` 对应 emulator `10.0.2.2:19431`。

已补文件态 proxy session：iOS / Android `start --execute-runner --output <dir>` 成功时会写出 `<dir>/session-state.json`，schema 为 `triton.proxy.session.v1`，并同步写出 `<dir>/requests.ndjson` 占位 capture artifact。session-state 会持久化 `cert` 状态，`device proxy status/export --session <dir>` 与 `sim proxy status/export --session <dir>` 可在后续 CLI 调用中读取同一个 session 目录，校验 platform / target 后返回状态或导出 capture artifact；旧 session 若缺少 `cert` 字段，则按对应平台保守证书状态回退。若只执行 `start` 而没有运行 `device proxy serve`，`requests.ndjson` 仍只是 `triton.network.v1` 占位文件；真实请求事件由 `device proxy serve` 写入。若 restore runner 失败后同目录留下 `restore-failure.json`，`status --session` 会在 `artifacts[]` 中补充 `kind=proxy-restore`，让后续诊断能发现恢复失败现场。`export --session <dir> --output <path.ndjson>` 会原样导出 capture artifact；`--output <path.har>` 会把 `proxy.serve.request` 事件转换为 metadata-only HAR skeleton。TLS 解密和更完整 redaction 仍属于后续切片。

已补三端共享本地 capture / mock / block / throttle proxy 服务：`triton device proxy serve --listen 127.0.0.1:19431 --output <dir> --mode record|mock|block|throttle --jsonl` 会启动 host-side HTTP proxy listener，写出 `<dir>/requests.ndjson`，并以 JSONL 输出 `proxy.serve.ready`、`proxy.serve.request`、`proxy.serve.connection-failed` 和最终 `proxy.serve.summary` event；`device` schema 同步声明 `jsonlEvents[]` 与 `finalEventKind=proxy.serve.summary`。该服务属于三端共用的 proxy endpoint：iOS / Android `start --proxy 127.0.0.1:19431 --execute-runner` 可通过平台 runner 指向它；Harmony 在真实 DevEco / Harmony 代理设置命令验证前仍不执行平台代理 mutation，但可以复用同一个 capture 服务作为人工或后续 adapter 的目标。当前服务记录 metadata-only request events，header 只保留 names、不写 header values / body；HTTPS `CONNECT` 只记录 tunnel 元数据，不做 TLS 解密。`record` 模式会尝试透传 upstream；`mock` 模式会记录同样的 metadata event，并直接向 client 返回固定 JSON mock 响应，不连接 upstream；`block` 模式会记录同样的 metadata event，并直接向 client 返回 `502 TritonKit Proxy Blocked`，不连接 upstream；`throttle` 模式会记录同样的 metadata event，并直接返回 `429 TritonKit Proxy Throttled` + `Retry-After: 1` 合成限流响应，不连接 upstream。mock / block / throttle 的 `proxy.serve.request` event 会直接写 `responseStatus` 与 `responseStatusText`，agent 不需要先导出 HAR 才能判断本地策略响应。当前 throttle 是稳定 rate-limit policy，不是带宽整形或真实延迟注入。

已补 `device proxy export --session` 导出摘要契约：成功导出 HAR / NDJSON 时，`NetworkProxySession` 直接返回 `requestCount`、`redaction` 与 `truncation`，agent 不需要反读 artifact 才能判断 capture 质量；占位 capture 会返回 `requestCount=0`、`redaction=default`、`truncation=none`，真实 `proxy.serve.request` 事件会按 metadata-only capture 统计请求数并返回 `redaction=headers-names-only`。capture artifact 缺失、不可读或导出写入失败时稳定返回 `ok=false`、`error.code=proxy_artifact_write_failed`、`error.nextAction.category=archive`，并保留目标输出 artifact path 供恢复。

已补 proxy session 到 `.tritonevidence` 的显式导入路径：`triton evidence --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` 与 `triton capture --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json` 会读取 `<dir>/session-state.json`，校验 `triton.proxy.session.v1`，并把 `session-state.json` 与 `requests.ndjson` 复制为 evidence artifacts。manifest 中 `network-capture` 作为高信号 primary artifact，`network.proxy-session` 与 `network-capture` 均标记 `redactionStatus=sensitive`，后续 `evidence summary/redact` 会按敏感证据处理。该导入路径已用 iOS Simulator、Android Emulator、Harmony / DevEco Emulator 三端 session fixture 覆盖，确保 platform / target 在 evidence manifest 中保真；同时已补 `evidence` / `capture` 两个真实 CLI argv smoke，确认 agent 实际调用 `--proxy-session` 时输出 JSON manifest 并复制 artifacts。它只归档已有 host-side proxy artifact，不执行新的平台代理 mutation，也不把占位 `requests.ndjson` 误判为已观察真实流量。若 session 元数据可读但 declared capture artifact 缺失或不可读，manifest 会保留 `network.proxy-session` artifact，只把 `network-capture` 记入 `skipped[]`，方便 agent 保留代理配置事实后继续走 archive recovery。若 session 目录中存在 `restore-failure.json`，或 session artifacts / restore snapshot 能定位到 restore failure artifact，导入路径还会把它复制到 `artifacts/network/restore-failure.json`，在 manifest 中标记 `kind=proxy-restore`、`redactionStatus=sensitive` 与 `policy=proxy-restore-failure-recovery`；这仍只是恢复失败现场证据，不代表平台代理已恢复成功。

已补三端网络接管任务规划入口：`triton plan network-proxy --platform ios|android|harmony --device <selector> --proxy 127.0.0.1:19431 --mode record|mock|block|throttle --output <proxy-session-dir> --certificate <path.cer> --audit-record <id> --evidence <dir.tritonevidence> --json` 会返回 host-only plan，按顺序给出 target resolve、proxy doctor、`device proxy probe --plan-only`、`device proxy cert plan`、`device proxy cert install --confirm --audit-record <id> --execute-runner` 审计命令、`device proxy serve --jsonl`、`device proxy start --plan-only`、`device proxy export --plan-only`、`evidence --include network.proxy-session` 和 `device proxy stop --restore-snapshot <restore-state-json> --plan-only`。当 `--output` 是具体目录时，`<restore-state-json>` 会落到该目录下的 `restore-state.json`。该 plan 即使 Triton embedded server 不可达也会生成，并在响应中保留 `serverReachable=false`；它只用于 agent 审阅和逐条执行，不自动执行真实平台代理 mutation、证书安装或 TLS 解密，也不证明 Harmony 已有 verified proxy / certificate setting command。

已补 `.tritonplan` replay 的 proxy 审计表达：`steps[]` 中 `action=evidence` 可声明 `include: "network.proxy-session"` 与 `proxySession: "<dir>"`，`triton plan inspect <file.tritonplan> --json` 会在 `steps[].argv` 中保留 `--proxy-session <dir>`，并在 `expectedArtifacts[]` 中暴露 `network.proxy-session` 与 `network-capture`；`triton replay <file.tritonplan> --dry-run --var platform=android --json` 会完成变量替换后输出同一 argv。`steps[]` 也可声明 `action=proxy-probe|proxy-serve|proxy-start|proxy-export|proxy-stop`，dry-run 会生成对应 `triton device proxy probe --plan-only`、`serve --jsonl`、`start --plan-only`、`export --plan-only`、`stop --restore --plan-only` argv，并保留 `network-capture` / `host-device-proxy` / `proxy-restore` 等 expected artifacts。`plan inspect` 还会在 `steps[].validationErrors[]` 中静态标出 missing platform、missing device selector、missing proxy endpoint、missing output path、export before start 和 stop without restore policy。真实 replay 执行 evidence step 时会把已有 session 传给 `.tritonevidence` 导入路径；若真实 replay 在业务 step 失败，后续业务 action / assertion 会停止，但 replay 会查找后续显式声明 `include: "network.proxy-session"` 与 `proxySession` 的 evidence step，并只执行 proxy-only evidence archive，把已有 session state 归档进 `.tritonevidence`。真实 replay 遇到 proxy lifecycle step 会返回 dry-run-only / unsupported，不启动 proxy listener，也不执行平台代理 mutation。

已补三端证书信任准备 plan-only 契约：`triton device proxy cert doctor --platform ios|android|harmony --json` 返回保守证书边界；`triton device proxy cert plan --platform ios|android|harmony --device <selector> --certificate <path.cer> --json` 返回 `action=proxy.cert.plan`、`configured=false`、`artifacts[].kind=proxy-certificate`、`cert.installed=false`、`cert.trusted=false` 和 `proxy_cert_untrusted` limitation。iOS ledger 只声明 `xcrun simctl keychain <target> add-root-cert <path.cer>`；Android ledger 只声明 `adb push` 加 `android.credentials.INSTALL` 用户安装 intent；Harmony 不输出未验证证书信任命令，并带 `proxy_cert_harmony_probe_only`。该入口不执行证书安装、信任配置或 TLS 解密。

已补证书信任 break-glass 执行入口：`triton device proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json` 只在三件套齐备时执行已审阅 ledger。iOS 成功 envelope 会标记 Simulator root cert 已安装/信任；Android 成功 envelope 只标记安装 intent 已打开，仍需用户在 emulator 内确认 CA 信任；两端失败稳定返回 `proxy_cert_install_failed`。Harmony 继续 probe-only，即使显式执行也返回 `proxy_unverified_platform_proxy` 与 `proxy_cert_harmony_probe_only`。

### 统一入口

```bash
triton plan network-proxy --platform ios|android|harmony --device <selector> --proxy 127.0.0.1:19431 --mode record|mock|block|throttle --output <proxy-session-dir> --certificate <path.cer> --audit-record <id> --evidence <dir.tritonevidence> --json
triton device proxy doctor --platform ios|android|harmony --json
triton device proxy probe --platform ios|android|harmony --device <selector> --json
triton device proxy cert doctor --platform ios|android|harmony --json
triton device proxy cert plan --platform ios|android|harmony --device <selector> --certificate <path.cer> --json
triton device proxy cert install --platform ios|android --device <selector> --certificate <path.cer> --confirm --audit-record <id> --execute-runner --json
triton device proxy serve --listen 127.0.0.1:19431 --output <dir> --mode record|mock|block|throttle --jsonl
triton device proxy start --platform ios|android|harmony --device <selector> --mode record|mock|block|throttle --output <dir> --json
triton device proxy start --platform ios|android|harmony --device <selector> --mode record|mock|block|throttle --output <dir> --plan-only --json
triton device proxy start --platform ios|android --device <selector> --mode record|mock|block|throttle --output <dir> --confirm --audit-record <id> --execute-runner --json
triton device proxy status --platform ios|android|harmony --device <selector> --json
triton device proxy status --platform ios|android|harmony --device <selector> --session <dir> --json
triton device proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson> --json
triton device proxy export --platform ios|android|harmony --device <selector> --session <dir> --output <path.har|path.ndjson> --json
triton device proxy export --platform ios|android|harmony --device <selector> --output <path.har|path.ndjson> --plan-only --json
triton evidence --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json
triton capture --include network.proxy-session --proxy-session <dir> --output <dir.tritonevidence> --json
triton plan inspect <network-flow.tritonplan> --json
triton replay <network-flow.tritonplan> --dry-run --var platform=android --json
triton device proxy stop --platform ios|android|harmony --device <selector> --restore --json
triton device proxy stop --platform ios|android|harmony --device <selector> --restore --plan-only --json
triton device proxy stop --platform ios|android --device <selector> --restore --confirm --audit-record <id> --execute-runner --json
triton device proxy stop --platform ios|android --device <selector> --restore-snapshot <dir>/restore-state.json --confirm --audit-record <id> --execute-runner --json
triton sim proxy start --simulator <udid|booted> --mode record|mock|block|throttle --output <dir> --plan-only --json
triton sim proxy start --simulator <udid|booted> --mode record|mock|block|throttle --output <dir> --confirm --audit-record <id> --execute-runner --json
triton sim proxy stop --simulator <udid|booted> --restore --plan-only --json
triton sim proxy stop --simulator <udid|booted> --restore --confirm --audit-record <id> --execute-runner --json
triton sim proxy stop --simulator <udid|booted> --restore-snapshot <dir>/restore-state.json --confirm --audit-record <id> --execute-runner --json
```

### iOS 兼容别名

```bash
triton sim proxy start --simulator <udid|booted> --mode record --output <dir> --json
triton sim proxy status --simulator <udid|booted> --json
triton sim proxy status --simulator <udid|booted> --session <dir> --json
triton sim proxy export --simulator <udid|booted> --output <path.har|path.ndjson> --json
triton sim proxy export --simulator <udid|booted> --session <dir> --output <path.har|path.ndjson> --json
triton sim proxy stop --simulator <udid|booted> --restore --json
```

### App 内 opt-in 入口

App 内流量接管只在业务 App 显式启用 runtime provider 后出现：

```bash
triton runtime network status --target <runtime-target> --json
triton runtime network export --target <runtime-target> --output <path.ndjson> --json
```

该入口只读取 App 主动上报的数据，不默认注入网络 hook。

## 三端能力矩阵

| 平台 | P0 目标 | 主要接管方式 | 主要限制 |
| --- | --- | --- | --- |
| iOS Simulator | `device proxy` + `sim proxy` 可启动、状态、导出、停止 | host-side proxy + simulator / host 代理配置 + 证书信任 | pinning、不走系统代理、自定义 socket、部分 QUIC |
| Android Emulator | `device proxy` 可启动、状态、导出、停止 | host-side proxy + emulator / adb proxy 配置 + 证书状态探测 | Android 7+ 用户 CA 信任策略、network security config、pinning、自定义 socket |
| Harmony Emulator | `device proxy doctor/status` P0，start 需真实验证后进 P1 | host-side proxy + HDC / 系统设置探测 + 证书状态探测 | DevEco / Harmony 代理配置命令需实测，平台证书策略和私有网络栈可能受限 |

### 2026-06-10 平台计划器状态

| 平台 | 当前实现级别 | 命令计划 | 执行策略 |
| --- | --- | --- | --- |
| iOS Simulator | fake adapter + `networksetup` override / restore planner + 原值 snapshot | HTTP / HTTPS proxy on，SOCKS off；restore 按 `networksetup -get*` snapshot 恢复 HTTP / HTTPS / SOCKS / bypass domains | 真实执行必须 break-glass + audit + restore snapshot |
| Android Emulator | fake adapter + ADB global proxy planner + 原值 snapshot | `adb -s <serial> shell settings put/delete global http_proxy`；host loopback endpoint 在 ledger 中映射为 `10.0.2.2:<port>`；restore 按 `settings get global http_proxy` 恢复原值或 delete | 真实执行必须 break-glass + target + audit；证书 trust 另切片验证 |
| Harmony / DevEco Emulator | fake adapter + HDC probe-only planner | `hdc -t <target> shell param get bootevent.boot.completed`、`hdc -t <target> shell echo triton-shell-ready` | 不执行未验证的系统代理设置；`start` 继续 unsupported |

### 2026-06-10 `--plan-only` 输出语义

- `ok=true`：TritonKit 成功生成该平台的机器可读接管计划。
- `configured=false`：没有修改 host 或 emulator 代理状态。
- `sourceCommands[]`：后续真实执行器需要审计、确认和恢复保护后执行的底层命令。
- Android 特例：`proxyEndpoint` 保留用户传入的 Mac host 监听地址，例如 `127.0.0.1:19431`；`sourceCommands[]` 面向 emulator 执行，loopback host 会写成 `10.0.2.2:19431`。
- `proxy_plan_only:not_executed`：明确该输出只是计划，不是已接管证明。
- `restore.restored=false`：stop plan-only 只生成恢复计划，没有执行恢复。
- `proxy_export_plan_only:artifact_not_written`：export plan-only 只声明 evidence artifact 目标路径，没有读取 session capture，也没有写出 HAR / NDJSON 文件。
- `destructive_action_requires_policy`：普通 start/stop 在没有 `--confirm --audit-record <id> --execute-runner` 任一项时被挡住。
- `proxy_runner_executed:break_glass`：iOS / Android start/stop 在三项策略齐备后调用了真实 command runner；这仍不是 capture/export 成功证明，只是代理 mutation 命令已按 ledger 执行。
- `proxy_harmony_probe_only:no_verified_proxy_mutation`：Harmony start/stop 即使带 policy 也只保留 probe-only，直到真实 DevEco / Harmony 代理设置命令被验证。
- `proxy_endpoint_unreachable`：执行 runner 前无法连接 `--proxy <host:port>`；该错误必须发生在任何 `networksetup` / ADB mutation 前，用来避免把模拟器/仿真器代理指向不存在的代理服务。
- `proxy_restore_snapshot_written`：start 已写出 `restore-state.json`，可用于后续 stop 恢复。
- `proxy_restore_snapshot_used`：stop 已按 `--restore-snapshot` 中的 restore ledger 执行恢复。
- `restore-state.json`：schema `triton.proxy.restore.v1`。iOS / Android 执行路径现在在 mutation 前记录 `snapshotSourceCommands[]`；iOS 同步写入 `serviceSnapshots[]`，Android 同步写入 `androidOriginalHTTPProxy`，使 stop 可恢复原始平台代理状态，而不是只做清空。
- `proxy_restore_failure_artifact_written`：`stop --restore-snapshot ... --execute-runner` 失败时已在 snapshot 同目录写出 `restore-failure.json`，失败 envelope 同步返回 `artifacts[].kind=proxy-restore`。
- `restore-failure.json`：schema `triton.proxy.restore-failure.v1`。记录 `platform`、`target`、`action`、`auditRecord`、`restoreSnapshotPath`、`restoreSourceCommands[]`、`errorCode`、`errorSummary` 和 `capturedAt`，用于后续 evidence/archive recovery，不代表恢复已成功。
- `proxy_session_state_written`：start 已写出 `session-state.json`，后续 `status/export --session <dir>` 可以跨 CLI 调用读取该 session。
- `session-state.json`：schema `triton.proxy.session.v1`。记录 `platform`、`target`、`captureMode`、`proxyEndpoint`、`configured`、`cert`、`visibility`、`limitations`、`artifacts[]`、`restoreSnapshotPath` 和 `sourceCommands[]`。
- `requests.ndjson`：`start --output` 会创建占位 artifact；`device proxy serve --output` 会追加 `triton.proxy.capture.v1` metadata-only request events。只有出现 `proxy.serve.request` 才能证明 capture proxy 收到过流量。
- `device proxy serve --mode record`：记录 request metadata 后尝试透传 upstream。失败时写 `proxy.serve.connection-failed`，不把失败伪装成业务通过。
- `device proxy serve --mode mock`：记录 request metadata，`policyAction=mocked`、`responseStatus=200`、`responseStatusText="TritonKit Proxy Mock"`，并直接返回固定 JSON mock 响应；该模式提供三端共用的 host-side mock 能力，不需要 App 内 SDK，也不代表 Harmony 平台代理 mutation 已验证。
- `device proxy serve --mode block`：记录 request metadata，`policyAction=blocked`、`responseStatus=502`、`responseStatusText="TritonKit Proxy Blocked"`，并直接返回 `502 TritonKit Proxy Blocked`；该模式提供三端共用的 host-side block 能力，不需要 App 内 SDK。
- `device proxy serve --mode throttle`：记录 request metadata，`policyAction=throttled`、`responseStatus=429`、`responseStatusText="TritonKit Proxy Throttled"`，并直接返回 `429 TritonKit Proxy Throttled` 与 `Retry-After: 1`；该模式提供三端共用的 host-side synthetic rate-limit 能力，不需要 App 内 SDK，也不代表真实带宽/延迟整形。
- `export --session ... --output <path.ndjson>`：原样导出 session capture artifact。
- `export --session ... --output <path.har>`：从 `proxy.serve.request` events 生成 HAR 1.2 metadata-only skeleton；forwarded request 的 response 仍是 `status=0/not captured`，mock / block / throttle request 会写入策略响应状态 `200 TritonKit Proxy Mock` / `502 TritonKit Proxy Blocked` / `429 TritonKit Proxy Throttled`；header values、request/response bodies、TLS decrypted content 和真实 response payload 均不会写入。
- `proxy.serve.ready`：`device proxy serve --jsonl` 已监听指定 `--listen` endpoint，输出 `capturePath`。
- `proxy.serve.request`：capture proxy 已收到一条 HTTP proxy request 或 HTTPS `CONNECT` tunnel request，并写入 metadata-only NDJSON event；mock / block / throttle 会在同一事件上写出本地合成响应的 `responseStatus` / `responseStatusText`。
- `proxy.serve.connection-failed`：capture proxy 未能解析、连接或转发当前请求；该事件会保留错误摘要，不代表业务请求成功。
- `proxy.serve.summary`：`device proxy serve --jsonl` 的最终 summary event，schema 中作为 `finalEventKind` 暴露，包含 `requestCount`、`capturePath`、`captureMode` 与 limitations。
- `device proxy serve --jsonl` command-level smoke 已覆盖真实命令输出路径：ready / connection-failed / request / summary 会出现在 stdout JSONL；`requests.ndjson` 只作为 capture artifact 追加 request / connection-failed 等事件，不写 final summary。
- `device proxy doctor/status` 现在会返回保守的 `cert` 状态：`installed=false`、`trusted=false`，iOS scope 为 `simulator`，Android / Harmony scope 为 `emulator`。这让 agent 能机器可读地判断 HTTPS 可见性仍受证书信任限制；该状态不是证书安装、信任配置或 TLS 解密证明。
- `device proxy cert plan` 现在会返回三端证书信任准备 ledger，但仍是 plan-only。iOS 使用 `simctl keychain add-root-cert` 作为待审计命令，Android 使用 `adb push` 和 `android.credentials.INSTALL` intent 作为待审计命令，Harmony 只返回 probe-only limitation，不编造 DevEco / Harmony 证书信任命令。
- `network-certificate-plan`：capability group 为 `host`，`requiredBy` 覆盖 `target/evidence/smoke/app`，`nextAction` 为 `triton device proxy cert plan --platform <platform> --device <selector> --certificate <path.cer> --json`；`proxy_cert_untrusted` 归入 diagnose / plan recovery。
- `proxy_capture_metadata_only:no_tls_decryption`：当前 capture proxy 不安装 CA，也不解密 TLS；HTTPS 只可见 CONNECT 目标 host / port。
- `proxy_capture_redaction:headers_names_only`：当前 capture proxy 只保存 header names，不保存 header values 或 body。

## 数据契约草案

### NetworkProxySession

```json
{
  "ok": true,
  "surface": "host.device-proxy",
  "action": "proxy.start",
  "platform": "ios",
  "target": "sim:<udid>",
  "lane": "host-proxy",
  "captureMode": "record",
  "proxyEndpoint": "127.0.0.1:19431",
  "configured": true,
  "cert": {
    "installed": true,
    "trusted": true,
    "scope": "simulator"
  },
  "visibility": "partial",
  "limitations": [
    "proxy_pinning_may_bypass: Certificate-pinned traffic may not be decrypted."
  ],
  "artifacts": [
    {
      "kind": "network-capture",
      "path": "network/requests.ndjson"
    }
  ],
  "restore": {
    "available": true,
    "snapshotPath": "network/restore-state.json"
  }
}
```

### 稳定错误码

- `proxy_tool_not_found`
- `proxy_start_failed`
- `proxy_not_running`
- `proxy_already_running`
- `proxy_config_failed`
- `proxy_restore_failed`
- `proxy_cert_untrusted`
- `proxy_visibility_limited`
- `proxy_unsupported_transport`
- `proxy_export_failed`
- `proxy_artifact_write_failed`
- `proxy_endpoint_unreachable`
- `proxy_platform_not_supported`
- `proxy_real_device_not_supported`
- `proxy_runtime_provider_unavailable`

## BDD 验收场景

### 场景一：agent 发现三端 proxy 能力

- Given 本机可能安装 iOS Simulator、Android Emulator、Harmony / DevEco Emulator
- When 执行 `triton capabilities --json`
- Then 输出 `device-proxy-ios`、`device-proxy-android`、`device-proxy-harmony`
- And 每个能力包含 `supported/reason/group/requiredBy/nextAction/evidence`
- And 不支持的平台返回 `supported=false` 和可恢复 `nextAction`

### 场景二：统一 doctor 告诉 agent 先修什么

- Given 代理服务、证书或目标设备可能缺失
- When 执行 `triton device proxy doctor --platform <platform> --json`
- Then 输出 target 可用性、proxy 可用性、证书状态、平台配置能力和限制
- And `primaryNextAction` 指向下一条 Triton 命令
- And 不要求 agent 读取 README 才能恢复

### 场景三：iOS Simulator 通过 host proxy 记录请求

- Given 一个 booted iOS Simulator
- When 先执行 `triton device proxy serve --listen 127.0.0.1:19431 --output <dir> --jsonl`
- And 再执行 `triton device proxy start --platform ios --device booted --mode record --proxy 127.0.0.1:19431 --output <dir> --confirm --audit-record <id> --execute-runner --json`
- Then 返回 `ok=true`、`lane=host-proxy`、`platform=ios`
- And `device proxy serve` 写出 network capture artifact
- And `triton sim proxy status --simulator booted --session <dir> --json` 返回同一 session 状态

### 场景四：Android Emulator 通过 host proxy 记录请求

- Given 一个 ready Android Emulator
- When 先执行 `triton device proxy serve --listen 127.0.0.1:19431 --output <dir> --jsonl`
- And 再执行 `triton device proxy start --platform android --device <serial> --mode record --proxy 127.0.0.1:19431 --output <dir> --confirm --audit-record <id> --execute-runner --json`
- Then Triton 配置 emulator 代理并返回机器可读状态
- And 当证书或 network security config 导致 HTTPS 不可解密时返回 `proxy_visibility_limited`
- And 不把代理配置成功误报为业务请求已被捕获

### 场景五：Harmony Emulator 能力先诊断再启用

- Given 一个 ready Harmony / DevEco Emulator
- When 执行 `triton device proxy doctor --platform harmony --json`
- Then 输出 HDC、系统代理设置能力、证书设置能力和缺口
- When 平台配置命令尚未实测可用
- Then `start` 返回 `proxy_unverified_platform_proxy`、`proxy_platform_not_supported` 或 `proxy_visibility_limited`
- And `nextAction.category=plan`

### 场景六：导出网络证据

- Given proxy session 已运行并产生请求
- When 执行 `triton device proxy export --platform <platform> --device <selector> --output <path.har> --json`
- Then 写出 HAR 或 NDJSON artifact
- And JSON 返回 path、bytes、redaction、requestCount、truncation
- And artifact 写入失败返回 `proxy_artifact_write_failed`

### 场景七：真实设备 target 不进入网络接管

- Given agent 传入 `scope=real`、`kind=real-device` 或 `ios-real:` / `android-real:` / `harmony-real:` selector 的 iOS / Android / Harmony target
- When 执行 `device proxy start|stop|status|export|cert plan` 或 break-glass runner helper
- Then 返回 `ok=false`、`error.code=proxy_real_device_not_supported`
- And `configured=false`
- And `sourceCommands[]` 与 `artifacts[]` 为空
- And `error.nextAction.category=diagnose`

### 场景八：停止并恢复代理状态

- Given proxy session 修改过 emulator / simulator 代理设置
- When 执行 `triton device proxy stop --platform <platform> --device <selector> --restore --json`
- Then 恢复原始代理设置
- And 返回 restore summary
- And restore 失败时返回 `proxy_restore_failed`，并把残留状态写入 evidence

### 场景八：App 内 opt-in 不改变默认 proxy 主线

- Given 业务 App 显式注册 runtime network provider
- When 执行 `triton runtime network status --target <runtime-target> --json`
- Then 返回 App 主动上报的 provider 状态
- And 该能力标记 `lane=app-runtime`
- And 未注册 provider 时返回 `proxy_runtime_provider_unavailable`
- And 不影响 `triton device proxy ...` host-side 能力

## 完成定义

1. 新增或更新 schema / capabilities / doctor / plan 契约，三端 proxy 能力可发现。
2. fake process runner 覆盖三端 proxy argv builder、parser、错误映射和 restore 行为。
3. 至少 iOS + Android 有真实 emulator smoke；Harmony 先完成 doctor / status 能力验证，start 进入 P1 实测切片。
4. `capture/evidence` 能收录 network artifact、proxy status、restore summary 和 limitations。
5. 文档、public skill、memory 同步更新。

## 分期

详细计划见 [plans/20260609-three-platform-network-takeover-plan-v01.md](plans/20260609-three-platform-network-takeover-plan-v01.md)。
