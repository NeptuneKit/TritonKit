# SP-154 Issue #174 Simulator Swipe Lifecycle

## 状态

- 状态：已完成（总集成候选，待 PR/CI）
- GitHub issue：[#174](https://github.com/NeptuneKit/TritonKit/issues/174)
- Branch：`feat/SP-154-issue-174-simulator-swipe-lifecycle`
- Worktree：`../TritonKit-worktrees/SP-154-issue-174-simulator-swipe-lifecycle/`
- 基线：`d2578089`

## 影响层与边界

本切片只修复 CLI Web bridge 的 `/web/host-input` 在 iOS Simulator 上提交 swipe 时缺少可靠 terminal touch phase 的问题。实现范围限定为 `CLIWebDeviceRuntime` 的 iOS host-HID command builder/runner 与 focused tests；HTTP route 继续复用既有 payload、target resolution 和 response envelope。

非目标：

- 不修改 Web React UI 或浏览器生成的 swipe payload，除非测试证明 payload 本身错误。
- 不修改 embedded runtime、`CLIXcode*`、devicectl parser、Android/Harmony host adapter。
- 不把 host action 的 `ok=true` 宣称为业务完成；它仍只表示底层输入已提交。
- 不依赖私有 Baguette API 作为产品契约，也不新增远端、真机或 release 工作。

## 根因结论

现有 iOS host swipe 只启动一次性 Baguette `swipe` 子命令。Baguette 的 HID send completion 只证明事件已入队；当前 Web bridge 又只等待子进程退出，因此一次性进程可能在 terminal `touch1-up` 真正送达 UIKit 前结束。`UIPageViewController` 随后保留未终止的 interactive transition，形成成功响应但页面停在两页之间的假成功。直接 TTY 调用偶尔可用，是进程与管道时序掩盖了该竞态，并非两条路径的坐标契约不同。

## 实现裁决

- iOS Simulator swipe 改用一个长驻的 `baguette input --udid <UDID>` 会话。
- 在同一进程内按 duration 节奏发送 `touch1-down`、10 个插值 `touch1-move` 与 terminal `touch1-up`；每个事件收到 `ok=true` 确认后才推进。
- terminal up 确认后继续保活至少 100ms，再关闭 stdin，使已入队终态有时间送达 UIKit。
- 缺少任一确认（尤其 terminal up）均失败关闭，不再把子进程退出误判为完整 swipe。
- tap 与 long press 保持既有一次性 argv；Android/Harmony 分流未修改。host success message 明示仍需 AX、wait 或 screenshot 验证业务 settled 状态。

## BDD 验收

### 场景一：iOS Simulator swipe 提交完整生命周期

- Given `/web/host-input` 收到 iOS Simulator swipe，包含 start/end、duration、width 与 height
- When host adapter 构造并执行底层命令
- Then fake runner 观察到按顺序提交 down、move、up 三个阶段
- And start/end、duration 与 viewport 坐标被完整保留
- And terminal phase 即使正常 move 已结束也明确存在

### 场景二：vertical pager 不再遗留未终止交互

- Given 一个对 terminal touch phase 敏感的 vertical pager fixture
- When 相同 swipe 通过 iOS host adapter 提交
- Then lifecycle fixture 收到 terminal up，状态从 interactive 转为 settled
- And 不允许仅有 down/move 的命令序列通过测试

### 场景三：long press 语义保持

- Given `/web/host-input` 收到 iOS Simulator longPress
- When host adapter 构造底层命令
- Then 仍以同起止点和请求 duration 提交 hold
- And 不被 swipe 的多阶段 terminal 逻辑改写

### 场景四：平台分流与结果语义不回归

- Given tap、Android swipe 或 Harmony swipe 请求
- When 经过现有 Web host-input 分流
- Then 原有 command argv 与成功结果保持不变
- And iOS swipe success message 只声明 host action 已提交，后续仍需 AX/wait/screenshot 验证页面 settled

## TDD 与验证计划

1. 在 `SingleDeviceWebPageTests` / bridge focused tests 中先新增 lifecycle 与 vertical pager stuck fixture，确认旧实现 red。
2. 最小修改 iOS Simulator swipe command builder/runner，显式提交 terminal up；保留 long press、tap 与跨平台分流。
3. 依次运行 focused suite、相关 CLI suite、Swift tests、CLI build、文档检查与 `git diff --check`。
4. 真实 Simulator smoke 仅在 Triton-first 事实、独占 target/server 与安全后验验证均满足时运行；否则如实保留为环境风险。

## 停止条件

- 修复只能依赖无稳定契约的私有 Baguette/API。
- 必须修改本 issue 禁止或其他 issue 所有的文件面。
- 同一环境或契约原因连续失败三次且无新的安全诊断路径。

## TDD 与验证结果

- Red：先加入生命周期 builder/runner 测试；旧实现因不存在 persistent lifecycle 接口而编译失败。
- Green：`SingleDeviceWebPageTests` 30/30；假 Baguette 记录恰好一个 PID、完整 down/move/up 事件，且 runner 耗时覆盖 `duration + terminalLinger`。
- 相关回归：`DeviceCrossPlatformTests` 96/96。
- CLI 全量：781 tests 被仓库既有测试运行器约束阻断；独立 scratch 下多数 CLI 子进程用例找不到测试约定位置中的 `triton`，另有 1 个既有 Xcode streaming timeout。改动相关 focused suites 全绿，失败不落在本 space 文件面。
- 未运行真实 Simulator smoke：并行 issue 工作共享本机设备与服务，未取得独占 target/server；按治理边界保留为合入后的 Triton-first 后验验收项。
