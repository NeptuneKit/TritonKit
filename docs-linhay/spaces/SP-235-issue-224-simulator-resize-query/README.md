# SP-235 · #224 Simulator 显示状态诊断

## 边界和现状

基线 main `a0d187ac`。只补显式目标 doctor 的 appResize/displays 只读事实与精确恢复指令，不绕过 unknown geometry 截图/触摸拒绝。#224全文及三条评论已经核对；Xcode27.1 topology bug 由 SP-218/v0.2.33 修复，Xcode26.6 旧 appResize 兼容性不能从该证据推断。影响 CLI host diagnostics/schema/failure envelope；无新 Web/HTTP 控制面。

## BDD / TDD

1. Given doctor 未传 --device，Then 不新增任何目标 resize/display 查询。
2. Given 显式已解析的 Simulator，When doctor，Then 分别报告 appResize 与 displays 状态/reason、绑定精确目标的 nextAction；unknown 不抹成 inactive/ready，工具可用不代表 capture/input 已验证。
3. Given 截图显示门禁失败，Then 返回既有 typed code 与同目标恢复 argv，零 capture side effect；不得回退未绑定 framebuffer。
4. Given 原始 selector 非 UUID，Then 不反射进新恢复指令，也不调用 geometry query。
5. Given selected HID/AX 或 screenshot unknown，Then 保留失败与独立业务验证边界，不放宽触控保护。

## 当前阶段与验证

静态实现已完成、待主控统一验证；未提交/推送/发布或关闭 issue。

- 新增 `CLIHostSimulatorDoctorDiagnostics.swift` 输出独立只读快照；仅显式已解析 Simulator 时运行，附精确 target/recovery。
- `failHostCommand` 补 `IOSSimulatorDisplayError` typed 映射；生产 screenshot、AX 和 HID failure 绑定恢复目标，不改原门禁。
- `SimulatorDoctorDiagnosticsTests` 覆盖无选择/非法目标零查询、不同 unknown 状态独立保留、snapshot不升级验证、零截图副作用、DTO/schema 和 single typed envelope。
- 已先编写测试并启动红测试；默认 Swift Build 冷编译导致宿主高负载，主控要求停止，本任务精确 session 退出130。**红测试尚未到测试编译，不宣称预期断言失败；绿测试未执行。** 原日志在本 worktree `.build/issue-validation/20261028-red-tests.log`，不公开私人路径。
- `git diff --check` 通过。全量/聚焦/文档编号门禁由主控在联合候选使用 `--build-system native --jobs 2` 统一验证；本 worktree 不伪造缺失 SP 编号。
- 真实 Simulator/Xcode26.6/原用户项目未执行；没有改变未知状态的安全边界。#224 在本轮只关闭诊断缺口，不宣称旧工具链的 appResize 根因已复现解决。

## 经验

已经沿用 host skill 的“原生命令响应先取证、unknown fail-closed、输入与截图不同证据”规则。新增诊断解释写回 CLI 权威文档与 public skills；未新增重复经验文件。
