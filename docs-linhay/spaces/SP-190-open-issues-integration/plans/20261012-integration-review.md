# 2026-10-12 线上 issues 本地集成评审

## 范围与交付状态

初始、增量与提交前线上队列均为 #214–#220；本轮没有远端写入或关闭 issue。所有改动在 `feat/SP-190-open-issues-integration`，主工作区不变。影响 CLI、host adapter、shared schema 和文档；无新增 Web/HTTP 控制面，无版本发布。

| Issue | 本地结果 | 保留边界 |
| --- | --- | --- |
| #214 | 精确 DerivedData 根目录检查、只读统计/mtime 修复；confirm 在删除前明确拒绝 | 安全止损，未完成排他/竞态删除协议；保持 OPEN |
| #215 | 离线 `sim swipe`，复用 host HID 生命周期与坐标归一化；无需 embedded server | 自动测试验证命令与进程生命周期，真实 swipe/pager 未验证 |
| #216 | type 的 help/schema/capabilities 一致标为 unsupported；说明剪贴板与真正输入的区别 | 没有新增键盘 primitive，不把 pasteboard staging 当作字段或业务成功 |
| #217 | run 构建失败非零退出，JSON/JSONL 单一 final，停止后续安装/启动 | 真实 CLI 子进程 + fake xcodebuild 验证；未运行私有 App |
| #218 | 所选工具链/设备独立 HID 兼容性报告；实际 tap/swipe bootstrap 分类与诊断脱敏 | 框架 class 可见只代表兼容性，available/inputDispatchVerified 保持 false；未实现未知现代私有 ABI |
| #219 | 显式 iPhoneOS SDK + generic iOS destination 允许仅 build；保留 run/test/明确设备保护 | 无真实 SDK 编译、安装或启动验证 |
| #220 | package-relative xcresult 与 DerivedData 路径按执行工作目录统一 | 夹具实际落盘并贯通 inline parser/计数；非真实 Xcode test |

## 测试与集成修正

- 完整 CLI：`TRITON_CLI_PATH=<built-triton> swift test --package-path CLI --no-parallel -j 4`，1189 tests / 108 suites 与 26 XCTest 全通过。
- 分项 focused 证据保留在 SP-179、SP-184～189 的 README；分项数量不能相加当作独立新增测试总数。
- 首轮完整回归发现 public skill 命令快照未登记 swipe、能力状态机尚未包含 host type 的明确 unsupported 边界；同步快照并增加三种连接状态始终 unsupported 的精确断言，完整重跑通过。
- 交叉审查修复 xcode 父/嵌套 schema 的 cleanup failureCodes/failureShape，以及 tap/swipe 的实际 TKInputResult 输出合同、bootstrap 错误码。
- 文档门禁 `verify.sh --ci-docs` 通过，space 登记 190/190；首次重复 SP190 路线链接已修复。
- 完整本地门禁通过：根包 264 + 50 Swift Testing、7 XCTest、Release CLI 构建与 CLI/Harmony host/iOS runtime observe smoke 通过。仅 CLI/host 变更，`TRITON_VERIFY_XCODE=0` 跳过可选 iOS Simulator SDK build；不把此门禁当作实际 Simulator 输入或真实 iOS SDK 编译证据。

- 文件规模检查发现 Xcode runtime 达到 1511 行，将 DerivedData cache metadata helper 移至现有 cache observation runtime，原文件降至 1497 行，保持行为不变并重跑完整 CLI / 本地门禁。

## 本机只读诊断

已保存 status/doctor/capabilities/schema/plan help 与 Simulator inventory 的本机事实。对一个 ready Simulator 运行 selected-device doctor，exit 0；实际所选 Xcode 的 `contents-shared-frameworks` 兼容性检查通过，返回 `ios_host_hid_framework_compatible`，同时明确 `available=false`、`inputDispatchVerified=false`、`verification=framework-compatibility-only`。没有发送输入、变更设备或切换工具链。

公开证据见 [脱敏摘要](20261012-selected-hid-probe.json)，设备标识和本机路径已移除；完整本机原始输出未纳入仓库。

## 远端推进条件

先获得远端写入授权，再推送/创建 PR、等待对应提交的 CI；只关闭满足其声明范围的 issue。#214 保持 OPEN。关闭前如需补充真实 swipe / SDK 编译验收，单独记录实际动作和后置证据。远端归档提交、其 CI 和最终 open 快照完成前，不宣称线上清零。

## 监督审计记录

- Requested：处理当前线上 GitHub issues，逐项隔离实现、验证并保留问题边界。
- Observed：#215～220 的本地实现与声明范围已落地；#214 仅完成安全止损。
- Evidence：各 issue space、完整 CLI / 本地门禁、脱敏 selected-HID probe 和三次 open 队列快照。
- Gaps：#214 仍缺安全删除互斥协议；真实 swipe、真实 SDK-only build 与实际 package Xcode test 未执行。
- Fixes made：父级/嵌套错误码、tap/swipe 输出合同、public skill 命令快照、能力状态机断言、HID 首 ACK 前失败 stderr，以及源文件规模治理。
- Remaining risk：真实工具链与 UI 输入验收缺口仍保留；远端 CI 尚未运行，不能按本地绿色直接宣称线上完成。
