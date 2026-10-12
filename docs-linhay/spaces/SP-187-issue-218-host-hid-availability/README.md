# SP-187 · Issue 218 host HID availability

- 状态：本地实现与 focused 验证通过，待主控集成。
- Issue：[218](https://github.com/NeptuneKit/TritonKit/issues/218)
- 影响层：CLI host adapter / doctor / schema；无新 HTTP/Web 控制面。

## BDD 与边界

1. Given selected Xcode 的 SimulatorKit 缺失或无法加载，When 明确选择 Simulator 查询 doctor，Then 返回 typed compatibility reason；实际 Baguette bootstrap 失败按 typed reason 返回，不自动重试或切换 backend。
2. Given legacy class 缺失而 modern class 存在，Then `ios_host_hid_modern_backend_unsupported`，不猜测私有新 ABI。
3. Given legacy class 存在，Then 仅 `compatible=true`；`available=false`、`inputDispatchVerified=false` 与 `framework-compatibility-only` 明确没有 dispatch 验证。
4. Given idb 版本探测、inventory、layout 可读，Then 不将这些事实提升为 host HID available。
5. `device doctor --platform ios --device <selector>` fresh resolve 一个已 boot Simulator，再报告其 selected-toolchain compatibility；不 boot、不发送触控、不切换全局 Xcode。

## 验证

`IOSHostHIDProbeTests` 覆盖 selected layout、缺失/loading/legacy/modern typed reason、class-only 边界、诊断保留和 parser。旧 idb doctor 测试同步收紧。真实现代 Xcode touch 及业务命中本轮未执行，不宣称恢复 host input。

- 2026-10-12：focused 15 tests / 3 suites 通过；隔离 bootstrap 缺框架实际 CLI envelope 返回 loaded=false、dlopen_failed。未触碰设备输入。
- `git diff --check` 通过；`verify.sh --ci-docs` 与 `check-docs.sh` 目前仅因新 SP-187 尚未由主控统一登记 index 而失败，待集成写回。
- 本轮通过隔离子进程读取 framework/class metadata；既有 action 不以此诊断作前置 gate。实际 bootstrap 失败 typed 分类并脱敏，不重试/不切换后端。

### Bootstrap EOF follow-up

- Swipe input helper 在首 ACK 前退出时也保留 bounded stderr，经 typed 分类输出；最多保存 16 KiB，后台持续排空避免管道堵塞，失败 cleanup 带终止/强制结束及有界等待。
- 真实 fake process 输出超过 16 KiB 的 bootstrap 诊断并 exit 1，经过 lifecycle 和最终 error envelope 验证为 `ios_host_hid_legacy_backend_unavailable`，不泄漏私有路径/原日志。
- 新增 probe + bootstrap + 既有完整 touch lifecycle focused 8 tests / 2 suites 通过；未执行真实 Simulator input。
- provenance 区分 `provided`、`DEVELOPER_DIR` 与 `xcode-select`，只有实际查询时记录 xcode-select；隔离 bootstrap 命令用静态路径占位，不公开本地路径。
