# 2026-10-21 联合验收与本地合并

## 候选与合并

- SP-214 候选 `bee3d609`，包含 `5a3a6d8a`、`943f46c3` 的显示拓扑解析、fresh `devicectl` probe、截图/AX fail-closed 接线。
- SP-215 主控文档候选 `fd08b3e6`。
- SP-216 候选 `5d5647b5`，包含 Harmony ArkWeb forward listing、归属复核和进程内清理互斥。
- SP-217 主控文档候选 `8ae12a03`。
- SP-218 已在本地 `main`，产品合并 `c2f4bdd1`，既有收口文档为 `ec595020`、`af91bf80`、`164e186f`。
- 本轮顺序合并到 `main`：SP-214 merge `0d35e95e`，SP-215 merge `b782c192`，SP-216 merge `34f713c7`，SP-217 merge `36145c62`。未推送、未 tag、未 release。

## 验证结果

- SP-214：`swift test --package-path CLI --scratch-path .build/sp214-final --no-parallel --filter 'SimulatorDisplaySafetyTests|SimulatorResizeCaptureRoutingTests'`，7 tests / 2 suites passed。
- SP-216：`swift test --package-path CLI --scratch-path .build/sp216-final --no-parallel --filter HarmonyArkWebBridgeCallTests`，37 tests / 1 suite passed。
- SP-218：沿用已完成任务的 CLI 1501 tests / 152 suites、Web 78 tests、root/release/smoke 证据；本轮未重复相同长测。
- 合并后完整 CLI：1507 tests / 153 suites passed。
- `docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 均通过；local gate 根包 293 tests / 41 suites passed，Release CLI build、Harmony host smoke、iOS runtime observe smoke 通过，Xcode build 按环境开关跳过。

## 未执行边界

未启动真实 iOS Simulator/Xcode display topology、真实 Harmony HDC、跨进程 forward 竞态、真实 guest touch、双架构发布/安装或用户设备验收。离线 fixture/fake-HDC 绿色结果不替代这些运行验收。
