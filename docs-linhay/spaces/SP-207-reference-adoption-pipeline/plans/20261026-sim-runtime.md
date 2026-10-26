# 2026-10-26 Simulator / runtime 参考日检

实际 main `24e7d0f21017c8ca7104b6f8e3912fc2c44be892` 未变。10仓官方默认分支 HEAD、全 Release 分页（最新非 draft 含 prerelease 完整正文）、固定 HEAD 许可全文/hash已读。7完整/3原有partial。simslim新增1提交13文件；其余HEAD、全部最新Release tag/body、许可hash相对20261025不变。无TLS首错/重试。成功点/import和昨日观察分别比较，未修改共享检查点。

|仓库|HEAD|Release|覆盖|
|---|---|---|---|
|tddworks/baguette|458044cceadd25a1366619b3747311ad7d959f94|v0.2.10|partial|
|EvanBacon/serve-sim|0193e65c481fc9b64a62427f32fcf143dbc3d2c0|无|完整|
|lycorp-jp/sim-use|c02295edfd2f442249b869096dda3dc7bfcd308d|v0.16.0|partial|
|MobAI-App/simslim|2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc|v0.12.2|完整|
|Mastersam07/OpenDeviceHub|e50f07f1f4480cb14d57f192df7bf598ca26e708|v0.2.0|完整|
|JaviSoto/device-hub-ios|3779e12aa00c08bb34805fef8ffe375838cbe815|无|partial|
|heoblitz/Loupe|ff1351242e6dbaba4a0b4de40d10350a668f03b8|v0.5.1|完整|
|jfarcand/mirroir-mcp|502c5e466da4d82df8f65ffa9a598c01e152b56b|v0.40.1|完整|
|RockxyApp/Rockxy|de791b63e7f9b5df49f127524a5c9320e675eb23|v0.41.0|完整|
|ProxymanApp/atlantis|cc059013de8778072b4fea6453b45e964e4202fe|2.0.0|完整|

## 新增量与本地主线

[simslim固定提交](https://github.com/MobAI-App/simslim/commit/2c68da93700aa1a1c45ce31a7ea9f7cac2174ddc)完整compare只有1提交，13文件全文均经Go源码/测试或顶层说明文件用途白名单后读取，保存在MobAI-App__simslim/source。未获取binary/helper/key/cert/identity内容。提交正文包含被同提交后续修订推翻的早期异常文件/lock方案，最终源码已删除该设计，不能按正文前半段误认仍有持久例外或锁。

最终提供booted-only enable/disable单项daemon/category、load/bootstrap后读取disabled与loaded、notStarted/stillEnabled区别，以及显式--save原子维护profile（验证在先，live成功后才写，shutdown只写文件）。当前Triton resource apply/restore语义是profile override与receipt三方恢复，只通过enable/disable修改override，未承诺单项daemon立即启动；verify也明确检查override。因此不能把上游新增live控制直接定成本地错误，或把disabled=false等同进程正在运行。暂不采用全套新控制与profile写操作。

但存在一个可离线验证的窄可靠性候选：上游simctl.go readLaunchd对LaunchdSimError124/Domain is tearing down与有界read timeout有限重试；Triton main CLISimulatorResourceState.readOverrides仅运行一次，任何非零返回即commandFailed。apply默认reboot后及restore/verify/inspection均可能走该reader。主线HostProcessRuntime已有有界timeout/pipe drain，不需要复制Go WaitDelay或扩大通用runner；仅可针对只读print-disabled恢复短暂launchd拒绝，不自动重试mutation。此为固定源码可证明的静态差异，未运行设备，不能声称本机已复现或所有launchd错误都可恢复。

候选交主控决定采用：文件面仅Sources/TritonKitCLI/CLISimulatorResourceState.swift与CLI/Tests/TritonKitCLITests/SimulatorResourceStateTests.swift（如需小型新reader测试夹具可同测试文件）；保持invalidUDID、malformed/truncated、permission及永久失败fail-closed，不变CLI/HTTP envelope、不加新控制面。BDD：给定有效UDID，首个print-disabled返回明确124/tearing-down，下一次返回合法override，则有界只读重试成功且不运行mutation；给定permission、截断或畸形payload立即失败；给定持续124/timeout达到预算，按原错误失败且不无限等待；取消/超时不被静默吞掉。只有可识别runner timeout才能纳入同策略，不把所有throw盲目重试。本轮未写实现、测试或space，父主控可在独立space/worktree执行先失败测试再实现。此候选不是旧SP192/196/200/214/218/219的重复display/HID/录制项。

## 已交付与边界

main-coverage.json保存SP192/196/200/214/218/219及两份20261024真实验收main blob/hash；main-resource-comparison.json保存本次资源reader/runtime/host runner/tests的固定主线证据。Xcode27.1/iOS27.0专用Simulator普通HID、Hub占用拒绝恢复、普通→Resize→普通录制及v0.2.33已有独立交付，不重排。Resize AX/HID仍unsupported，未外推其他工具链或用户工程。本轮未执行设备、构建或第三方代码。

旧Baguette二进制来源、sim-use CHANGELOG省略patch、device-hub-ios protocol.rs省略patch均未闭合，维持partial；其余无变化源码评估复用昨日固定证据。无共享文档/state/git写入、安装、remote写入或会话分派。经验检查沿用现有安全取证与静态/真实证据分离规则，无新增治理模式；窄候选的后续BDD交主控。
