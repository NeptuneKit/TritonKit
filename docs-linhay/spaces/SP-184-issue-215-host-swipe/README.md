# SP-184 · Offline iOS Simulator host swipe

对应 GitHub issue #215。范围是本机 iOS Simulator 的 CLI host 输入，不启动 embedded Triton server，也不扩展到真机、远端 agent 或 Web 控制面。

## BDD 验收

- Given 一个 booted local iOS Simulator，When 执行 `triton sim swipe --simulator booted --start-x 360 --start-y 700 --end-x 80 --end-y 700 --duration 0.35 --json`，Then 命令只解析 host Simulator target，并通过现有 host HID/Baguette 输入生命周期提交 down/move/up。
- Given host action 返回成功，Then JSON 明确这是 submission-only，并提供 `verification.required` 与 follow-up screenshot/AX/verify 建议；不把 pager 已 settled 当作成功。
- Given host adapter 或 Baguette 不可用，Then 保持单一失败 envelope，不回退 embedded server，也不伪造业务成功。

坐标使用 Simulator point-space；宽高从 Baguette layout metadata 推导，可成对传源图 `--width/--height` 做归一化；duration 必须是有限正数且不超过 10 秒。真实 Simulator/Baguette 回归需要独立 macOS 环境，本切片以 parser、schema 和离线 lifecycle fixture 验证。

## 2026-10-12 验证

- `TRITON_CLI_PATH="$PWD/CLI/.build/out/Products/Debug/triton" swift test --package-path CLI --filter 'SimulatorSwipeTests|SimulatorAdvancedControlsTests|CLIHelpTests/simSwipeHelpAndValidationAreOffline|SchemaFactSourceTests' --no-parallel`：163 tests / 4 suites 通过。
- `docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 通过。
- `sim swipe --help`、非法 duration / 缺半边 geometry 的单 JSON 非零失败、host dispatch fixture、source-space 归一化与 terminal-up fixture 已覆盖。
- 未运行真实 Simulator pager 验证、完整 CLI suite 或 local gate；交由主控集成验证。状态：ready-to-commit，按主控要求由主控串行提交。
