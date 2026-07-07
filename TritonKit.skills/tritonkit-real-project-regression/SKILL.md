---
name: tritonkit-real-project-regression
description: Use when TritonKit moves from demo/self-test into a real iOS app, Harmony app, or customer project for regression testing, adoption validation, or actual requirement discovery. Guides the AI agent to isolate external repo changes, run release CLI plus host-side or embedded runtime checks, collect machine-readable evidence, and turn real-project gaps into docs, fixes, or GitHub issues.
metadata:
  version: 0.1.0-dev
---

# TritonKit Real Project Regression

## Principle

Real-project validation is not the same as demo smoke. Treat the business app as an external system under test: avoid mixing its local changes into TritonKit commits, collect reproducible evidence, and keep every finding traceable to a command, output file, screenshot, or issue.

## Workflow

1. Confirm the real app, target branch, device/simulator, and the requirement being validated.
2. Check both repos before changing anything:
   - TritonKit: `git status --short --branch`
   - real app repo: `git status --short --branch`
3. Prepare the macOS `triton` CLI:
   - Prefer the released Homebrew binary when validating an external app: `brew install NeptuneKit/tap/triton` or `brew upgrade triton`.
   - If testing unreleased TritonKit changes from this repo, keep using the local release CLI.
   - If copying the local build into an existing `PATH` location while `triton serve` may be running from that path, stop the server first or replace through a temporary file and same-directory `mv`.
   - Confirm the active binary with `triton version --json` or `.build/cli/release/triton version --json`.
4. Integrate TritonKit into the app only through the intended DEBUG-only package path when embedded runtime access is required:
   - If the task only needs Harmony host-side emulator discovery, readiness, app inspect, or app launch, do not add an app dependency; use the Harmony host-side commands below.
   - If the task needs iOS embedded runtime access, use the iOS package path below.
   - If the task needs Harmony embedded runtime access, use the Harmony package/source path below and keep provider semantics opt-in.
   - SwiftPM or CocoaPods as requested; CocoaPods examples must use `:configurations => ['Debug']`.
   - For SwiftPM, distinguish build settings from product dependencies: TritonKit uses the package `TRITONKIT_RUNTIME_ENABLED` Debug compile flag, but SwiftPM still does not provide CocoaPods-style configuration-scoped product dependencies. Keep source-level `#if DEBUG` isolation, or create a separate Debug-only app target/scheme if Release must not link TritonKit at all.
   - For CocoaPods, the `TritonKit` podspec defines `TRITONKIT_RUNTIME_ENABLED` for the pod target Debug configuration. Do not ask the app target to add custom `OTHER_SWIFT_FLAGS` for this macro.
   - Put all app-side TritonKit code in a dedicated iOS file such as `TritonKitDebugBootstrap.swift`.
   - Wrap the entire file in `#if DEBUG`, including `import TritonKit` and `TritonKit.shared.start(...)`.
   - Call the bootstrap only from a `#if DEBUG` branch in AppDelegate, SceneDelegate, or SwiftUI `onAppear`.
   - Prefer `TritonKit.shared.start()` or the `start { config in ... }` facade; only use lower-level `delegate` / `connect(host:port:)` when the real app needs a custom delegate.
5. Start server with explicit port: `triton serve --host 127.0.0.1 --port 19421`.
   - If a human reviewer needs the readonly Web Device Hub during the same investigation, prefer `triton web --print-command --json` before launching it; released/Homebrew CLIs serve bundled `web/` assets and source checkouts use `Web/` Vite dev mode. Preserve the launch plan and treat `triton web` as observation-only support, not as proof of business control.
6. Verify connection and target identity:
   - `triton doctor --json`
   - `triton status --json`
   - `triton capabilities --json`
   - before using `baguette`, raw `xcrun` / `simctl`, `hdc`, `adb`, DevEco Emulator CLI, XcodeBuildMCP, or raw `xcodebuild`, preserve Triton-first fallback gate evidence from `status`, `doctor`, `capabilities`, `schema`, or `plan`; fallback is allowed only after Triton reports failure, unsupported capability/scope, or missing schema/capability for the required local emulator action;
   - use `doctor.checks[]` first for ordered recovery, and preserve `doctor.nextWorkflows` plus each check's `workflowCategories` so the regression report keeps the affected workflow taxonomy without re-deriving it from capabilities;
   - `triton list --json`
   - use `capabilities[].group`, `requiredBy`, `nextAction`, and `evidence` to decide whether the next step is target selection, runtime connection, Xcode preparation, action execution, assertion, or evidence capture; if a schema-provided capability lacks those planning fields, treat that as a TritonKit contract bug before relying on it;
   - treat duplicate capability names in schema or capabilities output as TritonKit indexing bugs before deriving a reusable regression plan;
   - treat empty or duplicate `requiredBy` / `evidence` entries as TritonKit metadata bugs; reusable regressions need clean workflow and artifact categories;
   - for iOS `AVPlayer` / `AVPlayerViewController` flows, run `triton debug snapshot --include media,ax,screenshot-metadata --json` before asserting playback; preserve `media.surfaces[]`, `media.controls[]`, `automationConfidence`, `fallbackAdvice[]`, and `evidenceCommands[]`;
   - if media `automationConfidence` is `surface-only`, treat rendered video as observation evidence only; require app-owned DEBUG overlay controls with stable accessibility identifiers before claiming pause, resume, seek, elapsed, duration, progress, or route-release control assertions;
   - for app-domain readiness that cannot be proven from generic UI, inspect `triton debug runtime manifest --json` `semanticDomains[]` first, then run `triton debug snapshot --include semantic,app,scene --json`; preserve `semantic.domains[]`, provider `source`, `confidence`, `state`, `schema`, `actions`, `redaction`, and `evidenceCommands[]`;
   - treat `app-semantic-state` as provider-backed business state and `app-semantic-action` as provider action-catalog discoverability. Do not build reusable regressions around generic provider action execution until a dedicated command contract exists;
   - treat unknown `capabilities[].group` values as TritonKit taxonomy bugs; reusable regressions should only depend on the fixed groups `action`, `assert`, `bootstrap`, `evidence`, `host`, `observe`, `semantic`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview`, and `xcode`;
   - treat unknown `capabilities[].requiredBy` values as TritonKit workflow taxonomy bugs; reusable regressions should only depend on `action`, `app`, `assert`, `evidence`, `observe`, `project`, `replay`, `route`, `runtime`, `smoke`, `target`, `webview-check`, and `xcode`;
   - treat unknown `capabilities[].evidence` values as TritonKit artifact taxonomy bugs; reusable regressions should rely on real stdout JSON, schema/status output, host artifacts, runtime snapshots, WebView provider output, route assertions, input results, evidence bundles, smoke summaries, tritonplans, Xcode artifacts, or unsupported envelopes;
   - treat empty `capabilities[].evidence` arrays as TritonKit contract bugs before building a reusable regression; every capability needs at least one machine-readable proof source;
   - verify `capabilities[].nextAction` against schema before turning it into a reusable script; platform-specific app install flags must match the target, for example iOS `--app <path.app>` versus Harmony `--hap <path.hap>`;
   - treat `nextAction.requiresLongRunningProcess=true` as valid only for real long-running process commands such as server bootstrap, JSONL build, or host proxy serve; when present, verify `readyEvents`, `finalEvents`, and `terminationSignals` before daemonizing it, and never daemonize ordinary target, observe, action, assertion, or evidence commands;
   - treat malformed `nextAction.args` placeholders as TritonKit contract bugs; reusable regressions should receive placeholders as standalone argv tokens, not string fragments that require custom parsing;
   - treat malformed placeholders in schema next commands, schema examples, or plan step commands as TritonKit contract bugs; reusable regressions should not depend on shell redirection or partial placeholder strings;
   - treat blank or duplicate command-level/subcommand-level `nextCommands[]` entries as TritonKit recovery list quality bugs before copying recovery suggestions into reusable regression scripts;
   - treat schema `nextCommands[]` root commands outside the recovery command taxonomy as TritonKit contract bugs; reusable regressions should only copy recovery suggestions whose root command has a defined diagnostic, discovery, target, project/Xcode, observe, action, assert, evidence, replay, or smoke role;
   - treat recovery roots without a stable category as TritonKit taxonomy bugs; reusable regressions should know whether a suggestion is `diagnose`, `discover`, `prepare-target`, `project`, `observe`, `act`, `verify`, `archive`, `replay`, `smoke`, or `plan`;
   - prefer schema `recoveryCommands[]` when constructing reusable recovery branches; it must mirror `nextCommands[]` and expose one `{command, category}` entry for each recovery suggestion;
   - treat `failureCodes[]` that cannot be mapped to valid recovery category families as TritonKit taxonomy bugs; reusable real-project flows should be able to classify `error.code` before choosing concrete recovery commands;
   - treat artifact/output failure codes without an `archive` recovery category as TritonKit recovery coverage bugs; real-project regressions need evidence/capture/export-style next steps when output paths are rejected, writes fail, or artifacts are too large;
   - treat assertion/route/text-not-found failure codes without a `verify` recovery category as TritonKit recovery coverage bugs; reusable regressions should have wait/assert/route-style next steps when expected UI or navigation state is not met;
   - treat runtime transport failure codes without a `diagnose` recovery category as TritonKit recovery coverage bugs; reusable regressions need status/doctor/capabilities-style next steps when server, runtime, or request transport fails;
   - treat target failure codes without a `prepare-target` recovery category as TritonKit recovery coverage bugs; reusable regressions need target/device/sim/app-style next steps, preferably `triton target resolve <selector> --platform <platform> --scope <scope> --json`, when a selector is ambiguous, missing, offline, not ready, or unavailable;
   - treat Project / Xcode failure codes without a `project` recovery category as TritonKit recovery coverage bugs; reusable regressions need Xcode discovery/defaults next steps, preferably `triton xcode discover --path . --json`, when workspace, scheme, or Xcode idle state is missing, ambiguous, invalid, or unavailable;
   - treat action/step failure codes without an `act` recovery category as TritonKit recovery coverage bugs; reusable regressions need executable action next steps, preferably `triton act input --json --summary --strict`, when an action batch or replay step fails;
   - treat destructive/confirmation failure codes without a `plan` recovery category as TritonKit recovery coverage bugs; reusable regressions need planning or policy-review next steps, preferably `triton plan --format json`, when a host-side destructive command requires confirmation or policy;
   - treat unsupported failure codes without a `plan` recovery category as TritonKit recovery coverage bugs; reusable regressions need capability-boundary planning next steps, preferably `triton plan --format json`, when a runtime, WebView, provider, or action capability is unavailable or method-blocked;
   - treat missing or mismatched `capabilities[].nextAction.category` as TritonKit capability contract bugs; reusable regressions should know each capability's next-step stage without parsing command roots by hand;
   - treat missing `doctor.checks[].nextAction.category` in the doctor output contract as a TritonKit diagnostic contract bug; reusable regressions should get the same stage vocabulary from doctor, capabilities, and plan;
   - treat missing or invalid `doctor.checks[].workflowCategories` as TritonKit diagnostic planning bugs; reusable regressions should be able to see which workflow taxonomy each doctor check blocks before consulting the full capabilities matrix;
   - treat missing or invalid `doctor.nextWorkflows` as TritonKit diagnostic planning bugs; reusable regressions should be able to identify the first actionable blocked workflow directly from the doctor root;
   - treat missing or invalid `plan.nextWorkflows` as TritonKit planning routing bugs; reusable regressions should be able to see whether the recommended lane is `smoke`, `app`, `route`, `assert`, `evidence`, or `target` before parsing individual step commands;
   - treat missing or invalid `plan.steps[].workflowCategories` as TritonKit planning routing bugs; reusable regressions should be able to enter a concrete step and still know which workflow taxonomy it belongs to, without rebuilding that mapping from command strings;
   - treat missing or invalid replay inspect / dry-run `steps[].workflowCategories` as TritonKit replay routing bugs; reusable regressions should be able to compare offline inspect and dry-run against the same workflow lane vocabulary before touching the app;
   - treat missing `error.nextAction.category` in `TKCLIErrorDetail?` output contracts or failure shapes as TritonKit error-envelope contract bugs; reusable regressions should route failures by category without parsing human-readable hints;
   - treat shell control operators in `plan.steps[].command` as TritonKit plan bugs; reusable regressions should receive single Triton invocations as the human-readable/logging form and express stdin/file prerequisites through metadata or the surrounding plan;
   - prefer `plan.steps[].argv` over parsing `plan.steps[].command`; if argv is missing or empty, report a TritonKit plan execution contract bug before building reusable runners;
   - treat missing or mismatched `plan.mode` as TritonKit plan contract bugs; reusable regressions should know whether a plan is bootstrap recovery or goal-specific workflow planning before selecting runners;
   - treat missing or mismatched bootstrap response `surface` fields as TritonKit contract bugs; reusable regressions should be able to distinguish status facts, ordered diagnostics, capability matrices, and plan responses from JSON alone;
   - treat missing or mismatched `plan.steps[].category` as TritonKit plan bugs; reusable regressions should know each step's workflow stage without parsing command roots by hand;
   - treat missing `plan.steps[].requires`, `plan.steps[].expectedArtifacts`, or `plan.steps[].stopConditions` as TritonKit plan bugs; reusable regressions should know prerequisites, evidence, and stop gates before executing a real app flow;
   - treat missing `steps[].argv`, `steps[].category`, `steps[].requires`, `steps[].expectedArtifacts`, `steps[].stopConditions`, or `steps[].validationErrors` from `triton plan inspect <file.tritonplan> --json` as replay-plan inspect bugs; reusable regressions should be auditable offline before `replay --dry-run` or execution;
   - treat missing `steps[].argv`, `steps[].category`, `steps[].requires`, `steps[].expectedArtifacts`, or `steps[].stopConditions` from `triton replay <file.tritonplan> --dry-run --json` as replay result bugs; reusable regressions should compare dry-run `steps[].argv` and step metadata against inspect metadata before touching the app;
   - treat replay dry-run accepting statically invalid steps as TritonKit validation bugs; reusable plans should fail before touching the app when `tap` has multiple selectors, `wait` has multiple conditions, `paste/type` lacks text, or `wait` lacks a condition;
   - before building reusable parsers or regression assertions from schema output, check that relevant `outputContracts[]` entries have non-empty `selector`, `model`, and field definitions with field `name`, `type`, and `description`; missing details are TritonKit contract bugs, not app integration issues;
   - treat duplicate `outputContracts[].selector` values within the same command as TritonKit schema lookup bugs before deriving reusable parsers or assertions;
   - treat any `subcommands[].outputSelectors[]` value that is absent from the parent command's `outputContracts[].selector` set as a TritonKit schema lookup bug before deriving reusable parsers or assertions;
   - if a schema command advertises a failure shape or non-zero failure exit but has empty `failureCodes[]`, report a TritonKit schema bug before relying on it for automated recovery;
   - if `failureCodes[]` contains non-lower_snake_case values or duplicates, report a TritonKit schema recovery bug before mapping `error.code` to reusable regression recovery logic;
   - if a subcommand exposes a failure code that is absent from the parent command schema, report a TritonKit schema consistency bug; reusable regressions should not need to merge undocumented parent and child code sets by hand;
   - if options or subcommands have empty names, empty option types/descriptions, empty subcommand summaries, or duplicate names in the same parent command, report a TritonKit schema quality bug before turning the schema into reusable automation;
   - if command names, subcommand names, or pure long flag aliases are not stable lower-kebab CLI keys, report a TritonKit schema routing bug;
   - if Subcommand / Task usage synopsis appears in `options[]` instead of `usageForms[]`, report a TritonKit schema-shape bug before deriving an option parser from it;
   - if positional arguments appear in `options[]` instead of `argumentForms[]`, report a TritonKit schema-shape bug before deriving argv or flag validation from it;
   - if `subcommands[].requiredOptions[]`, `optionalOptions[]`, or `oneOfRequiredOptions[]` references a flag or positional argument absent from the parent command's `options[]` or `argumentForms[]`, report a TritonKit schema reference bug before building a reusable regression;
   - if a command with `subcommands[]` also has non-empty command-level `requiredOptions[]`, report a TritonKit schema-shape bug; reusable regressions should read subcommand requirements from the subcommand itself, not from parent-level prose summaries;
   - if `defaultProviders[]` or `inheritsDefaultsFrom[]` contains something other than a schema-backed `triton ...` command, report a TritonKit planning contract bug before relying on that default source;
   - if command-level or subcommand-level `artifacts[]` contains unknown or duplicate values, report a TritonKit artifact taxonomy bug before relying on those artifacts in a regression report;
   - if `jsonlEvents[]` contains malformed or duplicate event keys, or `finalEventKind` is missing from the same `jsonlEvents[]`, report a TritonKit JSONL event contract bug before building long-running command monitors;
   - if a schema object is `retryable=true` but has empty `nextCommands[]`, report a TritonKit recovery contract bug before making it part of a reusable real-project flow;
   - if a command or subcommand exposes `failureCodes[]` but neither that object nor its parent command provides a usable `nextCommands[]` recovery path, report a TritonKit recovery contract bug before relying on it for automated regression recovery;
   - if schema examples use commands or flags that schema does not declare, report a TritonKit schema/example contract bug instead of copying the example into a real project regression script;
   - treat `plan-inspect` as offline `.tritonplan` summary inspection and `replay-dry-run` as offline validation only; real replay, smoke, wait, assert, and evidence capture remain separate proof steps.
   - for iOS Simulator embedded runtime, confirm `triton list --json` exposes `triton:ios-simulator:<SIMULATOR_UDID>` and `simulatorUDID`;
   - if multiple iOS Simulator runtime targets are connected, pass `--target <SIMULATOR_UDID>` or `--target triton:ios-simulator:<SIMULATOR_UDID>` for runtime commands; default `triton:local` should return `ambiguous_target`.
   - `triton debug runtime manifest --json`
   - `triton debug state app --json`
   - `triton debug state scene --json`
   - `triton debug state route --json`
   - `triton debug state responder --json`
   - `triton debug snapshot --include app,scene,route,ax,geometry --json`
   - `triton debug ledger --limit 50 --jsonl`
   - when the real app has hybrid pages, verify WebView state explicitly:
     - `triton webview list --platform ios --json`
     - `triton webview current --platform ios --json`
     - `triton webview current-url --platform ios --json`
     - `triton route assert-current-url '<expected-url>' --platform ios --json`
     - `triton webview call <method> --platform ios --json` only for page/app allowlisted methods;
     - `triton webview events --platform ios --limit 50 --json`;
     - read `webview list/current.primarySource` first; provider-backed results use `webview-provider`, while runtime AX and host layout candidate discovery use `runtime-tree` or `host-layout`;
     - treat iOS `webview list/current` as candidate discovery unless `primarySource.name=webview-provider` and provider metadata includes URL/session details;
     - treat `webview current-url`, `webview snapshot`, `webview call`, `webview events`, `webview wait`, and `route assert-current-url` as provider-level evidence, not generic AX/layout proof;
     - treat Harmony host layout Web candidates as host-only until an embedded WebView provider is registered.
7. Prepare host-side simulator state through Triton before falling back to raw `xcrun`:
   - list simulators: `triton sim list --json`;
   - for repeated multi-simulator work, create a stable selector: `triton device alias set iphone15 --platform ios --target <udid> --json`;
   - prefer unified selectors for common host actions: `--device <alias-or-id>`; use `--simulator <udid-or-booted>` only when an iOS-specific selector is clearer;
   - set a workspace default simulator when a flow will be reused: `triton sim use <udid> --json`;
   - boot and wait for readiness: `triton sim boot <udid> --wait --jsonl`;
   - list installed apps: `triton app list --device iphone15 --user-only --json`;
   - inspect installed app metadata: `triton app info --device iphone15 --bundle-id <bundle-id> --json`;
   - install simulator builds: `triton app install --device iphone15 --app <path.app> --json`;
   - uninstall disposable simulator apps only with explicit policy: `triton app uninstall --device iphone15 --bundle-id <bundle-id> --confirm --json`;
   - launch apps: `triton app launch --device iphone15 --bundle-id <bundle-id> --json`;
   - terminate apps: `triton app terminate --device iphone15 --bundle-id <bundle-id> --json`;
   - submit app debug routes: `triton app open-url '<url>' --device iphone15 --json`; when a DEBUG embedded runtime is connected, prefer `triton app open-url '<url>' --device iphone15 --wait-ready --snapshot --json` to capture readiness and snapshot summary in the same result;
   - locate containers: `triton app container --device iphone15 --bundle-id <bundle-id> --kind data --json`;
   - verify App preferences: `triton app prefs get <key> --device iphone15 --bundle-id <bundle-id> --json`;
   - set simulator App preferences from property-list compatible JSON values: `triton app prefs set <key> <json-value> --device iphone15 --bundle-id <bundle-id> --json`;
   - seed Swift `UserDefaults.data(forKey:)` values explicitly with plist Data: `triton app prefs set <key> --type data --base64 <base64> --device iphone15 --bundle-id <bundle-id> --json` or `--type data --hex <hex>`;
   - capture host-side framebuffer: `triton sim screenshot --simulator <udid-or-booted> --output /tmp/<case>-sim.png --json`;
   - only use raw `xcrun simctl` when the needed capability is not in `triton schema --command sim --json` or `triton schema --command app --json`, and include that schema gap or Triton error envelope in the regression report.
8. Prepare Xcode build/test/run through Triton before falling back to XcodeBuildMCP or raw `xcodebuild`:
   - discover project containers: `triton xcode discover --path <repo> --json`;
   - set reusable defaults: `triton xcode use --workspace <workspace>|--project <project> --scheme <scheme> --configuration Debug --simulator <udid> --json`;
   - list schemes: `triton xcode schemes --json`;
   - diagnose current Xcode build/test occupancy before starting a smoke run: `triton xcode status --json`;
   - wait for the current workspace to stop building/testing: `triton xcode wait-idle --workspace <workspace> --timeout <seconds> --json`;
   - inspect app product settings: `triton xcode settings --jsonl --timeout <seconds>` for large workspaces, or `triton xcode settings --json` for quick projects;
   - build: `triton xcode build --jsonl`;
   - test: `triton xcode test --result-bundle /tmp/<case>.xcresult --jsonl`;
   - build/install/launch: `triton xcode run --jsonl`;
   - `xcode run` only proves build/install/launch submission; verify business readiness with `triton status`, `triton wait`, `triton verify`, screenshot, or evidence.
   - `xcode settings/build/test/run --jsonl` includes stdout/stderr log paths and byte counts; inspect those artifacts before waiting longer or falling back.
   - use XcodeBuildMCP only as a temporary fallback when `triton schema --command xcode --json` or `triton xcode ... --jsonl` evidence shows the needed capability is missing, unsupported, or failed with a stable error code.
9. For HarmonyOS NEXT / DevEco Emulator validation, use Triton host-side device discovery before raw `hdc`:
   - probe tools: `triton device doctor --platform harmony --json`;
   - list HDC targets: `triton device list --platform harmony --json`;
   - for repeated multi-emulator work, create a stable selector: `triton device alias set harmony-a --platform harmony --target <hdc-target> --json`;
   - wait for boot readiness: `triton device wait-ready --device harmony-a --json`;
   - close a Triton-supervised HVD with launchd cleanup: `triton device stop --platform harmony --hvd <hvd-name> --path <deployed-path> --confirm --json`;
   - inspect app metadata: `triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json`;
   - install a debug HAP when needed: `triton app install --device harmony-a --hap <debug-signed.hap> --json`;
   - launch an Ability: `triton app launch --device harmony-a --bundle <bundle> --ability <ability> --json`;
   - run the one-command host smoke when available: `triton smoke harmony --device harmony-a --bundle <bundle> --ability <ability> --open-url <url> --wait-text <text> --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json`;
   - when multiple targets are `Connected`, pass `--device <alias-or-id>` or narrow with `--platform`, `--name`, `--runtime`, `--state`, and `--ready`; `ambiguous_target` is the expected machine-readable failure.
   - if a disposable Harmony fixture app is needed, use the local `harmony-next` skill's minimal Empty Ability scaffold:
     - guide: `references/quickStart/ets/minimal-project-scaffold.md`;
     - template: `references/templates/empty-ability-app/`;
     - stable UI signals: `Harmony Smoke Ready`, `smoke-title`, `smoke-counter`, `smoke-increment`;
     - validation path: `ohpm install`, `hvigorw --mode module -p module=entry@default assembleHap`, HDC install/start, `uitest dumpLayout`, and `uitest screenCap`.
   - when validating a standalone Harmony embedded HTTP runtime before it is connected through `triton serve`, use direct runtime checks:
     - `triton device runtime-url --device harmony-a --probe-manifest --json` to prepare HDC fport and get the `baseURL`; if you already have the raw HDC target id, `--platform harmony --target <hdc-target>` is the direct explicit form;
     - the Harmony demo host-access embedded runtime default is `http://127.0.0.1:28767`; `18765` is reserved for the demo device-to-host gateway fallback path;
     - `triton debug runtime manifest --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton debug state route --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton debug snapshot --runtime-base-url http://127.0.0.1:<port> --json`;
     - `triton debug ledger --runtime-base-url http://127.0.0.1:<port> --jsonl`;
     - `triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:<port> --json` when an app action provider is registered.
10. Run observation before action:
   - prefer one-shot regression capture when a full report is needed: `triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json`.
   - prefer one-shot evidence when a report or issue needs attachable proof: `triton evidence capture --case <case> --output /tmp/<case>.tritonevidence --json`.
   - inspect an existing bundle without reconnecting runtime: `triton evidence inspect /tmp/<case>.tritonevidence --json`.
   - summarize evidence before public handoff: `triton evidence summary /tmp/<case>.tritonevidence --json`.
   - use `primaryArtifacts[]` as the first inspection order; only fall back to full `artifacts[]` when those high-signal entries are insufficient.
   - write a safe handoff bundle: `triton evidence redact /tmp/<case>.tritonevidence --profile ios-private --output /tmp/<case>-redacted.tritonevidence --json`.
   - `triton geometry --json`
   - `triton debug ax --json`
   - `triton screenshot --json --output <path>`
   - `triton export --format archive --output <path>`
11. Execute the smallest user-flow regression with machine-readable commands:
   - when the next command sequence is not obvious, ask Triton for a task plan first: `triton plan ios-smoke --device <selector> --bundle-id <bundle-id> --url <url> --text <text> --evidence /tmp/<case>.tritonevidence --json`, `triton plan open-url --device <selector> --url <url> --text <text> --json`, `triton plan open-url --platform harmony --device <selector> --bundle <bundle> --ability <ability> --hap <path.hap> --url <url> --text <text> --evidence /tmp/<case>.tritonevidence --json`, or `triton plan webview-check --expected-url <url> --text <text> --json`;
   - if `triton plan open-url ... --json` returns `mode=bootstrap`, execute `steps[]` to recover the environment, then continue with `afterRecoverySteps[].argv`; do not drop the original open-url verification workflow during server/runtime recovery;
   - treat task plans as command recommendations only; execute the returned steps explicitly and keep wait/assert/evidence as the pass/fail proof;
   - treat any plan step whose `command` is prose instead of a `triton ...` command as a TritonKit plan contract bug; for a missing iOS runtime target, expect `triton xcode run --json` or another schema-backed Triton command;
   - verify `plan.nextStep` points to one returned `steps[].id`; if not, report a TritonKit plan contract bug before embedding the plan into a regression script;
   - if a plan returns a command whose root command, subcommand, or `--flag` is not present in `triton schema --json`, treat that as a TritonKit schema/plan contract bug before using the command in a reusable regression;
   - if a schema subcommand `nextCommands[]` entry references a root command, subcommand, or `--flag` absent from `triton schema --json`, treat that as a TritonKit schema recovery contract bug before copying it into a reusable regression;
   - if command-level or subcommand-level `nextCommands[]` contains shell pipes, redirection, command substitution, or multiple commands, treat it as a TritonKit recovery contract bug; reusable regressions should receive single Triton invocations;
   - if command-level `outputFormats[]` contains unknown or duplicate values, treat it as a schema command taxonomy bug; valid values are `text`, `json`, `jsonl`, `logs`, `tree`, `auto`, `archive`, `file`, and `json-metadata`.
   - if a schema example contains zero or multiple `triton` invocations, treat it as a schema/example contract bug before copying it into a real-project script; examples may use `printf`, pipeline, or stdin preparation, but must expose exactly one reusable Triton invocation.
   - if an output contract field `type` is prose instead of a machine-readable scalar/DTO, optional, array, dictionary, or union type, treat it as a schema field contract bug before building parser logic around it.
   - if an output contract `model` is prose or raw Swift generic syntax instead of a machine-readable model, array, dictionary, or union type, treat it as a schema model contract bug before building parser logic around it.
   - if an output contract `selector` is not dot-separated lower-kebab, or `kind` is not single lower-kebab, treat it as a schema key contract bug before building parser logic around it.
   - if an `outputContracts[].format` value is not `json`, `jsonl`, or `archive`, treat it as a schema output taxonomy bug before building parser logic around it.
   - if an `outputContracts[].kind` value is not documented by the schema tests and dev docs, treat it as a schema output taxonomy bug before building parser logic around it.
   - if the flow will be reused, first create or update a `.tritonplan`; use `triton record --output <file.tritonplan> --json` only as an editable starter template, not as proof that live recording happened;
   - inspect reusable flows with `triton plan inspect <file.tritonplan> --json`, and read `steps[].argv/category/requires/expectedArtifacts/stopConditions/validationErrors` before dry-run;
   - dry-run reusable flows before touching the app: `triton replay <file.tritonplan> --dry-run --var key=value --var secret-env=ENV --json`, and compare returned `steps[].argv/category/requires/expectedArtifacts/stopConditions` with inspect output;
   - treat dry-run failure on ambiguous selectors or missing text/condition as a plan authoring issue; fix the `.tritonplan` before running against the business app;
   - replay committed flows with `triton replay <file.tritonplan> --json`, keeping secure values in environment variables and using `--var <name>-env=<ENV>`;
   - prefer action commands that are already machine-readable by default: `triton act find "HTTP"`, `triton act tap "HTTP"`, `triton act type "hello"`, `triton act paste "console"`, `triton act clear`; use `--format text` only for human-readable debugging;
   - for form flows, prefer semantic embedded actions over a `tap` plus `type` chain: `triton act focus "用户名" --json`, `triton act set-text "用户名" "alice" --json`, `triton act set-text "密码" "$TRITON_PASSWORD" --secure --json`, `triton act select-segment "协议" "HTTP" --json`, `triton act set-switch "记住我" on --json`;
   - when labels repeat, run `triton act find "<text>" --all`; if a known point lies inside the intended candidate, prefer `triton act tap "<text>" --at x,y`, otherwise choose `triton act tap "<text>" --index <n>` or `triton act tap "<text>" --within x,y,width,height`;
   - when `tap` or `assert` fails, read nearest candidates / nearestText and suggestedCommands from the JSON envelope before changing the test flow;
   - when `replay` fails, read top-level `recoveryProposal`, `failedStepIndex`, `failureCode`, `failureError`, `failureWorkflowCategories[]`, `failureRecoveryCategories[]`, `failurePrimaryArtifacts[]`, `recoveryCommands[]`, and `suggestedCommands[]` first; use `recoveryProposal.diagnosis`, `evidenceRefs`, `proposal.policyDecision`, and `nextActions[]` as the repair-advisor surface before broader step-by-step traversal or re-planning; then inspect the failed step `error` payload, including `wait/input/evidence` failures that only returned `ok=false`; if `failureError.nextAction` exists, expect replay recovery commands and proposal next actions to expose the same path; prefer failures that preserve runtime/target/transport codes over generic `step_failed`;
   - `triton act type --text <text>` is the alternate flag form and must never be combined with positional `<text>`;
   - `triton act press --button <button>` is the alternate flag form; prefer positional `triton act press <button>`;
   - for batch input, use `triton act input --json --summary --strict`;
   - when `tap`, `swipe`, `type`, or `paste` runs with `--platform harmony`, parse the host output contract selected by schema: `host.harmony-tap`, `host.harmony-swipe`, or `host.harmony-text-input`; do not assume the result shape is the embedded runtime `input.result`.
   - when `wait` runs with `--platform harmony`, parse `host.harmony-wait`; do not assume the result shape is the embedded runtime `wait.result`.
   - when `ax` or `screenshot` runs with `--platform harmony`, parse `host.harmony-artifact`; do not assume the result shape is the generic `host.artifact` device-level contract.
   - when `press` runs with `--platform harmony`, parse `host.harmony-key-action`; do not assume the selector remains `host.key-action`.
   - when `clear` runs with `--platform harmony`, expect a machine-readable `unsupported_capability` boundary; capabilities should expose `harmony-clear-text` as unsupported, not executable.
   - if legacy selectors (`host.tap`, `host.swipe`, `host.text-input`, `host.wait`) appear in schema output, treat it as a host contract regression before continuing real-project replay automation.
   - when deriving actions from `triton capabilities --json`, trust only schema-aligned `nextAction` values; embedded `press` is unsupported and should not be used as proof of device-level HID control.
   - after taps, submissions, and navigation, use `triton wait --text`, `triton wait --gone`, `triton wait --idle`, or a safe `triton wait --predicate` instead of fixed sleeps;
   - use `triton verify text-exists|text-not-exists <text> --json` for final pass/fail checks; add `--within x,y,width,height`, `--role`, or `--count` when labels repeat across headers, sidebars, and cells;
   - assert expected state through `wait`, a second `ax`, `find`, `screenshot`, archive check, or a fresh `evidence` bundle.
12. Store outputs under `/tmp` during iteration, then copy only durable screenshots or docs into the correct `docs-linhay/spaces/<space-key>/` location when the result is worth keeping.
13. Before sharing evidence outside the real app repo, sanitize project and personal information:
   - replace private project names, app names, bundle IDs, team IDs, organization names, user names, account IDs, email addresses, phone numbers, local usernames, internal domains, and absolute private paths with stable placeholders;
   - keep platform/tool versions, TritonKit version, command names, error codes, redacted route shape, and minimal sanitized snippets needed for reproduction;
   - do not attach full private logs, screenshots with personal data, unredacted `.tritonevidence`, `.tritonplan`, `.xcresult`, HDC/Simulator dumps, app archives, or credentials.
14. If the real app exposes a missing TritonKit capability, unclear behavior, or bug, use `tritonkit-dev-feedback` and file/prepare the GitHub issue directly after redaction.

## Real-Project Smoke Issue Closure

Use this checklist before commenting on or closing a real-project smoke issue such as iOS one-command smoke, Xcode occupancy diagnostics, WebView route checks, Harmony host-side smoke, or simulator takeover slices.

1. Confirm the implementation is on `main` and pushed to `origin/main`; reference the exact commit hash in the issue comment or session notes.
2. Confirm the relevant CLI schema exposes the capability, for example `triton schema --command smoke --json`, `triton schema --command xcode --json`, `triton schema --command app --json`, or `triton schema --command webview --json`.
3. Run the narrow unit or mock tests that own the orchestration and error shape.
4. Run at least one structured host/runtime verification that exercises the user-facing command. For iOS one-command smoke this means `triton smoke ios ... --json`; for open-url readiness it means `triton app open-url <url> --wait-ready --snapshot --json`; for Harmony host smoke this means the HDC-backed `device/app/ax/wait/screenshot` chain or `smoke harmony` when available.
5. Treat host action acknowledgements as submission evidence only. `simctl openurl`, HDC `aa start`, `xcode run`, tap, launch, or install success does not close a business smoke issue until a later `wait`, `assert`, snapshot, screenshot, or evidence result proves the expected app state.
6. Attach or summarize evidence after redaction. Public comments must avoid real app names, bundle IDs, team IDs, private paths, screenshots with personal data, full logs, credentials, and unredacted `.tritonevidence`, `.xcresult`, or HDC/Simulator dumps.
7. Update the owning `docs-linhay/spaces/<space-key>/README.md` or technical note with the current state, including which issues are still open.
8. Write memory for the decision, closure criteria, residual risks, and follow-up issues.
9. Run docs/skill sync for pure documentation closures, or the full relevant test gate for code closures.
10. Only close the issue once the issue-specific closure criteria are met. Keep epics such as simulator takeover open unless the scoped P0/P1 acceptance criteria are satisfied and remaining advanced scope has been split into follow-up issues or explicitly deferred in the closure comment.

Do not collapse multiple open issues into a single closure comment just because they share an orchestration layer. A shared implementation can close one issue and leave related issue slices open.

## iOS App Integration Guide

Use this exact shape when the real app needs TritonKit embedded runtime access.

SwiftPM:

```text
https://github.com/NeptuneKit/TritonKit.git
```

Add only the `TritonKit` product to the iOS app target. App integrations should not select or import internal TritonKit targets directly. Keep every app-side source file that imports or starts TritonKit behind `#if DEBUG`; do not rely only on the package runtime guard.

SwiftPM supports configuration-scoped build settings, so TritonKit defines `TRITONKIT_RUNTIME_ENABLED` only for Debug package builds and keeps the embedded runtime no-op in Release. SwiftPM / Xcode package product dependencies still do not have a CocoaPods-style `:configurations => ['Debug']` switch: the package product may remain attached to the target even though the runtime is disabled. If the production Release target must not link TritonKit at all, create a separate Debug-only app target or scheme and attach the `TritonKit` product only to that target.

CocoaPods during development. Add only the `TritonKit` pod; do not add sibling TritonKit pods. The podspec defines `TRITONKIT_RUNTIME_ENABLED` for the TritonKit pod target Debug configuration, while Release remains no-op:

```ruby
target 'YourApp' do
  use_frameworks!

  pod 'TritonKit',
      :git => 'https://github.com/NeptuneKit/TritonKit.git',
      :branch => 'main',
      :configurations => ['Debug']
end
```

Create a dedicated Debug bootstrap file. For team apps, prefer an opt-in Debug bootstrap so ordinary Debug builds do not expose the runtime unless the developer explicitly enables it:

```swift
// TritonKitDebugBootstrap.swift
#if DEBUG
import Foundation
import TritonKit

enum TritonKitDebugBootstrap {
    static func startIfEnabled() {
        let arguments = ProcessInfo.processInfo.arguments
        let environment = ProcessInfo.processInfo.environment
        let isEnabled = arguments.contains("--triton-enabled")
            || environment["TRITON_ENABLED"] == "1"
            || UserDefaults.standard.bool(forKey: "TRITON_ENABLED")

        guard isEnabled else { return }

        TritonKit.shared.start { config in
            config.endpoint = .environment()
            config.autoReconnect = true
            config.features = [.hierarchy, .accessibility, .input]
            config.redaction.secureText = .lengthOnly
            config.redaction.collectClipboard = false
            config.redaction.collectNetwork = false
            config.redaction.collectLogs = false
            config.appIdentity = .init(name: "YourApp", tags: ["debug", "opt-in"])
        }
    }

    static func stop() {
        TritonKit.shared.stop()
    }
}
#endif
```

Enable it from Xcode with launch argument `--triton-enabled`, environment variable `TRITON_ENABLED=1`, or Debug-only user default `TRITON_ENABLED=true`. `config.endpoint = .environment()` reads `TRITON_HOST` / `TRITON_PORT` and falls back to `127.0.0.1:19421`. Use `TritonKit.shared.start { config in config.endpoint = .device("192.168.1.20", port: 19421) }` when a physical device needs to connect to a Mac LAN address.

Preferred facade APIs:

| Need | API |
| --- | --- |
| Start with environment fallback | `TritonKit.shared.start()` |
| Start with explicit local CLI port | `TritonKit.shared.start(.local(port: 19421))` |
| Start from environment variables | `TritonKit.shared.start(.environment())` |
| Start from a device to a Mac LAN address | `TritonKit.shared.start(.device("192.168.1.20", port: 19421))` |
| Start with advanced options | `TritonKit.shared.start { config in ... }` |
| Stop the debug runtime | `TritonKit.shared.stop()` |
| Observe connection state | `TritonKit.shared.onStateChange { state in ... }` |
| Observe connection errors | `TritonKit.shared.onError { error in ... }` |

For advanced debug bootstrap code, keep the same file-level `#if DEBUG` guard and configure the facade in one closure:

```swift
#if DEBUG
TritonKit.shared.start { config in
    config.endpoint = .device("192.168.1.20", port: 19421)
    config.autoReconnect = true
    config.features = [.hierarchy, .accessibility, .input]
    config.redaction.secureText = .lengthOnly
    config.appIdentity = .init(name: "YourApp", tags: ["smoke"])
}
#endif
```

Observe connection status without implementing a full delegate:

```swift
#if DEBUG
enum TritonKitDebugObservers {
    private static var stateToken: TritonKit.ObservationToken?
    private static var errorToken: TritonKit.ObservationToken?

    static func start() {
        stateToken = TritonKit.shared.onStateChange { state in
            print("TritonKit state:", state)
        }
        errorToken = TritonKit.shared.onError { error in
            print("TritonKit error:", error)
        }
    }
}
#endif
```

Retain observation tokens for as long as callbacks are needed, and call `cancel()` when an observer should be removed. `start` retains the default request handler internally; only use the lower-level `delegate` / `connect(host:port:)` API when you need a custom delegate or custom message routing.

Call the bootstrap only from a guarded app entry point:

```swift
#if DEBUG
TritonKitDebugBootstrap.startIfEnabled()
#endif
```

## Harmony App Integration Guide

Use this shape when the real app needs Harmony / DevEco validation.

Host-side Harmony checks do not require any app package dependency:

```bash
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device wait-ready --device <hdc-target> --json
triton app inspect --platform harmony --bundle <bundle> --target <hdc-target> --json
triton app install --device <hdc-target> --hap <debug-signed.hap> --json
triton app launch --device <hdc-target> --bundle <bundle> --ability <ability> --json
triton app open-url --device <hdc-target> --bundle <bundle> --ability <ability> '<url>' --json
triton debug ax --platform harmony --target <hdc-target> --output /tmp/<case>-layout.json --json
triton wait --platform harmony --target <hdc-target> --text '<text>' --timeout 15 --json
triton act tap '<text>' --platform harmony --target <hdc-target> --json
triton screenshot --device <hdc-target> --output /tmp/<case>.jpeg --json
triton smoke harmony --device <hdc-target> --bundle <bundle> --ability <ability> --open-url '<url>' --wait-text '<text>' --screenshot /tmp/<case>.jpeg --evidence /tmp/<case>.tritonevidence --json
```

When multiple HDC targets are `Connected`, pass `--device <alias-or-id>` or an explicit `--target`; `ambiguous_target` is the expected machine-readable failure.
Host-side layout and screenshot artifacts may contain private UI data; inspect or summarize them before attaching evidence to public issues.

For Harmony embedded SDK work, keep the TritonKit brand separate from the OHPM package id. The actual package id and ArkTS import path are lowercase:

```text
tritonkit
```

Until the Harmony package is published, use the aligned `harmony-TritonKit` source/HAR for validation. Keep the app integration Debug-only. Release builds must compile to disabled/no-op behavior and must not collect UI, screenshots, logs, route state, or action data.

Business semantics are not generic HAR capabilities. Route, responder, and semantic action state should come from app provider hooks. If providers are not registered, `unsupported_runtime_scope` is the correct runtime result; if the manifest marks those capabilities supported without providers, file a bug.

For a standalone Harmony embedded runtime before it is connected through `triton serve`, use direct runtime checks:

```bash
triton device runtime-url --device harmony-a --probe-manifest --json
triton debug runtime manifest --runtime-base-url http://127.0.0.1:28767 --json
triton debug state route --runtime-base-url http://127.0.0.1:28767 --json
triton debug snapshot --runtime-base-url http://127.0.0.1:28767 --json
triton debug ledger --runtime-base-url http://127.0.0.1:28767 --jsonl
triton act set-text "密码" "$TRITON_PASSWORD" --secure --runtime-base-url http://127.0.0.1:28767 --json
```

For the Harmony demo, `28767` is the host-access embedded runtime port exposed through HDC `fport`; `18765` is only the demo device-to-host gateway fallback port.

## CLI Install Contract

Use Homebrew for real-project adoption checks by default:

```bash
brew install NeptuneKit/tap/triton
brew update
brew upgrade triton
```

Use the local release CLI only while TritonKit is pre-release, while validating unreleased source changes, or when Homebrew / GitHub Release assets are unavailable:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
.build/cli/release/triton version --json
```

When installing that local build into `~/.local/bin/triton` or another existing `PATH` location, avoid overwriting a path that may be backing a running `triton serve` process. Stop the server first, or use atomic replacement:

```bash
swift build --package-path CLI --scratch-path .build/cli -c release --product triton
cp .build/cli/release/triton ~/.local/bin/triton.new
mv ~/.local/bin/triton.new ~/.local/bin/triton
triton version --json
```

Homebrew installs only the macOS CLI. The app-side embedded runtime still comes from SwiftPM or CocoaPods and must remain DEBUG-only.

Release assets live in `NeptuneKit/TritonKit` GitHub Releases and include arm64/x86_64 CLI archives plus `tritonkit_checksums.txt`. The Homebrew tap is updated from those release assets after `v*` tag releases. If the release or tap is unavailable in a test environment, do not fail the regression setup on Homebrew; use the local release CLI and file a TritonKit issue with the missing distribution evidence.

## Boundaries

- Do not commit or revert real app repo changes unless the user explicitly asks.
- Do not publish real app identity, private bundle IDs, personal accounts, user names, emails, internal hosts, absolute private paths, or unredacted evidence in TritonKit issues.
- Inspect evidence manifests, screenshot pixels, and artifact filenames before attaching them to public issues. If redaction cannot be verified, summarize the evidence instead.
- Do not treat a successful tap as completion; verify the resulting app state.
- Do not add Web/Wails UI to satisfy real-project needs when CLI/HTTP can provide the contract.
- System alerts and SpringBoard-level controls remain outside embedded runtime scope; expect `runtime_ui_interrupted` or unsupported errors.
- If the requirement becomes product work, create or update the corresponding `space` before implementation.

## Existing Regression Entrypoints

- Generic complex harness: `docs-linhay/scripts/verify-complex-harness.sh`
- Intent CLI smoke: `docs-linhay/scripts/verify-intent-cli-smoke.sh`
- Overloaded real-app smoke: `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`

## Replay Plan Notes

- `.tritonplan` schema version 1 supports `tap`, `paste`, `type`, `clear`, `wait`, `screenshot`, and `evidence`.
- Use `${variable}` placeholders for account names, passwords, hosts, or output paths.
- Use `secure: true` on password-like `paste` or `type` steps; replay summaries must redact values.
- Prefer an `evidence` step at the end of a reused smoke flow so the final state is attachable to issues and regression reports.
- For stale-list regressions, pair `capture` with `assert text-not-exists <stale text> --within <right-list-bounds>` so the report contains both artifacts and a machine-readable pass/fail result.
