---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app, Harmony app, or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus host-side or embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Project Regression

## Principle

Real-project validation is not demo smoke. Treat the business app as an external system under test:

- Do not mix real-app repo changes into TritonKit commits.
- Prefer released `triton` for external adoption checks.
- Preserve command, JSON output, screenshot, evidence, or issue links for every finding.
- Do not publish private app identity, bundle IDs, accounts, internal hosts, private paths, credentials, full logs, or unredacted evidence.

For old/new Xcode checks, preserve scoped `triton device doctor --platform ios --json` output. `commandSupport` is `help-advertised-only`, not boot/install/launch or business validation. Simulator-only health does not depend on CoreDevice; all/real requires its discovery contract. Use the chosen DEVELOPER_DIR in the child environment without global switching, distinguish real toolchain runs from contract fixtures, and do not retry a state-changing operation via an alternate backend.

## Standard Workflow

1. Confirm app repo, branch, target device/simulator/emulator, and requirement.
2. Check both repos before changing anything:
   ```bash
   git status --short --branch
   ```
3. Prepare CLI and confirm binary:
   ```bash
   triton version --json
   ```
4. Start the local server explicitly when embedded runtime is needed:
   ```bash
   triton serve --host 127.0.0.1 --port 19421
   ```
5. Preserve Triton-first facts before fallback:
   ```bash
   triton doctor --json
   triton status --json
   triton capabilities --json
   triton schema --json
   ```
6. Observe before action, execute the smallest flow, then verify business state with `wait`, `verify`, screenshot, or evidence.
7. Redact before sharing externally.
8. If the real app exposes a TritonKit gap, use `tritonkit-dev-feedback` to prepare a redacted issue.

## Reference Routing

Start with [references/feature-index.md](references/feature-index.md) to map the requested feature to the smallest reference file. Then read only the matched reference(s).

## Common Commands

Triton-first facts:

```bash
triton doctor --json
triton status --json
triton capabilities --json
triton schema --json
triton list --json
```

Observation and verification:

```bash
triton observe tree --platform <ios|android|harmony> --device <selector> --outline --json
triton wait --text '<text>' --timeout 15 --json
triton verify text-exists '<text>' --json
triton screenshot --output /tmp/<case>.png --json
triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json
```

For an iOS Simulator coordinate-only action, use `triton act tap --device sim:<UDID> --at <x,y> --json`. This explicit host selector bypasses embedded `/targets`, preventing a same-Simulator stale/background runtime from being selected; a canonical `triton:ios-simulator:<UDID>/app:<bundle-id>` remains the exact embedded target form. Host-HID acknowledgement is not a business verdict, so always follow it with observation, wait/verify, screenshot, or evidence.

Treat evidence capture as one machine-readable completion gate: parse stdout as exactly one manifest and inspect `ok`, `partial`, top-level `error`, and every `skipped[].error`. Expected unsupported artifacts may yield `ok:true, partial:true`; request or artifact-write failures yield `ok:false, partial:true`, `error.code=evidence_capture_partial`, and a non-zero exit. Do not accept a bundle merely because some status/list/version artifacts exist.

Planning and replay:

```bash
triton plan ios-smoke --device <selector> --bundle-id <bundle-id> --url <url> --text <text> --evidence /tmp/<case>.tritonevidence --json
triton plan inspect <file.tritonplan> --json
triton replay <file.tritonplan> --dry-run --json
triton replay <file.tritonplan> --json
```

For recorder-derived flows, only `triton test import <case.tritontestcase> --output <plan.tritontest.yaml> --bundle-id <bundle-id> --device-platform ios-simulator --json`, then `triton test validate`, then `triton test run --target <target-id>` can lead to a real runtime verdict. If a future 3 × 20 reliability collection is being prepared, `triton test reliability-preflight --collection <private.json> --json` may freeze its private inputs only: accept `ready_to_collect` only with `writesEvidence=false`, `usesRuntime=false`, and `eligibleForReliabilityGate=false`; its negative control must not reuse a supported flow's normalized-plan digest and must declare an exact `expectedFailureType` for a non-optional, read-only terminal assertion. It does not boot/select a Simulator, start/reuse a server, reset an App, write evidence, or prove a verdict. Keep its private path/UDID/bundle/target/reset data out of public reports, then use a separately authorized live harness for actual collection. `testrec replay --dry-run`, `local-simulated`, and `matrix` are offline diagnostics: even if their compatibility fields say `ready`, `passed`, or `passedCount`, require `verdictBoundary.countsAsRealTestVerdict=false` and do not use them as regression evidence or reliability-gate samples. Treat an older replay result without this boundary as legacy/unknown, not affirmative proof.

For an explicitly authorized receipt-backed collection, run `test reliability-reserve` only against a fresh private root, record its lowercase `receiptSha256` in operator/CI state outside that root, then call `test reliability-sample` one slot at a time with `--expect-receipt-sha256 <64-lowercase-hex>`, `--confirm`, exact canonical iOS Simulator/App target, private reset receipt, and an operator-owned already-running `127.0.0.1:19421` server. Receipt-backed `test reliability --collection-receipt` requires the same expected anchor before it scans evidence. Never derive the expected anchor from the current root just before use: it would not detect a complete receipt replacement. The receipt root holds a collection-wide lease: a busy or stale lease fails closed before target execution and must not be deleted or reused automatically. It must not manage App/Simulator/server lifecycle or clean/retry evidence. Treat the sample's single typed JSON result as the verdict contract: an expected negative nonpass is `ok=true` / exit 0 only for terminal `failed` with the exact frozen assertion failure type; a supported nonpass, unexpected negative pass, or wrong negative failure type is `ok=false` / exit 1 without a second error envelope. Legacy `test reliability --samples` is diagnostic-only and cannot pass the Stage 1 gate. Configuration, receipt anchor, reset, or target rejection is a single `TKCLIErrorResponse`. SHA-256 anchor checking is not a signature, identity proof, remote ledger, or hostile-filesystem defense. Do not begin a live collection without explicit dedicated-target, reset, server-ownership, negative-control, and private-evidence authorization.

After a receipt-bound runner finishes, it must seal one private `reliability/identity-chain-v2.json` only if binding, reset receipt, normalized plan, runtime target, `run/run.json`, and `run/events.jsonl` all exist; a write or component failure preserves the claimed slot and must not be backfilled, cleaned, or rerun automatically. Receipt-backed report exposes only `identityChain.state`, expected/valid/missing/invalid counts, and `receiptAnchorVerified`: missing v2 chains block as `identity_chain_incomplete`, while body/frozen identity/terminal evidence/component/manifest disagreement blocks as `identity_chain_invalid`. These are offline byte-consistency checks, not evidence that reset, App/runtime execution, history, target exclusivity, or hostile-filesystem integrity was real; never put chain hashes, private paths, target/bundle/UDID, flow, run, or reset identities in a public regression report.

For receipt-backed reports, read the additive `stage1` cohort contract rather than conflating the compatible top-level metrics: `stage1.stage1A` is only the 60 supported slots (3 flows × 20) and owns supported ECR/ORR plus strict per-flow completeness; `stage1.stage1B` is all 61 receipt/control slots and owns full receipt integrity plus FER across every terminal failed/blocked slot, including the expected negative control and any supported nonpass. Legacy `reliability --samples` has model value `stage1=nil` and omits that JSON field. For receipt-backed output `stage1.gate` must equal the top-level gate; an integrity-only Stage 1B blocker is not `stop_expansion`. Report only counts, rates, statuses, and blocker codes—never any private slot identity.

## Completion Gate

- Requirement has machine-readable pass/fail evidence.
- Real app repo changes are isolated and explicitly reported.
- TritonKit repo changes, if any, have focused tests and docs/memory updates.
- Public handoff is redacted.
- Any product gap is turned into a doc update, code fix, or redacted GitHub issue.

## Device Hub readonly metadata evidence

`device files --platform ios --device <selector> --domain-type systemCrashLogs --json` is standalone shallow metadata, not contents/copy or business verification. App domains require --domain-identifier; optional --subdirectory/--username must match file-JSON request scope. Default opaque tokens/safe metadata keep names/relative paths/owners/xattrs/content/rawIDs private; --include-sensitive deliberately adds only names/relative paths, never publish that private output. JSON/count limits are local acceptance, not remote traversal/transport/disk caps. temporary is policy-required before backend, not platform unsupported. Preserve exact unsupported_device_file_query without silent DeviceFS retry; only explicitly owned Simulator acceptance may boot/restore, verify every other name/state unchanged. Never borrow business instances or infer readiness/regular-file/writable authorization from file metadata.

For a deliberate `device mountpoint --platform ios --device <selector> --json` query, preserve exact echoed-device binding, private artifacts and token-only output. It does not inspect/verify a native path or mount state, list contents, prove readability/writability or business readiness. Do not stat/open/traverse returned dataPath, start Finder, explicitly mount/unmount or silently fallback from files; no automatic target preparation. Service/private artifact side effects remain; use only task-owned Simulator lifecycle acceptance and verify restoration/other names-states. Unknown backend failures query_failed; never infer platform unsupported from absent evidence.

Hardware provenance preflight via device info: optional hardware.platformObservation exact explicit hardware system/device/reality plus modern/legacy layout, old archived missing field nil-compatible. No name/product/runtime/marketing/legacy ios/capabilities OS/iPadOS/physical inference; iOS+iPad stays ios/ipad, absent reality unknown, modern present/null/partial blocks stale mirrors. Do not echo unknown observation raw values, authorize controls/business readiness, or alter IDs/dispatch/argv. Validate nested schema/bound CLI roundtrip and current readonly physical info; fixtures other families not live control proof.

Regression platform preflight: `device platforms --json` compiled six-family catalog only, optional --apple-platform filter, --inventory one availableSimulator metadata/globalcounts with unknown. No default host queries/physical/boot/control/server or rawIDs/names/runtime. Never infer iPadOS/iPhone-iPad from iOS runtime/name or assume Mac Simulator; 0 not unavailable. Report-only control/auth false not prior action denial, generic command surface/cap arrays not platform-specific acceptance. Validate provider counters/static failure privacy/strict rawidentifier fixtures plus actual envelopes; old ios namespace/IDs/argv retained, physical/platform action evidence remains separate.

Administration regression and feedback must distinguish readonly --plan-only, fixture-tested explicit execution, and separately authorized physical acceptance. Use the Device Hub 能力组 section below; do not execute real pairing or diagnostic collection without task authorization. Private native logs and identifiers must remain local.

For bounded relative directory add `--subdirectory <relative-directory>` with explicit native container/app view only. 1...32 raw components/4096 UTF8 bytes/255 each, no absolute/dot/dotdot/empty/control or normalize/URLdecode; root/every relative-layer owner/noFollow same FD. Input and standard-root shape64/16384 budget preflight before discovery/artifacts; never query/open UUID placeholder, fresh actual root parent UTF8 bytes + UUID binding and repeated combined guard before directory IO. Exact subdir byte token scopes, omitted old tokens, no scope-field echo. Opted-in existing directory only; actual owned default/optin privacy0700-0600/budgets/finally all names-state restore; zero metadata not readiness, overflow must actually be observable else mark fixture-only. No content/recursive/outsidecontainer/Finder/autoprep/fallback/Temporary-domain creation.

For one native container add `--container-identifier <native-child-name>` with app-data/app-group view only, one raw 1...255 UTF8 byte component, no dot/dotdot/slash/control. Not verified bundle/group identity/install proof; validate before discovery/artifacts, same-FD root/every-relative-layer owner/nofollow. Selection fields never echo input; directoryToken and entry scope hash exact view/container bytes, not secret/auth proof, opt-in leaf names may coincide with input. Omitted tokens preserved; default names private. Actual owned acceptance must use opt-in namespace candidate explicitly, metadata-only both default/opt-in, bounds/0700-0600 and finally all name/state restore; no App install/launch/content/recursive/outside-containerpath/fallback.

Explicit `device fs list --platform ios --device <selector> --json` is fixed namespace shallow metadata only (--view mount-root default|app-data-containers|app-group-containers), no bundle/group-ID navigation. Check root owner before namespace open then namespace owner in same FD chain. Exact descriptor type devicefs admits native synthetic dirent/stat ID difference, always double nofollow stat inode/device/kind; other FS types strict dirent binding; entryIdentityVerification not atomic/provenance proof. Mount-root token compatible, namespaces view-salted: fresh fileJSON identity+standard parent/currentUUID root, same final FD owner/nofollow, no content/recursive/domain mapping. Default entry names private, include-sensitive names only; never publish nativepaths/private artifacts. hostFilesystemInspected=true does not prove mount provenance, read/write authorization or business readiness. No automatic files failure fallback/boot/pair/unlock/Finder/explicitmount; query timeout not FUSE cancellation/remotehardlimit/atomic snapshot. Real acceptance requires owned only lifecycle/restoration and all names-state comparison, not fixture-only success; physical listing is not claimed by Simulator acceptance.

## 2026-09 issue 合同补充

- `xcode test --jsonl` 默认 compact；完整 raw 日志在 artifact，显式 `--progress full` 才转发。按子命令 schema 选参数，`xcode run` 不接受 `--progress`。
- DerivedData 存在不证明 cache 命中。`reuseVerification=unknown`，`incrementalExpected=false` 仅表示没有验证过的预期；读取 `observedBuild.taskLogCounts/logCoverage`，不擅自称增量或全量。
- 排查 repo-local 构建缓存占用时先运行 `triton xcode derived-data inspect --root .triton/DerivedData --json`；cleanup 默认 dry-run，只有确认候选和预计释放量后才显式追加 `--confirm`。仅接受 canonical repo-local `.triton/DerivedData` 或用户全局 Xcode DerivedData root；Xcode 构建进行中不要清理。
- `debug attrs --oid` 支持 UIView/CALayer oid；UILabel 的有效字体/颜色与 UTF-16 run 有界输出，正文预览和 run 都要检查截断字段。
- collection cell 激活尊重 allowsSelection/delegate，success 只证明公开 callback，必须验证业务后置条件。`act tap --duration` 不支持长按，提前 typed unsupported；embedded longPress 和非滚动手势也不伪造成功，使用 App 显式注册的 semantic DEBUG action 或检查实际 provider 能力。
- Harmony ArkWeb bridge-call 需可达 DevTools socket 与页面 `window.__tritonBridge.methods` 自有函数白名单；函数接收 `(params, complete, reject)`，支持返回值/Promise/callback。明确选中 CDP page ID，stale/ambiguous 失败关闭；不把 CDP page ID 当导航 session 验证，清理失败也可能发生在页面方法已执行之后，重试前先验业务状态。

## Device Hub 能力组（2026-10-10）

`device containers --device <selector> --bundle-id <id> [--group-id <id>] [--list] --json` 查询 SDK 显式 bundle/group membership 与容器路径绑定，默认只公开 tokens、状态和能力边界。`--list` 只对所选 Simulator 的受限原生容器做浅层元数据读取，逐级 nofollow/owner/预算检查，不读取业务内容。真实设备支持 SDK 元数据，不将其设备路径当作本机路径打开。旧 SDK 缺少参数明确 unsupported，缺绑定字段 unavailable；不能按 App 名/目录名猜归属，`deviceFSBindingVerified=false` 始终保留。

Crash 的三条契约独立：`device files --domain-type systemCrashLogs` 是 CoreDevice 浅元数据文件域；`device fs list --view diagnostic-reports` 只枚举 DeviceFS 明确的 `DiagnosticReports` namespace，缺目录就失败，不能猜 root 映射或宣称与文件域逐项等价；`device diagnose` 是敏感诊断 ZIP 采集，可能含宿主日志。均不得由目录存在推导额外权限。

Temporary 查询可能创建客户端域，实际是否新建没有可靠后置证据。默认继续返回 `device_file_domain_policy_required`；只有 `device files --domain-type temporary --domain-identifier <client-id> --allow-domain-creation --confirm --execute-runner --audit-record <id>` 才允许执行，执行前持久审计，`riskLevel=automation`、creation unknown，失败可能已经创建且不自动重试。本轮无真实 Temporary 查询。

`sim pairs --json` 读取原生 watch/phone 配对关系，不证明输入、连接或业务就绪。`device platforms --include-real-devices [--device <exact-id-or-inventory-token>] --json` 独立发现/选择 Apple physical 硬件元数据；只有 SDK 显式 physical 纳入，不从名称、transport 或 capability 数组推断，旧 iOS 路由不扩大。Crown/侧键、tvOS 焦点/选择/返回、visionOS 视角/场景/专门输入仍无已验证程序后端，明确未支持；macOS 仍区分 Xcode build/test 工作流与 Device Hub 控制。

`device pair|unpair|diagnose --platform ios --scope real --device <selector> --plan-only --json` 保留只读策略审查。执行后端要求 `--execute-runner --confirm --audit-record <id>`；diagnose 另需 `--output <private.zip>`，可设 `--maximum-archive-bytes`。先持久化 intent，再单次原生命令、严格 file-JSON 绑定和独立配对后置状态 / 诊断 ZIP 检查，最后写 completion；成功、失败、超时、部分完成分开，未知状态不重试。诊断仍可能包含宿主 CoreDevice 日志，即使关闭 host sysdiagnose；与 Crash 日志域不同。输出目录须已存在且仅当前用户可访问，拒绝覆盖/符号链接，0600 发布及本地大小限额不等于原生采集峰值限制。外部工具使用路径，前后 inode 检查不消除同用户并发替换风险。此后端本轮仅隔离 fixture 验证，未获真机执行/诊断采集验收授权；旧 `sim pair/unpair/diagnose` 保留。
