# Round 177 - simulator gate port collision hardening

## 目标

降低模拟器门禁在连续运行时的端口冲突噪声，避免 `verify-ios-runtime-observe-smoke.sh` 固定端口复用导致的偶发 traceback。

## 变更

1. 调整 `docs-linhay/scripts/verify-simulator-gate.sh`：
   - quick/full 模式在调用 `verify-ios-runtime-observe-smoke.sh` 前，自动注入随机 `TRITON_IOS_RUNTIME_SMOKE_PORT`。
   - 输出实际使用端口，便于排查。
2. 保持门禁结构不变：quick 仍覆盖 simulator domain 核心测试；full 继续叠加 iOS WebView harness。

## 验证

- `docs-linhay/scripts/verify-simulator-gate.sh quick`
- `docs-linhay/scripts/check-docs.sh`
- `git diff --check`
