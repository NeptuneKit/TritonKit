# SP-235 · #224 Simulator 显示状态诊断

当前状态：#224 保持开放，等待原 iPhone 瞬态 `queryFailed` 的当次探针。iPad 在正式 v0.2.46 上复现精确 `unsupportedDevice`，默认截图与实时流仍会拒绝，显式主 LCD PNG 已通过。独立 Host HID 验收见 [#277](../SP-274-issue-277-resize-host-input/README.md)。iPhone 实时流的历史证据见 [0.2.38 巡查接替](plans/20261030-release038-followup.md)。

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

## 2026-11-16 当次探针验证

v0.2.46 候选在自有 iPad / iOS 27.0 的默认截图错误内返回当次 `probeDiagnostic`，报告 `native-result`、exit 1、CoreDevice 1001，JSON/log/process 引用可读。显式主 LCD still 截图通过。另一次 doctor 有自己的探针和独立引用，与动作失败分别保存。在自有 iPhone Simulator，正常截图和 Host HID swipe 通过，独立读回公开 fixture 轮播从 item1–4 滑到 item4–7。`queryFailed` 由注入回归测试覆盖；[线上报告的瞬态](https://github.com/NeptuneKit/TritonKit/issues/224#issuecomment-6860613134)本次未复现，根因未知，issue 保持开放。验证汇总见 [SP-292](../SP-292-open-issues-release-046/README.md)。

## 2026-11-16 默认 iPad 预览 409

正式 v0.2.46 在自有 iPad 的默认截图和 Web MJPEG 均复现拒绝。CLI 当次探针确认 `unsupportedDevice` / CoreDevice 1001，目标 doctor 单独复现相同分类。显式 `--primary-framebuffer` 得到 2048×2732 PNG，自有 iPhone 对照收到真实 MJPEG。#224 线上最后一次属于瞬态 `queryFailed`，原因仍未知。

影响层为 CLI 进程的只读 HTTP 路由。验收场景：当 MJPEG、单帧或直接 framebuffer 拒绝未知 Resize 时，HTTP 409 返回当次探针的分类、阶段与原生错误事实，并附绑定同一目标的诊断命令。原始产物路径留在本机。活动会话仍拒绝，未知状态不启动订阅，健康 iPhone 流照常解码。显式主 LCD PNG 仍走既有独立命令。

复验：本地候选的三个 HTTP 入口都在自有 iPad 返回当次 `probeDiagnostic.reason=unsupportedDevice`、`stage=native-result`、CoreDevice 1001 以及指定目标的 doctor 动作。HTTP 省略本地文件路径，CLI 保留三个可读取的产物引用。三个入口的拒绝回归覆盖相同原生错误码下的 `queryFailed`、精确 `unsupportedDevice` 以及活动状态，验证未启动订阅。iPhone 的普通 JPEG 和 MJPEG 首帧均解码为 1206×2622，iPad 显式主 LCD PNG 为 2048×2732。39 项专项测试通过。正式 v0.2.46 的 6 次对照 iPhone 截图均成功，原瞬态缺当次回执。此变更在本地验收。

完整 CLI 1,900 项、根包 313 项和本地总门禁通过。通用 Xcode Simulator 构建按 CLI 诊断改动范围跳过。使用优化构建产物在仓库外以 packaged 模式重跑三个 iPad 409 入口、iPhone JPEG/MJPEG 解码和显式主 LCD PNG，结果一致。原始回执位于本地忽略目录 `.build/issue-followup-20261116/`，发布版本仍为 v0.2.46。

### 五项现场证据

- #224：失败的 iPhone 截图回执要包含时间、CLI/Xcode/runtime 版本、当次探针阶段、退出状态、原生错误域与错误码或缺少原生回执的原因。后续成功的 doctor 单独标记时间。 [回帖](https://github.com/NeptuneKit/TritonKit/issues/224#issuecomment-6912155612)
- #237：原 App 更新 SDK，并记录 `Package.resolved` 的 TritonKit revision。在原页面复跑默认快照、forms-only 与文本等待。仍失败时附 typed error、WKErrorDomain 和行列。 [回帖](https://github.com/NeptuneKit/TritonKit/issues/237#issuecomment-6912084430)
- #238：已许可且可运行原 App 的 HVD，同一 CDP discovery 页面复跑 `pageInit`。断连时保存同次转发、连接阶段、typed error 和 POSIX 等原生错误。 [回帖](https://github.com/NeptuneKit/TritonKit/issues/238#issuecomment-6912086647)
- #246：已许可的 HVD 和真实 IME，独立核对空串、恰好三个空格、普通文本及延迟回读，每案保留单次提交证据。Harmony `act clear` 仍是 `unsupported_capability`，须另验清空结果。 [回帖](https://github.com/NeptuneKit/TritonKit/issues/246#issuecomment-6912088807)
- #274：原低内存机的启动入口、脱敏父进程链、模型规格、内存或 RSS 时间线、取消／超时结果与同窗口 CLI/HTTP 响应。 [回帖](https://github.com/NeptuneKit/TritonKit/issues/274#issuecomment-6912090887)

2026-11-26：三个只读 HTTP 路由的 Resize 当次诊断随 v0.2.47 发布。重启后两次 iPhone 截图拒绝为 `ios_simulator_display_safety_unknown`，第三次成功为 1206×2622。仍缺原 Resize `queryFailed` 的当次回执，#224 保持开放。[最新回复](https://github.com/NeptuneKit/TritonKit/issues/224#issuecomment-7169333500)
