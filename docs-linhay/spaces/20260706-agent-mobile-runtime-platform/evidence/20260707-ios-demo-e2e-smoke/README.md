# 2026-07-07 iOS Demo End-to-End Smoke Evidence

本目录记录一个可控 iOS Simulator target scope 的完整端到端 smoke。目标是补齐 `20260706-agent-mobile-runtime-platform` space 中“target discovery -> session ready -> app launch -> screenshot -> action -> evidence export”的最小真实验收链。

## Smoke 结果

- Target discovery：`target-resolve-selected.json` 明确选中 `sim:83407554-53AB-45B4-A0C1-D59F34E26A67`，设备为 `iPhone 17 Pro / iOS 26.5`。
- App launch：`xcode-run-demo.jsonl` 通过 `triton xcode run` build/install/launch `TritonKitDemo`，launch source command 注入 `TRITON_HOST` / `TRITON_PORT` 并已脱敏。
- Session ready：`targets-after-demo-launch.json` 显示唯一 runtime target `triton:ios-simulator:83407554-53AB-45B4-A0C1-D59F34E26A67/app:com.neptunekit.tritonkit.demo`，`connected=true`，`hierarchyCacheState=active`。
- Screenshot：`screenshot-before-action.png` 和 `screenshot-after-action.png` 都由 `triton screenshot` 从 live runtime 采集，metadata 分别在同名 `.json`。
- Action：`tap-primary.json` 显示 `triton act tap Primary` 命中 `UIButton`；`wait-complex-harness-1.json` 显示 `Complex harness: 1` 匹配成功，identifier 为 `ComplexHarnessStatus`。
- Evidence export：`evidence-capture-demo.json` 显示 `triton evidence capture` 成功导出 `demo.tritonevidence`，包含 9 个 artifact；`evidence-summary-demo.json` 给出后续 redact 建议。
- Workspace / Atlas：`workspace-run-ios-demo.json` 返回 `status=passed`，target 已通过 host discovery 解析；`workspace-runs/ios-demo-e2e/atlas/app-map/app-map.json` 存在，coverage 记录 `observedRuns=1`、`passCount=1`、`screenCount=1`、`stateCount=1`。

## 可复跑入口

脚本入口：

```bash
TRITON_BIN=.build/cli/release/triton \
TRITON_IOS_DEMO_SIMULATOR=83407554-53AB-45B4-A0C1-D59F34E26A67 \
TRITON_VERIFY_OUT_DIR=.build/ios-demo-e2e-smoke-script \
docs-linhay/scripts/verify-ios-demo-e2e-smoke.sh
```

本机有多个 booted simulator 时，脚本不会自动选择 `booted`，需要显式传 `TRITON_IOS_DEMO_SIMULATOR=<udid>`。
