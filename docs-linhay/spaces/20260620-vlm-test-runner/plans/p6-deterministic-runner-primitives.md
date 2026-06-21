# P6 Deterministic Runner Primitives

## Goal

Expand `triton test run` beyond the P0D/P0E minimal runner while keeping deterministic runner execution as the primary test chain.

This phase is not VLM runner integration, not suite execution, and not report generation. It only extends validate/normalize and runner execution for deterministic primitives that can produce `.tritonevidence` observations.

## Implemented Scope

Supported by validate/normalize:

- `launch`
- `stop`
- `takeScreenshot`
- `tap.point`
- `input.text`
- `press.button`
- `swipe.from/to`
- `assertVisible.text`
- `assertNotVisible.text`
- `scrollUntilVisible.text`

Execution behavior:

- `launch` still binds and verifies an already connected runtime target.
- `takeScreenshot` writes observation artifacts.
- `tap`, `input`, `press`, and `swipe` capture before/after observation events.
- `assertVisible` and `assertNotVisible` use AX exact text observation.
- `scrollUntilVisible` performs bounded deterministic swipes and records observations.
- `stop` is recognized by validate/normalize, but live embedded-runtime execution returns `stop_not_supported` until host app terminate target selection is wired.

## Explicitly Out Of Scope

- `tap(text)`
- id/index/relationship selectors
- selector healing
- VLM runner steps
- App Map execution
- suite runner
- flow glob
- `testOutputDir`
- execution order policies
- HTML/JUnit reports
- autonomous loop

## Machine Contract Updates

- `triton schema --command test --json` exposes deterministic runner semantics.
- `triton capabilities --json` keeps `test-run-minimal` for compatibility and adds `test-run-deterministic`.
- Normalized plan output includes `endPoint`, `text`, `button`, `direction`, and `maxScrolls`.
- Unsupported steps remain `validation_error` and do not create evidence or invoke device operations.

## Validation

Targeted checks completed during implementation:

```bash
swift test --package-path CLI --filter TestValidationTests --filter TestRunExecutionTests
```

Result: passed.

Full collective validation is deferred until the current large implementation slice is complete.
