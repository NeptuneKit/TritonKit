# SP-235 · #224 Simulator 显示状态诊断

当前状态：已随PR #233合入远端main（`40850dde`），issue #224已completed关闭；现场复验范围见[远端处置](https://github.com/NeptuneKit/TritonKit/issues/224#issuecomment-6460618236)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
## 边界和现状

基线 main `a0d187ac`。只补显式目标 doctor 的 appResize/displays 只读事实与精确恢复指令，不绕过 unknown geometry 截图/触摸拒绝。#224全文及三条评论已经核对；Xcode27.1 topology bug 由 SP-218/v0.2.33 修复，Xcode26.6 旧 appResize 兼容性不能从该证据推断。影响 CLI host diagnostics/schema/failure envelope；无新 Web/HTTP 控制面。

## BDD / TDD

1. Given doctor 未传 --device，Then 不新增任何目标 resize/display 查询。
2. Given 显式已解析的 Simulator，When doctor，Then 分别报告 appResize 与 displays 状态/reason、绑定精确目标的 nextAction；unknown 不抹成 inactive/ready，工具可用不代表 capture/input 已验证。
3. Given 截图显示门禁失败，Then 返回既有 typed code 与同目标恢复 argv，零 capture side effect；不得回退未绑定 framebuffer。
4. Given 原始 selector 非 UUID，Then 不反射进新恢复指令，也不调用 geometry query。
5. Given selected HID/AX 或 screenshot unknown，Then 保留失败与独立业务验证边界，不放宽触控保护。

## 当前阶段与验证

本地联合实现、完整CLI与local验收完成；现已合main并关闭对应issue；本批次未发布。

- 新增 `CLIHostSimulatorDoctorDiagnostics.swift` 输出独立只读快照；仅显式已解析 Simulator 时运行，附精确 target/recovery。
- `failHostCommand` 补 `IOSSimulatorDisplayError` typed 映射；生产 screenshot、AX 和 HID failure 绑定恢复目标，不改原门禁。
- `SimulatorDoctorDiagnosticsTests` 覆盖无选择/非法目标零查询、不同 unknown 状态独立保留、snapshot不升级验证、零截图副作用、DTO/schema 和 single typed envelope。
- 已先编写测试并启动红测试；默认 Swift Build 冷编译导致宿主高负载，主控要求停止，本任务精确 session 退出130。**当时红测试未到测试编译，不宣称旧实现断言失败；候选绿测现已随SP-241完整CLI通过。** 原日志在本 worktree `.build/issue-validation/20261028-red-tests.log`，不公开私人路径。
- `git diff --check` 通过。全量与文档编号门禁已在SP-241通过；本 worktree 不伪造缺失 SP 编号。
- 真实Simulator的目标doctor已验证独立diagnostics和capture/inputVerified=false；Xcode26.6/原用户项目未执行；没有改变未知状态的安全边界。#224 在本轮只关闭诊断缺口，不宣称旧工具链的 appResize 根因已复现解决。

## 经验

已经沿用 host skill 的“原生命令响应先取证、unknown fail-closed、输入与截图不同证据”规则。新增诊断解释写回 CLI 权威文档与 public skills；未新增重复经验文件。
