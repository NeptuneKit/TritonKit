# SP-159 实施计划：iOS DDI recovery

## 写入面

- `CLI/Tests/TritonKitCLITests/DeviceCrossPlatformTests.swift`
- `CLI/Tests/TritonKitCLITests/FailureDiagnosticsTests.swift`
- `Sources/TritonKitCLI/CLIHostProcessRuntime.swift`
- 本 space README、`docs-linhay/memory/2026-08-09.md`

## 验收重点

1. DDI failure 仍使用 `ddi_missing`。
2. `nextAction` 是可执行的 `app install`，包含 `--platform ios`、`--scope real`、`--device <selector>`、`--app <app-path>`、`--json`。
3. trust/developer-mode/locked/offline 的 mapping 不发生漂移。
4. 不引入 live device、签名资产或远端写入依赖。
