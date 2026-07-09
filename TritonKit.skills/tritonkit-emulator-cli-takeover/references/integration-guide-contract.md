## Integration Guide Contract

When changing iOS / Harmony / CLI onboarding or usage guides, keep these entry points aligned:

- `README.md` must split iOS embedded runtime, Harmony host-side adapter, Harmony embedded SDK, and CLI install/run guidance.
- `tritonkit-dev-feedback` must be able to guide external users through iOS, Harmony, or CLI adoption before filing feedback.
- `tritonkit-real-project-regression` must treat iOS and Harmony apps as external systems under test, using host-side checks when embedded runtime is not required.
- Harmony docs must state that host-side HDC / DevEco Emulator control does not require embedded SDK integration.
- Harmony embedded SDK docs must state package id/import path `tritonkit`, Debug-only runtime, Release disabled/no-op behavior, provider-owned business semantics, and `--runtime-base-url` direct checks while standalone.
- CLI docs must keep Homebrew as the released install path and local `swift build --package-path CLI --scratch-path .build/cli -c release --product triton` as the unreleased-source fallback.
