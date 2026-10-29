# SP-235 · #224 Simulator 显示状态诊断

当前状态：用户要求继续处理#224；v0.2.35后反馈仍有queryFailed，原诊断缺口修复不能视为根因解决。已定位iPad能力拒绝并完成最小分类修复/失败测试/真实验证，#224已恢复OPEN，iPad默认截图/输入仍受限，显式主屏截图续作见下方验收，按用户追加要求仅验收Xcode27.1；旧completed记录保留历史含义，后续不据它判定问题全部解决。
## 边界和现状

基线 main `a0d187ac`。只补显式目标 doctor 的 appResize/displays 只读事实与精确恢复指令，不绕过 unknown geometry 截图/触摸拒绝。#224全文及三条评论已经核对；Xcode27.1 topology bug 由 SP-218/v0.2.33 修复，Xcode26.6 旧 appResize 兼容性不能从该证据推断。影响 CLI host diagnostics/schema/failure envelope；无新 Web/HTTP 控制面。

## BDD / TDD

1. Given doctor 未传 --device，Then 不新增任何目标 resize/display 查询。
2. Given 显式已解析的 Simulator，When doctor，Then 分别报告 appResize 与 displays 状态/reason、绑定精确目标的 nextAction；unknown 不抹成 inactive/ready，工具可用不代表 capture/input 已验证。
3. Given 截图显示门禁失败，Then 返回既有 typed code 与同目标恢复 argv，零 capture side effect；不得回退未绑定 framebuffer。
4. Given 原始 selector 非 UUID，Then 不反射进新恢复指令，也不调用 geometry query。
5. Given selected HID/AX 或 screenshot unknown，Then 保留失败与独立业务验证边界，不放宽触控保护。

## 历史诊断交付阶段与验证

本地联合实现、完整CLI与local验收完成；现已合main并关闭对应issue；本批次未发布。

- 新增 `CLIHostSimulatorDoctorDiagnostics.swift` 输出独立只读快照；仅显式已解析 Simulator 时运行，附精确 target/recovery。
- `failHostCommand` 补 `IOSSimulatorDisplayError` typed 映射；生产 screenshot、AX 和 HID failure 绑定恢复目标，不改原门禁。
- `SimulatorDoctorDiagnosticsTests` 覆盖无选择/非法目标零查询、不同 unknown 状态独立保留、snapshot不升级验证、零截图副作用、DTO/schema 和 single typed envelope。
- 已先编写测试并启动红测试；默认 Swift Build 冷编译导致宿主高负载，主控要求停止，本任务精确 session 退出130。**当时红测试未到测试编译，不宣称旧实现断言失败；候选绿测现已随SP-241完整CLI通过。** 原日志在本 worktree `.build/issue-validation/20261028-red-tests.log`，不公开私人路径。
- `git diff --check` 通过。全量与文档编号门禁已在SP-241通过；本 worktree 不伪造缺失 SP 编号。
- 真实Simulator的目标doctor已验证独立diagnostics和capture/inputVerified=false；Xcode26.6/原用户项目未执行；没有改变未知状态的安全边界。#224 在本轮只关闭诊断缺口，不宣称旧工具链的 appResize 根因已复现解决。

## 经验

已经沿用 host skill 的“原生命令响应先取证、unknown fail-closed、输入与截图不同证据”规则。新增诊断解释写回 CLI 权威文档与 public skills；未新增重复经验文件。

## 2026-10-28 后续根因修复

影响层：CLI host Simulator Resize probe及其截图/输入消费者；不绕过unknown门禁，不改Web写入范围。基线d966c559，分支codex/issue-224-resize-query复用干净SP241集成worktree与缓存，原主目录WIP隔离。

BDD：真实已停止/活动Resize查询须按原生结构、完整命令回执和目标身份判定；先以脱敏原生失败fixture证明旧实现误分类，再最小修复。错误包装不能把一般query failure、混合错误、无目标回执或超预算输出误作inactive；截图通过不证明HID成功。真实验证仅使用本任务新建Simulator，设备与scratch操作串行。

当前后续事实源：[Resize capability rejection](plans/20261028-capability-rejection.md)，接替旧记录的完整关闭含义；v0.2.35已发布旧diagnostics修复，本轮部分修复尚未发布。

用户追加范围：只用Xcode27.1测试即可，旧Xcode26.6不再作为本次阻塞。部分修复已提交为5296ec2e并创建[PR #236](https://github.com/NeptuneKit/TritonKit/pull/236)，#224保持OPEN；iPad默认捕获/输入仍受限；PR已按用户授权合并，未发布。

## 2026-10-28 继续：显式主屏截图

新增CLI显式 `--primary-framebuffer`，限定单LCD still PNG，保持Resize unknown和全部输入保护；BDD/真实生命周期证据与验证结果统一维护于[主屏截图验收](plans/20261028-primary-framebuffer.md)。之前“捕获仍拒绝”指默认路径；本模式独立声明范围，不推导完整问题已解决。

## 2026-10-29 合入main

用户明确授权后，[PR #236](https://github.com/NeptuneKit/TritonKit/pull/236)已合入main，merge commit `27c7a87597274649e62a00b2cf1dad92b12677f9`。候选8c2fab81的Swift/CLI Release、CocoaPods和contracts CI全部通过；merge tree与该候选完全一致。#224保留OPEN，剩余iPad默认捕获/输入限制未解除；#214暂缓，主目录17个WIP保持不变，未发布。此前未合并文字仅表示对应历史阶段。
