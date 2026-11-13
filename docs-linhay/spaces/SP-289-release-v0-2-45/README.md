# SP-289 — v0.2.45 整体发布

## 授权、基线与状态

- 用户于2026-11-13明确要求“提交、推送、发布”；在当前main串行执行，不创建branch/worktree。
- 开工HEAD：`f0a5593f`；工作区干净，远端main `607410fb` 为祖先，当前9条未推送提交。远端最新稳定版v0.2.44，v0.2.45本地/远端均未占用。
- 本次按当前arm64-only完整契约发布CLI、bundled Web/unsigned Runner、public skills、checksum、Homebrew和同tag SwiftPM（iOS16+）。不发布已退休x86_64/CocoaPods。
- 范围包含SP-283公开资产校验、SP-284只读资源依赖诊断、SP-285 Android尺寸解析、SP-286原始业务数据、SP-287功能图及SP-288 skills补齐；SP-281仅已交付回执/证据基础，不宣称P2/所有host throw/Sim HID/统一owner完成。
- 不以发版重启/停止其他任务的serve、设备、App或模型；Homebrew升级前核对实际旧服务与Cellar路径，必要时保留旧版资源。

## BDD 与验收边界

1. Given v0.2.44版本清单，When 校验目标0.2.45，Then 先保留失败，再只更新Web两份manifest，CI负责CLI/skills/Runner版本戳；SwiftPM沿tag、不新增Package版本字段。
2. Given 精确候选main SHA，When 发布tag，Then 本地完整门禁与准确SHA完整main CI先通过，工作区/远端同步、无已有tag；不能用tag contracts代替main CI。
3. Given 公开发布完成，When 重取资产，Then 完整下载后验证arm64/Web/Runner/skills/checksum版本与内容；所有Release jobs/tap成功，现有tag不移动。
4. Given Homebrew安装版，When 从仓外启动隔离packaged Web，Then 先mode=packaged/readonly=true，验证HTML/JS/CSS/registry及完整gesture DTO的405拒绝，并完成真实浏览器检查；不把工作台代替所有三平台流/业务操作验收。
5. Given 结果归档，When 收口，Then 更新space/索引/memory，docs-only提交与push后确认该SHA CI；日志/资产/安装/浏览器事实分别标明范围和unknown。

## 环境与验证计划

- 本机Swift6.4；默认Node25不在Web声明支持范围，采用现有Node24.21.0，不升级全局工具或依赖。
- 原生Sources/Tests冻结后串行运行 `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`、完整CLI测试（绑定本次CLI）、Web完整测试及构建、版本/发布/public skill门禁。
- 本轮不新增真实设备/用户App/模型行为验收；额外Xcode Simulator构建明确跳过。iOS16+按当前Package声明沿tag分发；本地/准确候选CI只证明实际执行的编译与测试，不宣称UIKit或iOS16真机行为验收。
- 当前状态：准备发布，尚未推送/打tag/公开发布。过程证据置于plans，最终结果以[发布验收](./plans/20261113-release.md)及远端回读为准。
