# 2026-10-28 验证记录

> 历史冻结记录。当前整合、测试结论及未验边界见[SP-241联合验收](../../SP-241-open-issues-validation/plans/20261028-validation.md)。下文中断/待验描述只对应当时的独立分支。

- 基线：a0d187ac；独立 SP-239 worktree。
- RED：新增 `RunnerObservationGeometry` 用例后、实现前，RunnerProtocol 编译失败 `cannot find RunnerObservationGeometry in scope`。记录 `20261028-red.log`。
- GREEN：`swift test --package-path Sources/TritonKitCLI/Resources/ios-runner --jobs 2 --no-parallel --filter HTTPProtocolTests`，20 tests / 0 failures；记录 `20261028-green.log`。
- 后续完整 protocol test 使用仓库根独立 scratch `.build/runner-protocol`，避免在打包资源目录生成 `.build`。第一次 scratch已移至根 `.build/runner-protocol-initial`，不属于分发源。
- `swiftc -parse .../TritonIOSRunnerTests.swift`：通过；仅语法，不能代替iOS编译或设备运行。
- manifest通过正式 `package-ios-runner-resources.py` 重新生成并校验。
- 未执行：物理设备 UI fixture、真实问题复现与签名编译、完整CLI/root/local。由主控统一验证。

## 设备验证交接

在保存Triton-first事实后，使用同一候选资源 project/scheme `TritonIOSRunner`，仅测试 `TritonIOSRunnerTests/testCrossAppObservationWithoutOrientation`，覆盖fixture probe→activate→有效inspect→未知orientation inspect/screenshot→旧coordinate拒绝→非前台拒绝。该测试通过注入orientation模拟已知错误，不等于重现物理设备报告。另需在受影响设备对真实allowed app完成start→activate→inspect/screenshot，记录实际geometryError.field或成功geometry。

## 冻结前结果

- 完整 shipped RunnerProtocol：`swift test --package-path Sources/TritonKitCLI/Resources/ios-runner --scratch-path .build/runner-protocol --jobs 2 --no-parallel`，32 tests / 0 failures（HTTPProtocol 20 + RunnerServer 12）。日志 `20261028-protocol-full.log`。
- `verify.sh --ci-docs` 的CI scope classifier通过，随后 docs结构失败；`check-docs.sh` 同样失败于编号连续性（当前只有SP-239登记，SP-228～238在其它并行worktree），需主控统一登记再验。
- `git diff --check`通过。CLI新增 lifecycle forwarding fixture未执行；禁止以协议测替代CLI/真实设备测试。
