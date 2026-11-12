# SP-281 P0/P2 — 历史候选测试记录（完成声明已纠正）

> 2026-11-12复核：下列测试结果是真实历史候选结果，但曾把helper标签测试当成Simulator真实入口接线，并把局部投影称为P2完成，这个结论不成立。当前范围见[README](../README.md)和[提交收口](./20261112-session-closeout.md)。

## 当时执行面（非P2完成证明）

当时在main串行修改parser和host receipt投影，保留其它WIP；未操作设备或推送发布。P2迁移未完整实现。

- P0：修复 device parity HTTP 生成 `device ... --json` 后 typed action parser 不接受 `--json` 的真实 argv 接线。
- P1：复用 `TKActionAdmissionCoordinator` / `TKActionReceipt` 作为 host mutation 的统一投影，并保持动作提交成功不等于业务完成。
- app lifecycle正常返回分支增加shared receipt；sim.tap/swipe/press只进入helper的标签测试，不是实际HID调用迁移，旧输出字段保留。

P3 approval control plane、P4 remote admission、P5 session resume、P6 真实设备/发布范围仍未实现。

## P0 修复

`CLIDeviceParityHTTP` 继续对受限命令追加 `--json`；`DeviceActionCommonOptions` 现在显式接受 `--json` 和 `--format`。新增两类测试：

- direct typed action parser accepts `--json`;
- `deviceParityHTTPArguments` 生成的完整 argv 进入 `TritonKitCLI.parseAsRoot`，不会在 `unknown_option` 处停止。

旧 parity allowlist、payload 限制、禁止 help/jsonl/format 注入和单 JSON envelope 行为保持。

## P1/P2 shared host receipt

新增 `CLIHostActionReceiptRuntime.swift`：

- 对helper传入的operation标签生成digest；当时app.*宽泛判断包含只读命令，提交收口已改明确mutation列表并补负例；
- 使用 shared coordinator issue/consume/generation；
- host exit 0 映射 `delivered/settled/executed=true`，但 `postcondition=unverified`；
- 直接调用helper的非零fixture可映射unknown；真实host非零/timeout throw会跳过这个helper，尚未接线；
- receipt 绑定 action、target、runtimeScope、admissionID、contextDigest、generation；
- `HostActionOutput.actionReceipt` 是 additive 字段，旧字段和 hostAction submission proof 不删除。

这条投影只覆盖runSimpleHostCommand的正常返回分支。实际SimTap/SimSwipe调用runWebHostDeviceInput，根本不经该helper；没有sim.press命令已接入的证据。构造标签的单测不证明真实路由。

## BDD / focused 证据

- parity argv → real root parser：通过；不启动 provider；
- 六种operation标签的receipt构造fixture：通过，不等于六个真实入口接线；
- helper的非零result投影fixture：通过，实际throw路径未覆盖；
- 原 device action/evidence 25 项 focused：通过；
- AppOpenURLFlowTests、SimulatorAdvancedControlsTests：通过；
- 本轮 focused 合计：59 tests / 4 suites，通过。

## 冻结候选验证结果

| 检查 | 结果 |
| --- | --- |
| `swift test --package-path CLI --no-parallel` | **1858 tests / 204 suites passed**，exit 0 |
| root package（local 内） | runtime **130 tests / 26 suites**；shared **313 tests / 45 suites**，通过 |
| `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` | exit 0；依赖边界、iOS DEBUG 隔离、root、release CLI build、CLI/Harmony/iOS observe smoke、docs、diff通过 |
| `docs-linhay/scripts/verify.sh --ci-docs` | exit 0；docs、skill、release contract通过 |
| P0-P2 focused | **59 tests / 4 suites passed**；包含 parity argv、app lifecycle、Simulator HID、shared receipt、原 device evidence |
| Simulator build | 显式 `TRITON_VERIFY_XCODE=0` 跳过；未执行设备动作 |

通过结果绑定当前 main 工作区候选，不继承历史 SP-281 304/1685 计数。

## 完成边界

P0 parser修复和部分host正常投影有效；P2原范围未完成，不能重新定义“完成”来覆盖缺口。WebView/管理/workspace/replay未统一owner；需要逐入口补真实调用与失败测试。

当时WIP未提交。本轮用户已授权本地归档提交；上表仅当时测试采样，不冒充提交候选最新结果，当前结果见提交收口。
