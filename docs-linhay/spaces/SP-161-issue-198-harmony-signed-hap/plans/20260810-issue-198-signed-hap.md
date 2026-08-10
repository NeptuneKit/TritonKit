# #198 signed HAP 修复计划

## 契约

- `assembleApp` 的 HAP 发现只接受文件名 token 含 `signed` 的 HAP；未发现 signed 候选时返回既有 `hap_artifact_not_found` 失败。
- 成功摘要中的 `artifact` 与 `artifactPath` 相同，`nextAction.args` 的 `--hap` 值必须逐字复用该路径。
- 默认 `assembleHap` 路径仍兼容历史 debug/emulator unsigned HAP 发现，不宣称其为 real-device installable signed artifact。

## 验证记录

- [x] `swift test --package-path CLI --scratch-path .build/sp161-198 --filter BuildRunnerTests` — 10/10 通过。
- [x] `swift test --package-path CLI --scratch-path .build/sp161-198 --filter BuildRuntimeTests` — 4/4 通过，含默认 assembleHap unsigned fixture。
- [x] `git diff --check` — 通过。
- [x] `swift build --package-path CLI --scratch-path .build/sp161-198-release -c release --product triton` — 通过（`Build of product 'triton' complete`）。
- [x] `docs-linhay/scripts/check-docs.sh` — 主控登记 SP-161/SP-162 后通过（`162 spaces registered`）。

## 风险 / 停止条件

- 仅有本地 fixture 证据；没有可公开的 Harmony 签名工程、证书/profile 或 real-device/HDC 环境，因此不执行真实安装。
- 若 DevEco 使用不含 `signed` token 的 signed HAP 命名，需在后续带真实产物的切片中补充明确命名/签名校验，不在本 issue 中猜测成功。
