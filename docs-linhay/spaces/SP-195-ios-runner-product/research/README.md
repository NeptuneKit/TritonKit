> 本档保留实验时的工作区/分支名；其 SP-193 是隔离研究时的临时编号，主仓正式 SP-193 属于 iCTRL参考追踪。实验记录归档在 SP-195，原始研究工作区不移动。

# iOS 设备端常驻 XCUITest Runner 研究归档

## 边界

- 用户请求：研究设备端常驻 XCUITest Runner，评估 iCTRL 机制能否用于 TritonKit。
- 影响层：独立 iOS 测试 Runner、研究用 host HTTP client 和实验 evidence；产品 CLI/HTTP 契约仍不改变。
- 追加授权：用户要求“展开调研和测试”，本期继续最小 PoC 的 SDK 编译与可用目标运行。专用模拟器隔离验证；真机按可发现性、签名和授权事实决定可执行范围，不绕过密码、不修改系统开发配置。
- 基线：`main@8aaf6c31d308194b489e10ed83362cee91f549d5`。
- 分支：`feat/SP-193-ios-resident-xctest-runner`。
- 独立 worktree：`../TritonKit-worktrees/SP-193-ios-resident-xctest-runner/`。
- 状态：最小实测及多 App 场景实验已完成；Safari 输入与截图归属部分未通过，产品集成及完整生命周期待定。

## 研究验收场景

1. Given iCTRL 的固定源码版本，When 核对构建、签名、启动和运行循环，Then 说明 XCUITest 权限来源、Runner 与主 App 的关系，以及脱离 Xcode 不同阶段的前提。
2. Given 后台、锁屏、授权、DDI、进程崩溃和设备重启，When 评估长驻边界，Then 不把运行循环等同系统保活，不把 wake 等同解锁，不把源码宣称等同真机验证。
3. Given TritonKit 现有 host/embedded 架构，When 制定接入方案，Then 保持 CLI/HTTP 为事实入口、设备与 App 绑定、单一失败 envelope、机器可读恢复、串行副作用和 Release runtime no-op。
4. Given 未执行设备动作，When 交付研究，Then 给出按阶段可执行的 BDD/验证计划，并明确 SDK/静态检查不能证明真机启动、后台存活或业务动作成功。

## 交付

- [机制、证据缺口与 TritonKit 接入方案](./mechanism.md)。
- [分阶段设备实验与 BDD 验证计划](./plans/validation.md)。
- [追加跨 App 场景与 BDD](./plans/20261014-cross-app-validation.md)、[多 App 实测结果](./plans/20261014-cross-app-results.md)、[脱敏摘要](./plans/20261014-cross-app-summary.json)。
- [实测报告与证据边界](./plans/20261014-lab-results.md)、[脱敏机器可读结果](./plans/20261014-lab-summary.json)；实验、仓库与文档门禁，不创建提交或远端写入。
- 实验代码：独立 `Examples/ResidentRunnerResearch/`，仅服务本期机制验证，不进入根 SwiftPM 或发布产物。BDD：身份鉴权、有界协议、真实 UI 查询/截图、单次 counter tap 后置断言、连续健康与停止、冷启动与失效分类。

## 研究裁决

- 第一阶段：Mac 管理 XCTest 会话，独立 Runner provider，先 health/AX/截图，再公共 XCTest tap 与显式后置断言。
- 预装冷启动、锁屏、断 USB、设备重启与手机端 DDI 准备分别验收；RunLoop 不能证明永久后台运行。
- iCTRL 的图标冷启动依赖 Apple Runner 黑盒；当前 re-kick 实际已禁用，不能复制旧注释中的恢复方案。
- Appium 固定版本资料显示 iOS 27+ 的 devicectl 预装启动 fallback 已禁用，启动模式与 OS/Xcode 必须独立建矩阵。
- 现有专门平台的一次性 Runner、embedded transport、可选 Simulator lease 不能直接充当通用真机常驻方案。

## 验证记录

- `triton 0.2.26` 的只读 version/status/doctor/capabilities/schema xcode/plan 事实已私有保存；不代表 Runner 可用。
- 匹配门禁：41 条独立单测、两次真实 testServe、`verify.sh --local`（根264tests/34suites）、`--ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 通过。
- Simulator testServe 231.804 秒通过；有线 iPhone testServe 195.316 秒通过；UI 查询、截图、单次 tap、重复去重、health 和 stop 已证实。真机第一次因 UI automation 初始化超时失败，解锁后新会话成功，保留失败证据。
- 追加多 App 实验：52 条独立单测通过；Calculator 7+8=15 与重复请求去重、Settings 滚动/General/返回、fixture AX 状态保留通过。Safari 启动/查询通过，输入返回 cross_app_focus；最后全屏截图为 App Switcher，不能当 fixture 画面验证。最终 testServe 179.109s、零失败、exit0，正常 stop。
- 研究保留在独立 worktree，尚未合入 main，也未创建提交或远端写入。

## 非目标

- 本期不承诺零电脑首次设置、越过签名/配对/用户授权、开机自启或永久后台存活。
- 不将 XCTest/私有 API 放入 embedded SwiftPM 根包。
- 不新增 Web/Wails 控制面、云设备或对外 LAN 控制产品。
- 不复制 iCTRL 自定义密码协议，不读取私钥/配对文件或修改系统开发设置；签名仅使用本机有效 identity 和证书公开 OU，采用 Xcode 自动 provisioning。

## 并行登记说明

收尾发现主工作区另一项可行性研究已登记 SP-192，本项改登记 SP-193。此 worktree 保留 SP-192 的只读文档快照供编号连续性，未修改它的主工作区内容，也不采用它的设备探针作为本项验证。未来集成需保留既有 memory 段落并追加本项研究记录。
