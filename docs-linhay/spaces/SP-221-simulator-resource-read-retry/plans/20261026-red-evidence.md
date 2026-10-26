# 首轮红测试证据

2026-10-26；基线 `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`，生产reader未改。

命令：`swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update --filter SimulatorResourceStateTests`；exit 1，10 tests / 3 failures (1 unexpected)。此前中断的exit130不算红测试。

环境：Apple Swift 6.4 (swiftlang-6.4.0.34.1)，Darwin 27.0.0 arm64。仅复用离线现有依赖缓存，无安装升级。

```text
Build complete! (90.66秒)
/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-221-simulator-resource-read-retry/CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift:132: error: -[TritonKitCLITests.SimulatorResourceStateTests testReadRetriesAreLimitedAndPreserveThrownFailure] : XCTAssertEqual failed: ("1") is not equal to ("3")
/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-221-simulator-resource-read-retry/Sources/TritonKitCLI/CLISimulatorResourceState.swift:15: error: -[TritonKitCLITests.SimulatorResourceStateTests testReadRetriesTransientReturnedAndProductionThrownFailuresOnSameArgv] : failed: caught error: "commandFailed"
/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-221-simulator-resource-read-retry/CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift:140: error: -[TritonKitCLITests.SimulatorResourceStateTests testTruncatedSuccessIsRejectedWithoutRetry] : XCTAssertThrowsError failed: did not throw an error
	 Executed 10 tests, with 3 failures (1 unexpected) in 2.075 (2.076) seconds
	 Executed 10 tests, with 3 failures (1 unexpected) in 2.075 (2.076) seconds
	 Executed 10 tests, with 3 failures (1 unexpected) in 2.075 (2.077) seconds
```

SHA-256：

- `Sources/TritonKitCLI/CLISimulatorResourceState.swift`: `68ca59a1fe49f8a715c1d88aee6d82ea749080dfb9b02f53c7510f0076760318`
- `CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift`: `92ff557d81ce548444c5978e95d65bb55264a0d627e2bca387bdc7c4c63cc264`
- `docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/red.log`: `df9011968baa4f55a24f3e35afcc0c9dc564b29addb224dcdfbec6d5ca2e5a5d`
