# SP-128：Xcode 真机 alias preflight

## 状态

- 状态：本地集成已验证；等待主分支收口
- Issue：GitHub #167
- 基线：`feat/SP-126-testrec-convergence@5f6c2f6f`
- Branch：`feat/SP-128-issue-167-xcode-device-alias-preflight`
- Worktree：`../TritonKit-worktrees/SP-128-issue-167-xcode-device-alias-preflight/`
- 影响层：CLI 的 Xcode command/target-resolution runtime 与对应 schema/test

## 问题边界

`xcode run --device <selector>` 的 real-device 路径当前先调用 `xcodebuild`，之后才解析 host device selection。子目录中的 alias store 缺少 selector 时，命令会先承担完整 build 和 build-settings 查询的成本，最后才返回 target failure。本 slice 将顺序收敛为：target preflight -> build -> product resolution -> install/launch；不改变 alias store、discovery、install 或 launch 的既有行为。

## BDD / DoD

1. 从 alias 不可解析的子目录发起 real-device `xcode run` 时，selection preflight 返回单一合法 machine-readable `target_not_found`（含 recovery），且 `xcodebuild`、build-settings/product resolution、install 和 launch 均未发生。
2. alias 可解析或使用显式 real-device selector 时，既有 `xcodebuild` 的 SDK、destination、argv，以及后续 install/launch 路径保持不变。
3. focused Swift tests 使用窄的 preflight/build closure seam 证明失败时 build closure 不调用，并覆盖成功 selection 的顺序；不启动真实昂贵 build 或真实设备。
4. Xcode schema 声明 `target_not_found`、`ambiguous_target` 和 `target_platform_mismatch`；root/run 的 real-device selection failures 使用 `triton target resolve <selector> --platform ios --scope real --ready --json`，其它 schema（含 `target`）继续使用 generic recovery。

## 范围

允许修改：Xcode command/target-resolution runtime、对应 focused tests、此 space 及本 slice 的索引和 memory。

不在范围：evidence、#164、#166、#168、testrec、serve、Web、Android、alias store/discovery 语义、真实 xcodebuild、真实设备和远端 GitHub 操作。

## 验证与风险

- 独立 scratch：`.build/sp128-xcode-alias-preflight`，不与其他 slice 共享。
- 计划运行：`git diff --check`、docs 结构检查、匹配的 focused Swift tests；按结果再评估 `docs-linhay/scripts/verify.sh --local`。
- 第二轮窄 TDD 已验证 `XcodeCommandTests` 22/22、`FailureDiagnosticsTests` 13/13；除 schema recovery 外，runtime `HostDeviceSelectionError` 也以同一 iOS real target-resolve argv 输出单一 `nextAction` envelope。schema broader suite 的既有 device proxy、sim app-console、device 参数/selector contract failures 未纳入本 slice。
- XcodeBuildMCP 参考文档在当前 checkout 缺失，记录为环境文档风险；本 slice 不修复该文档，也不以真实 Xcode/设备运行替代单测。
- 此路径的 selection resolver 可达 `target_not_found`、`ambiguous_target`（`booted` 多候选）和 `target_platform_mismatch`（alias 平台与固定 iOS request 不符）；Xcode root/run recovery 已携带 iOS real scope 与 ready 约束，`target` 等其它 schema 保持 generic。`parameter_conflict` 不由该固定 selection request 产生，双 selector 仍属于另一条 Xcode workflow error 路径。

## 停止条件

完成上述 BDD、focused tests、文档检查和本地 checkpoint commit 后停止；只把 commit/hash、命令输出和未覆盖的 selection failure family 交回主控。禁止 push、PR、merge、tag、release、关闭 issue，以及删除或清理任何 worktree/branch。

## 当前收口状态

- source checkpoint `25f7e048` 已纳入本地 integration commit `0ceb825c`；`XcodeCommandTests` 22/22 与 `FailureDiagnosticsTests` 13/13 在联合 scratch 中通过，Xcode root/run schema 和 runtime error envelope 的 iOS real `target resolve` recovery 已由 focused tests 复核。
- `SchemaFactSourceTests` 与共同基线保持同一 119 tests / 12 个既有 failure signatures；空间/索引的连续编号门禁在联合分支已通过。
- 未覆盖真实 `xcodebuild`、真实 device 或子目录 live alias store；这些是本 slice 有意保留的环境边界，不应以纯 preflight tests 代替。尚未合入 `main`，无远端操作。
