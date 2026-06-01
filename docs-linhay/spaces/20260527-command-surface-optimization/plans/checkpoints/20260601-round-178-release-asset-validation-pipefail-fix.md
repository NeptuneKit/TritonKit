# Round 178 - release asset validation pipefail fix（2026-06-01）

## 背景

- 在 `v0.1.12` tag 发布时，CI run `26749313825` 于 `Package arm64 release assets` 阶段失败。
- 失败步骤：`Validate release asset set`。
- 失败根因：`set -euo pipefail` 下使用 `tar -xOf ... | grep -Fxq ...`，`grep` 提前退出后 `tar` 收到 `SIGPIPE` 返回非零，导致步骤失败（`Broken pipe`）。

## 变更

- 文件：`.github/workflows/ci.yml`
- 步骤：`Validate release asset set`
- 调整：
  - 用循环提取每个 skill 的 `version` 行后再做字符串比较；
  - 不再直接使用 `tar | grep` 管道校验，规避 `pipefail` + `SIGPIPE` 假失败。

## 验证

- `docs-linhay/scripts/verify-release-automation.sh` 通过。
- 本地复现脚本验证新版校验逻辑可正确通过 skill 版本断言，不触发 `Broken pipe`。

## 后续动作

- 提交修复后重新触发下一版 tag release。
