# SP-214 — Simulator 主显示器路由安全

## 状态与边界

2026-10-20 由参考更新流程评估为可纳入；2026-10-21 已完成实现并合入本地 `main`。影响层为 macOS CLI/HTTP 共用的本机 Simulator AX、host touch 与主屏采集安全门禁；不改 embedded SDK、Web/Wails、真机或远端产品面。

产品基线 `main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`。branch `feat/SP-214-simulator-display-safety`；worktree `../TritonKit-worktrees/SP-214-simulator-display-safety/`。本期独立主控 [SP-215](../SP-215-simulator-display-integration/README.md)。依据 SP-207 既有授权直接开发验证，允许必要本地提交和主控本地 main 合并；不推送或发布。

## 固定来源与实际缺口

来源：[sim-use dc58fe8](https://github.com/lycorp-jp/sim-use/commit/dc58fe8ea2353cde5cb15944eaee16105ad27b4d)；[完整增量](https://github.com/lycorp-jp/sim-use/compare/81c3089331aa0004fc97cd5330e2b32ca79dd6ce...dc58fe8ea2353cde5cb15944eaee16105ad27b4d) 的显示拓扑与路由机制。31 提交、99 变更文件已读取，98 份当前全文、1 removed；原始证据 `.build/reference-monitor/20261020/sim-runtime/lycorp-jp__sim-use/`。固定 LICENSE 全文为 Apache-2.0（GitHub 识别 NOASSERTION）；独立实现机制，复制代码须保留许可、版权和变更通知，外部 idb patch 不继承根许可证授权。

当前 `CLIHostSimulatorAXDriver` 的 `devicePointSize` 使用 mainScreenSize/mainScreenScale，frontmost/hit-test 均固定 displayId=0；`assertIOSSimulatorResizeTouchAllowed` 与 capture gate 只确认 appResize 状态。appResize inactive 不能证明应用位于主显示器。SP-210 校验数值几何、SP-196 拒绝 Resize 均已实现，但尚不覆盖副 integrated display active 的事实。合法尺寸仍可能用于错误显示器，导致错误坐标或错误采集对象。

只采用可验证主屏路由的安全拒绝，不引入 Duo fold/rotate/副屏 HID/AX 路由、不改变默认坐标语义、不升级工具/依赖。上游允许 unknown 回退主屏、永久缓存或关闭安全检查的做法不采用；其性能与跨 Xcode 兼容数字未经本地验证。

## BDD 与验收

- Given appResize inactive 但非 primary integrated display active，When 准备主屏 AX/坐标动作或主屏捕获，Then 在 native submit/输出文件创建/流字节发出之前返回稳定单一失败 envelope，副作用计数为 0。
- Given 完整且绑定精确 target/命令的拓扑，仅一个 primary integrated active，When 现有单屏路径执行，Then 保留合法行为；虚拟 Resizable 的存在不因总屏数大于 1 被误判为 Duo。
- Given 目标不匹配、缺字段、null/布尔伪数字、重复 ID、多个 active、截断、超时或不支持查询，Then 明确 unknown，不丢弃坏条目后推断主屏，不凭版本/机型名称/exit 0 放行。旧 Xcode 兼容保留真实未验边界，不伪造能力证明。
- Given 两次完整动作间切屏或重启，Then 每次动作重新确认，复用旧 display UUID/TTL 不得授权新动作；同一请求遵守现有采集 deadline，不无界叠加查询。
- Given 已有 Resize active/unknown，Then 既有拒绝与错误语义不回归；不依赖坐标的键盘/其他命令保持独立能力边界。

先失败测试，再最小实现。测试使用本 worktree 独立 scratch；离线 parser/DI/fake tool/真实 CLI 进程测试明确区分于真实 Simulator 验收。禁止在本期自动查询/启动/操作设备、切换 Xcode、安装依赖或执行第三方代码。

## 文件面与交付

执行会话拥有本 space、必要新增 `Sources/TritonKitCLI/CLIHostSimulatorDisplay*.swift`、`CLIHostSimulatorAXDriver.swift`、Resize/process/capture 的必要门禁接线及对应 CLI 测试；相关错误/schema/public skill 文档按真实契约最小同步。修改共享代码前确认其他会话未拥有同一文件，不回滚他人工作。主控拥有 SP-215、共享索引/memory/采用登记及整合；执行会话不修改 SP-207 共享状态。

执行输出：精确候选清单和 SHA、红绿测试证据、focused/full CLI 与受影响根包/local 门禁结果、实际错误 envelope、未验边界。不以 fixture 推断设备动作通过。主控独立核对实际 diff 和联合候选，再完成必要本地提交/合并。

所有本项目新执行/主控会话显式指定 `model="gpt-6.1-sol"`，不回退其他模型；创建成功才记真实 thread ID，失败保留待分派，不把 agent 名或 worktree 当作会话成功。

## 2026-10-20 分派结果

必要创建请求显式 `model="gpt-6.1-sol"` 后被桌面接口以 `could not validate model` 拒绝，无真实 thread ID；未开发、未验证、未合并。保留独立工作区供后续仅补缺角色，记录见 [分派证据](../SP-207-reference-adoption-pipeline/plans/20261020-dispatch.json)。

## 2026-10-21 implementation

新增 `CLIHostSimulatorDisplayRuntime.swift`：对精确 target 绑定的 display topology JSON 做离线解析，仅允许唯一 active、primary、integrated display；缺字段、重复 ID、数字伪布尔、多 active、target 不匹配、截断均 unknown。AX/screenshot 接线提供 display probe seam，unknown 在 native action/输出前拒绝，且现有 Resize gate 优先执行。

验证：`swift test --package-path CLI --scratch-path .build/sp214-scratch --no-parallel --filter SimulatorDisplaySafetyTests`；无真实 Simulator、设备操作或依赖安装。完整 CLI、根包及真实 topology 命令验收由主控执行。

## 2026-10-21 完成实现与离线验收

- 已接入真实 `xcrun devicectl device info displayTopology --device <uuid> --json-output ... --log-output ...` 查询；artifact、命令参数回显、目标 UUID、输出上限、超时/unsupported/非零结果均 fail-closed。截图路由与 AX press 默认先确认唯一 active primary integrated display，再执行既有 Resize/AX 几何门禁；测试仍可注入 display probe。
- focused：`swift test --package-path CLI --scratch-path .build/sp214-scratch --no-parallel --filter 'SimulatorDisplaySafetyTests|SimulatorResizeCaptureRoutingTests'`，7 tests passed。未执行真实 Simulator/Xcode display topology，保留该运行验收边界。

### 2026-10-21 real probe接线

新增 `iosSimulatorDisplayTopologyQueryCommand` 与 `probeIOSSimulatorDisplay`，沿用 devicectl file-JSON artifact、超时、非零结果和 unsupported 分支；每次调用 fresh query，严格校验 command echo/target/display 数组。截图与 AX activation 默认使用该 probe，同时保留注入 seam。focused 4 display tests + 3 resize routing tests 通过；无真实设备验收。
