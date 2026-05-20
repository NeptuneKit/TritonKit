需求和技术设计已整理为三层文档：

- Product / requirement spec: `docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Technical design: `docs-linhay/spaces/20260520-simulator-takeover/technical-design.md`
- Project architecture summary: `docs-linhay/dev/20260520-simulator-takeover-architecture.md`

整理后的结论：

- `xcrun-host-adapter-research` 只保留为前置调研，不再作为独立并行方案。
- 主路径是 Triton native host adapter wrapping Apple official CLIs.
- P0/P1 only covers the real-project regression loop: simulator/app lifecycle, deep links, containers, preferences, screenshot, privacy/location/UI/status bar, media, keychain, pasteboard, iCloud, app data, plan/evidence integration.
- P2+ defers host UI, logs/video/diagnostics, xctrace, Xcode build/test, coverage, SPM, scaffolding, runtime maintenance, and watch pairing.
- Destructive commands must require `--confirm` or `.tritonplan` `confirm: true`.
