# Round 179 - release skill version parser runner compatibility（2026-06-01）

## 背景

- `v0.1.13` 发布 run（`26749922464`）仍失败于 `Package arm64 release assets / Validate release asset set`。
- 根因不是业务逻辑，而是 runner 可用工具差异：workflow 使用了 `rg`，Ubuntu release runner 未安装 ripgrep。

## 变更

- 文件：`.github/workflows/ci.yml`
  - 将 skill 版本行提取从 `rg '^  version: '` 改为 POSIX 常见工具：
    - `sed -n 's/^  version: .*/&/p'`
- 文件：`docs-linhay/scripts/verify-release-automation.sh`
  - 新增 release 合约检查：禁止 workflow 在该校验链路依赖 `rg`。

## 验证

- `docs-linhay/scripts/verify-release-automation.sh` 通过。
- `docs-linhay/scripts/check-docs.sh` 通过。
- `git diff --check` 通过。

## 后续动作

- 提交后重新发布下一版 tag。
