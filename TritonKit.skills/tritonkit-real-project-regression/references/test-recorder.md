# Explicit-event test recording and import

## Prerequisites

`testrec` records **explicitly supplied events**, not every user touch/network request automatically. It compiles a `.tritontestcase` contract; the existing `test run` remains the real executor. Source platforms may be ios/android/harmony/web, but successful source classification is not all-platform live replay support.

```bash
triton schema --command testrec --json
triton schema --command test.import --json
triton schema --command test.run --json
```

Use an owned fresh output path, preserve the App's original observations/requests and freeze the intended target independently. Do not remove values or block recording/import merely because business text resembles passwords/tokens/emails/numbers. Caller-requested redaction/parameterization belongs in a separate conversion, not in fabricated raw originals.

## Workflow

1. Start a case and read the actual `sessionId` and `casePath`:

```bash
triton testrec start --platform ios --case login-flow --output '<fresh-case.tritontestcase>' --json
```

2. Append observed events in order. Allowed kinds are `action`, `network`, `page-route`, `page-fingerprint`, `page-snapshot`; `--payload-json` is one JSON object. These minimal examples demonstrate event submission, **not a complete importable test**:

```bash
triton testrec event --session '<sessionId>' --kind page-route --payload-json '{"id":"p1","route":"login"}' --json
triton testrec event --session '<sessionId>' --kind action --payload-json '{"id":"a1","kind":"tap","target":{"label":"Continue"}}' --json
```

Populate actual action timing, target attributes, page/fingerprint/snapshot and network evidence according to the installed schema/observed source. Do not invent page snapshots or add fake success/negative controls to make compilation green. An accepted event JSON object only proves append acceptance; it may still be insufficient for compilation/import.

3. Stop and inspect; then compile the existing source package:

```bash
triton testrec stop --session '<sessionId>' --json
triton testrec inspect '<case.tritontestcase>' --json
triton testrec compile '<case.tritontestcase>' --json
triton testrec proposals '<case.tritontestcase>' --json
```

Compile defaults to `<case>/compiled-contract.json`; `--output` explicitly chooses another contract location. Compilation/proposals are analysis, not App execution. Inspect quality findings, source artifacts, page mapping and unsupported operations; correct the actual source or stop, never erase a failing fact to force readiness.

4. If page correspondence needs diagnosis, use `testrec match-page <case> --page <compiled-page-id> --candidate-json <actual-fingerprint-object> --json`. The candidate must be a real target fingerprint, not the source fingerprint relabeled as target evidence.
5. For the supported imported iOS Simulator path, specify App identity/platform explicitly and place the output **outside** the source package:

```bash
triton test import '<case.tritontestcase>' --output '<fresh-plan.tritontest.yaml>' --bundle-id '<bundle-id>' --device-platform ios-simulator --json
triton test validate '<fresh-plan.tritontest.yaml>' --json
```

Import does not infer the bundle or silently upgrade generic iOS to Simulator. It consumes the compiled source, not an uncompiled arbitrary raw stream. Keep source artifact paths inside the package, avoid overwrites/symlinks, and inspect actual import errors for incomplete page evidence, unsupported/lossy operations or incompatible source contracts.
6. Only after validation, exact connected runtime selection and separate action authorization, run the plan with the live executor:

```bash
triton test run '<fresh-plan.tritontest.yaml>' --target '<runtime-target>' --evidence-dir '<fresh-run.tritonevidence>' --json
```

See [replay plans](replay-plans.md) for `.tritonplan` command replay, which is a different format/workflow. [App-map](../../tritonkit-emulator-cli-takeover/references/app-map.md) can export reviewed map paths into the same validated test-plan executor.

## Verification

Append/stop outputs publish session/case paths and counts; inspect them before compiling. Import/validate success is **not** a test verdict. Accept only the live run's actual terminal status, assertions and attributable evidence; distinguish failed, blocked, stopped, partial and unknown. Preserve the failed step/error/recovery proposal, and do not automatically resubmit uncertain input or modify a claimed reliability slot.

`testrec replay <case> --platform ios --dry-run --json`, `--executor local-simulated` and `testrec matrix` are offline diagnostics. Their legacy ready/passed counters do not count as runtime test verdicts: require `verdictBoundary.countsAsRealTestVerdict=false` and `eligibleForReliabilityGate=false`. Older output without that boundary is legacy/unknown, not proof. The HTTP recorder endpoints share these boundaries; see [local HTTP API](../../tritonkit-emulator-cli-takeover/references/http-api.md).

## Limits

A complete automatic recorder, universal source-to-target mapping and new Android/Harmony/Web live test executors are not implied. Real 3×20 supported plus independent negative-control reliability collection is a separate, explicitly authorized workflow; preflight/offline samples do not establish it. Read the regression skill's receipt/anchor/identity-chain requirements before such a collection.

Keep original fixtures, empty versus missing values, original target text and provider coverage. Truncation/unreadable data must remain explicit. Raw local capture does not authorize public sharing; apply the feedback skill's public preflight to a separate outgoing copy.
