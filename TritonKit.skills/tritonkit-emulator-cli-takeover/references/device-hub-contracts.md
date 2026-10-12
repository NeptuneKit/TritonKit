# Device Hub contracts

This reference is shared by the installed public skill bundle. Inspect the installed CLI schema before use; available SDK backends and target families may differ. Historical acceptance is product evidence, never authorization to operate a new user's device.

## Discovery and shallow metadata


Use existing CLI contracts, not Device Hub window automation:

```bash
triton device list --platform ios --scope simulator --json
triton device list --platform ios --scope all --json
triton target resolve sim:<udid> --platform ios --json
```

Xcode 27 CoreDevice inventory includes simulated and physical devices. Prefer authoritative `properties` when present; derive kind from observed hardware reality, never from the name, transport, or UUID shape. The combined iOS inventory joins canonical `sim:<UDID>` identities and prefers simctl lifecycle facts; explicit `--scope all` must fail if either backend fails, rather than claim complete discovery. Explicit simulator selectors without scope remain simulator-only. Missing/unknown metadata reports `ready=false` with `readiness-unknown`; physical discovery readiness is development-service eligibility, not unlocked state or business readiness. `--scope real` is existing readonly discovery compatibility, not permission to orchestrate physical devices. Keep raw captures private and distinguish anonymized captured shapes from synthesized new-only fixtures. Do not parse terminal tables, map preparedness numbers without a documented contract, or enable input/screenshot capabilities merely because CoreDevice advertises them.

For an already-started Simulator or paired physical iOS target, use `triton device info --platform ios --device <selector> [--lock-state] --json` for whitelisted properties. The optional lock query returns observed `passcodeRequired` and `unlockedSinceBoot`, not screenLocked or business readiness; unrequested is `not-probed`, absent fields unknown. It never starts/pairs/unlocks a target or retries another backend. Raw identities, serials, network addresses and upstream capabilities stay private. Structured CoreDevice1001 lock capability rejection returns `unsupported_device_info_query`; preserve that failure, not a silently downgraded success or global Simulator guarantee. Device Hub full coverage must be reported per capability/platform and evidence, not inferred from this snapshot.

`triton sim rename <explicit-uuid> "New Name" [--timeout <seconds>] --json` is a standalone reversible display-name mutation, not boot/delete/clone. Reject ambiguous/physical typed selectors, blank/control names and invalid timeout before execution. Treat success as submission-only; independently use device list to verify name/canonical identity/state. Acceptance must restore only the explicitly owned instance's original name and never overwrite an unexpected third-party rename.

`triton device files --platform ios --device <selector> --domain-type systemCrashLogs --json` lists shallow metadata only; app domains require --domain-identifier. Optional --subdirectory/--username bind the JSON query scope. Default name/path metadata is private (opaque correlation token); explicit --include-sensitive exposes only filenames/relative paths. No contents, owners/xattrs/isWritable authorization/raw identifiers, recursion/copy or automatic backend retry. JSON/entry limits reject local acceptance only; temporary requires a separate side-effect policy and returns device_file_domain_policy_required before backend. Simulator-specific CoreDevice1001 listFiles rejection is unsupported_device_file_query, not a global platform claim. Restore only explicitly owned instances after acceptance; never borrow booted business devices.

`device mountpoint --platform ios --device <selector> --json` independently returns a DeviceFS correlation token and private artifact references. Require unique echoed raw --device exact binding; native path/raw physical IDs remain private. Do not access returned path, invoke Finder, explicitly mount/unmount, or auto boot/pair/unlock/retry; filesystem/mount/content/business verification remain false. CoreDevice service/private artifact side effects remain, and metadata does not prove path presence or read/write authorization. Unknown capability errors query_failed, not guessed unsupported; local JSON limits are not remote hard limits.

Device info hardware.platformObservation is optional/additive, fresh identity-bound explicit exact hardware platform/deviceType/reality with sourceLayout; old missing field decodes nil. iOS+iPad remains ios/ipad, no name/product/marketing/runtime/legacy ios/capability inference; unknown reality not physical, unknown raw observations not echoed, modern present/null/partial forbids deprecated fallback. Preserve IDs/argv/dispatch/no auto controls/business proof. Check nested schema/CLI roundtrip, separate current physical readonly evidence from other-family fixtures/controls.

Apple platform report: `device platforms --json` compiled catalog, not current SDK/action availability. --apple-platform catalog-only filter; --inventory one available Simulator metadata query/global family counts (unknown retained), no IDs/name/rawruntime or physical/boot/control. Default zero queries/no server. iOS runtime not iPadOS/iPhone-iPad proof, no Mac Simulator guess; zero not unavailable. Report-only false control/auth flags not old command denial. Old ios IDs/argv stable, no capability-array/generic command autoenable; errors static/code only. Keep compiled report, observed counts and actual action acceptance separate.

Bounded container-relative metadata: optional `--subdirectory <relative-directory>` requires explicit container/app view; raw1...32 components/4096 UTF8 bytes/255 each, no absolute/dot/dotdot/empty/control, no normalize/URLdecode. Standard-root shape budget64/16384 preflight before discovery/artifacts (placeholder never IO/identity), fresh actual parent UTF8 bytes and UUID binding then exact combined recheck before directory IO. Root/every relative owner/noFollow same FD, not all system ancestors owner=current uid. Scope tokens add exact subdir bytes, omitted old compatibility; no scope-field echo/only opt-in leaves. Existing opted-in directory selection only, no create/content/recursive/outsidecontainer/Finder/autoprep/fallback; app tmp metadata not Temporary-domain creation. Actual owned privacy/bounds/state restore acceptance mandatory.

Single native container metadata: add `--container-identifier <native-child-name>` only to app-data/app-group views. One raw 1...255-byte UTF8 component, no dot/dotdot/slash/control; pre-discovery/artifact validation, never normalize. Same FD root and every relative-layer owner/nofollow. No verified bundle/group identity/install proof; requested identifier not selection-field echoed, opaque directoryToken/view+container entry salt, old omitted-scope tokens unchanged. Include-sensitive only leaf names (coincidences allowed); no outside-container paths/content/recursion/fallback/Finder/autoprep. Native names come from explicitly opt-in namespace listing, no automatic child selection; actual owned lifecycle restoration required.

`device fs list --platform ios --device <selector> --json` deliberately lists standard identity-bound DeviceFS fixed namespace shallow metadata only (--view mount-root default|app-data-containers|app-group-containers); no bundle/group-ID navigation. Device-root owner checked before namespace open then namespace owner, same FD chain. Exact fstatfs devicefs admits observed synthetic dirent/stat ID difference while always requiring double nofollow stat inode/device/kind, other filesystems strict dirent binding. entryIdentityVerification not snapshot/provenance proof, old root tokens compatible/new view-salted; never automatic files-error fallback. Fresh private mountpoint/UUID+exact parent binding and same-FD owner/nofollow are mandatory. Default token/kind/regular size, include-sensitive adds names only. No content, arbitrary subdirectory traversal, domain guessing, Temporary creation, Finder, explicit mount or automatic boot/pair/unlock; bounded container-relative selection follows the separate guard above. hostFilesystemInspected=true, mountStateVerified/readWriteAuthorizationVerified/businessReadinessVerified/contentsRead=false. Query timeout is not FUSE syscall deadline; limits are local acceptance, not remote hard limits or atomic snapshot. Never publish native paths/private artifacts. Use the separate `device containers` contract below for SDK identity binding; a native directory selector alone does not provide that binding.


## App and App Group bindings

`triton device containers --device <selector> --bundle-id <id> [--group-id <id>] [--list] --json` requires SDK-explicit bundle identity, group membership and container-path binding. Never infer ownership from App names, directory names or path shape. Missing SDK parameters are unsupported; absent binding fields are unavailable. `deviceFSBindingVerified=false` stays explicit.

Default output exposes tokens/status/boundaries. `--list` is shallow metadata only on the selected Simulator's restricted native container, with owner/nofollow/relative-path/budget guards. Physical devices support SDK metadata binding; never open their paths as local host files. App `tmp` directory metadata is separate from the Temporary file domain. Neither surface reads business file contents.

## Crash and Temporary

Keep three Crash contracts separate: `triton device files --domain-type systemCrashLogs` is a CoreDevice shallow metadata domain; `triton device fs list --view diagnostic-reports` enumerates only the explicit DeviceFS `DiagnosticReports` namespace; `triton device diagnose` collects a sensitive diagnostic ZIP, potentially including host CoreDevice logs. Missing DeviceFS namespace fails; do not guess root mapping or claim entry equivalence between these surfaces.

Temporary queries may create a client domain. Default `device_file_domain_policy_required` is a side-effect policy rejection before backend execution. A currently authorized query additionally requires `--domain-type temporary --domain-identifier <client-id> --allow-domain-creation --confirm --execute-runner --audit-record <id>`. Durable intent precedes the call; `riskLevel=automation`, actual creation remains unknown, and failure may already have created the domain. Do not retry automatically. Temporary has isolated contract coverage but no real query acceptance in the 2026-10-12 evidence baseline.

## Management execution

`triton device pair|unpair|diagnose --platform ios --scope real --device <selector> --plan-only --json` remains the readonly policy review. An executable backend now exists; it requires `--execute-runner --confirm --audit-record <id>` instead of `--plan-only`, and diagnose also requires `--output <private.zip>`. Flags record policy but do not replace explicit current-task authorization.

Before execution, bind a fresh exact device identity and persist intent. Execute once, validate native file-JSON target/request binding, check independent pairing state or diagnostic archive, and persist completion. Preserve distinct succeeded/failed/timed-out/partial results and unknown side effects; a plain process exit is insufficient. Never retry an uncertain mutation or switch to a different device to make a recovery pass. Old `sim pair/unpair/diagnose` command forms remain available.

Diagnostic output requires an existing user-owned private directory, rejects overwrite and symbolic links, and publishes mode 0600. The default local archive acceptance limit is 256 MiB; `--maximum-archive-bytes` is an explicit operator policy, not automatic budget escalation or a native capture peak-disk limit. A native collection can complete while local publication is partial because its archive is too large. Preserve private source evidence; do not silently re-collect. ZIP structure/hash checks do not establish diagnostic content completeness. Path/inode checks do not eliminate same-user replacement races.

## Specialized Apple platforms

`triton sim pairs --json` reports native watch/phone pairing metadata, not live connectivity or input readiness. `triton device platforms --include-real-devices [--device <exact-id-or-inventory-token>] --json` adds Apple hardware discovery with SDK-explicit physical provenance. Unknown reality is not physical; do not infer from transport, name or capability strings. Other Apple families' parser fixtures are not physical hardware acceptance.

Without execution options, `triton device platform-control --platform <watchos|tvos|visionos|macos> --action <control> --json` describes its contract: watchOS Crown/Action and tvOS remote/focus are `fixture-only`, `executable=false`, `actionsExecuted=false`. This describes a nonexecuting response, not absence of the explicit runner backend. Crown requires finite nonzero `--delta`.

The explicit watchOS/tvOS runner requires `--device <exact-udid> --xctestrun <private.xctestrun> --test-identifier <Target/Class/testMethod> --result-bundle <fresh.xcresult> --audit-record <id> --execute-runner --confirm --json`. Supply a separately built, dedicated XCTest artifact and an installed matching Simulator runtime. Public skills contain no runnable test project. Validate exact target/runtime family before one test method; disable parallel clones and repeated execution. Result parent must be owned mode 0700 with no symbolic-link path components.

The runner injects versioned `TRITON_PLATFORM_REQUEST`, including action, target, unique nonce and optional Crown delta, then validates the designated xcresult test/device attachment. Successful receipt must bind target/action/nonce/event/postcondition. Do not parse xcodebuild stdout as proof. Persistent intent/completion, bounded logs and typed outcomes preserve failures and unknown delivery; missing or contradictory evidence exits nonzero without automatic retry. After-run bundle size checks are not live disk quotas.

Native watchOS/tvOS test builds and native XCTest attachment transport were validated; actual Crown/tvOS input remains unaccepted because matching runtimes could not be downloaded in the validation environment. watchOS Action additionally lacks an isolated verified postcondition; side-button, visionOS gaze/pinch/scene, and macOS Device Hub control remain unsupported. Xcode macOS build/test is a separate supported workflow, not Device Hub input. GUI-only evidence cannot promote any unsupported or fixture-only row.

## Evidence baseline (2026-10-12)

| Capability | Implementation and acceptance |
| --- | --- |
| Physical iOS info/lock/readiness, Crash shallow metadata, App/group SDK binding | Real readonly acceptance; no business content read |
| Physical iOS pair/unpair | Executed with native result and independent postcondition; original unpaired target restoration remains incomplete |
| Physical iOS diagnose | Native capture and private archive success verified under an explicitly selected 512 MiB budget; previous 256 MiB over-limit partial retained |
| Physical iOS App install/info/launch | Dedicated signed fixture installed and process checked; does not prove business UI readiness |
| Temporary | Policy/audit backend and isolated tests; no real domain query acceptance |
| watchOS Crown and tvOS input | Explicit runner implemented; native build/attachment transport verified; runtime/input acceptance blocked |
| watchOS Action | Contract/runner route exists; no verified isolated action postcondition |
| side-button, visionOS specialized controls, macOS Device Hub control | Unsupported |

Report implementation, native execution, fixture coverage, plan-only and GUI-only evidence separately. This baseline covers selected Apple hardware/toolchains only; it is not full Device Hub integration or fresh user authorization.
