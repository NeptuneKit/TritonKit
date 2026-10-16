# SP-200 — Mobile 设备能力补齐与统一发布

## 需求、授权与边界

- 2026-10-15用户明确要求：Mobile MCP 差距表除云设备预订/释放、标准MCP接入外，其他全部支持；授权创建space、实现、验证、提交、合并和上线。
- 影响CLI、共享host契约、既有HTTP机器入口、内置iOS Runner、终端镜像、public skills和发布包；Web/Wails维持既有只读边界。
- 基线 `main@5952fc6a`（包含SP-199参考档案）；branch `feat/SP-200-mobile-device-parity`；worktree `../TritonKit-worktrees/SP-200-mobile-device-parity/`。既有SP-194/SP-196工作区不修改。
- 排除云fleet、远端预订、MCP server、Appium/WDA依赖、业务App强制SDK、正式Web写控制面。终端镜像通过CLI动作，不另造业务执行器。
- 状态：实现与验证完成，待主线合并及 v0.2.29 发布。功能不可只提供 plan 或恒定 unsupported 替代实现；平台固有不支持已纳入能力矩阵与证据。

## BDD与验收

1. Given明确本机target，When读取/设置orientation、fold、location、clipboard，Then输出单一JSON、target/source/执行状态，保留原值和能力边界；覆盖Android Emulator及可用iOS路径，硬件不具备折叠能力明确失败。
2. Given录屏start返回，When执行其他CLI动作后stop，Then生成实际可播放媒体、会话身份绑定、status可查询；重复start/不同target/旧PID/路径覆盖/timeout不得误报成功。
3. Given设备日志或crash，When bounded logs / crashes list/get，Then有来源、字节/时间预算、私有artifact与partial错误；metadata不冒充报告正文。
4. GivenApp归档，When安装ZIP/IPA，Then安全解包并选择唯一目标平台可安装App；拒绝路径逃逸、symlink、炸弹/多候选，原APK/HAP/.app不回归。
5. Given最新观察与目标，When double-tap、Runner coordinate/press、foreground query，Then检查坐标/geometry/白名单和requestID，串行执行并以观察或业务后置条件证明；unknown不自动重发。
6. Givenkitty/Ghostty终端，When打开mirror，Then截图刷新、坐标换算、键盘/Home/Back操作使用既有CLI/HTTP；退出恢复终端与清理自有资源；非兼容终端明确报错并提供可用替代。
7. Given所有切片集成，When发布下一patch，ThenCLI双架构、Runner/Web/public skills、checksum、GitHubRelease与Homebrew同版；安装后repo外运行新命令验证。不得以fixture、编译或上游声明代替真实通过。

## 分工与文件所有权

- 主控：登记/索引、总契约入口接线（Device/App/act/Runner注册、commandSchemas/capabilities/HTTP）、集成构建与全部真实设备动作、完整测试、docs/skills、提交/合并/push/tag/release。
- Environment：新`CLIDeviceEnvironment*`与专用测试，orientation/fold/location/clipboard/foreground；不得修改Device根注册/全局schema。
- Recording：新`CLIDeviceRecording*`与专用测试，start/status/stop持久会话；不得修改Environment/Device根。
- Diagnostics/Install：新`CLIDeviceDiagnostics*`、`CLIAppArchive*`与专用测试；必要App.install调用点提交主控接线补丁。
- Actions/Runner：专用action文件及Runner协议/资源/hostclient；负责coordinate/press/double-tap，Runner现有资源文件独占；不改Environment。
- Terminal：新`CLIDeviceMirror*`与专用测试；消费统一CLI契约，不操作真实设备。
- 多agent在同一隔离feature worktree按文件面并行；每个agent先失败测试、后最小实现；禁止提交/推送/设备操作，测试仅主控调度。

## 证据与交付

源调研：[SP-199](../SP-199-mobile-mcp-reference/README.md)；[正式参考档案](../../dev/mobile-mcp-reference.md)。当前验收日志与机器输出默认保留私有，不将设备身份、日志正文、截图或签名信息提交。分阶段结果写`plans/`，每日与长期memory收口。适用测试、local门禁、HTTP/终端/真实设备证据齐备再发布；原平台系统限制需单列，不许改产品最小版本换验证绿色。

## 收口记录

实现、focused tests、Android Emulator 与 iOS Simulator 回归证据见 [实现说明](../../dev/20261015-mobile-device-parity.md)。云设备预订/释放和标准 MCP server 按用户授权明确排除。

## 2026-10-16 工作区收口

已核对本期产品实现进入本地 main，原 worktree 与本地 feature 分支已清理。原始验证日志、历史未提交副本已保存至仓库外私有归档；本次清理不改变发布与真实设备验收边界。详见[本地 worktree 与分支收口](../../dev/20261016-worktree-closeout.md)。
