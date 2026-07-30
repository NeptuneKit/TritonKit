# SP-155 Issue 175 iOS Readiness CoreDevice

## 状态

- GitHub issue：#175
- Branch：`feat/SP-155-issue-175-ios-readiness-coredevice`
- Worktree：`../TritonKit-worktrees/SP-155-issue-175-ios-readiness-coredevice/`
- 阶段：已完成（本地，待主控按 SP-142～155 顺序集成）
- 基线：`d2578089`

## 问题与根因假设

Xcode 26.5/CoreDevice 可以把已配对、当前可用于惰性 service activation 的真机显示为 `available (paired)`，同时稳定 JSON 仍可能带有未建立 tunnel、DDI service 尚未激活的快照字段。现有 parser 把 `tunnelState=disconnected` 和 `ddiServicesAvailable=false` 各自直接提升为 `offline` / `ddi-missing`，导致 `device list`、`wait-ready` 与 app selector 在 CoreDevice 真正尝试安装前错误拒绝目标。

本切片只修复 iOS real-device discovery/readiness 事实归一。底层仍仅消费 `devicectl --json-output <fresh-path>`，不解析 stdout，不自行建立 tunnel，不执行真实安装。

## 影响层与边界

影响层：

1. `TritonKitShared` 的 devicectl list JSON parser 与脱敏 target DTO。
2. CLI iOS real-device list / resolve / wait-ready，以及复用同一 selector 的 app install 前置事实。
3. 对应 shared / CLI fixture tests 与文档路由。

不包含：

1. Android/Harmony adapter。
2. app lifecycle command builder 或真实 install/launch/open-url。
3. `CLIXcode*`、embedded runtime、Web host input、签名资产。
4. 系统级 HID、SpringBoard 自动化、远端真机或设备云。

## BDD

### 场景一：CoreDevice available paired 可惰性激活

- Given 脱敏的 Xcode/CoreDevice list JSON 中设备可见且 paired/trusted、Developer Mode enabled、unlocked
- And tunnel 尚未建立、DDI service 快照为 false
- When Triton 解析 iOS real-device target
- Then target 为 `scope=real`、`kind=real-device`、`source=devicectl`
- And `state=connected`、`ready=true`、`blockedReasons=[]`
- And stable id 仍为脱敏 `ios-real:<hash>`
- And list、wait-ready 与 app selector 看到同一 eligible target 事实

### 场景二：明确不可用状态继续 fail closed

- Given JSON 明确报告 `visibilityClass=offline|unavailable`、unpaired/not trusted、locked 或 Developer Mode disabled
- When Triton 解析并选择 target
- Then `ready=false`
- And 分别保留 `offline`、`not-trusted`、`locked`、`developer-mode-required`

### 场景三：明确 DDI 缺失继续 fail closed

- Given JSON 提供显式 DDI missing/unavailable 状态或 error
- When Triton 解析 target
- Then `ready=false`
- And `blockedReasons` 包含 `ddi-missing`
- But 单独的尚未激活 service/mount 布尔快照不得等价为显式 DDI 缺失

### 场景四：JSON 合同与隐私不回归

- Given `devicectl list devices`
- Then Triton 仍要求 fresh `--json-output` 与 `--log-output`
- And malformed/missing devices JSON 保持稳定 parser error
- And 公开 target 不编码 raw CoreDevice identifier、UDID 或 serial

## 验收

1. 脱敏 fixtures 覆盖 Xcode/CoreDevice available-paired、明确 offline、unpaired/not trusted、locked、Developer Mode 与显式 DDI missing 变体。
2. parser 先红后绿；selection 证明 available-paired target 能通过 `ready=true` 过滤并生成使用 raw identity 的 install plan，而公开 target/sourceCommand 仍脱敏。
3. focused shared / CLI tests、完整 root Swift tests、CLI tests/build、文档门禁与 `git diff --check` 通过，或记录与本改动无关的既有 blocker。
4. 不执行真实设备 install/tunnel；真实 smoke 记录为环境/授权边界 skipped。

## 停止条件

1. 只有真实安装或隧道副作用才能决定合同。
2. 修复需要修改 app lifecycle、Xcode、Android/Harmony 或签名配置。
3. 同一原因连续失败三次且无法继续缩小问题。

## 实现结论

1. readiness 不再把 paired/trusted、未显式离线的设备所携带的 `tunnelState=disconnected` 当作离线；该状态可由 CoreDevice 在具体动作时惰性激活。
2. `ddiServicesAvailable=false` / `developerDiskImageMounted=false` 仅在上述惰性激活资格成立时视为尚未激活的快照；显式 DDI missing/unavailable 状态或 error 仍 fail closed。
3. explicit offline/unavailable、unpaired/not trusted、locked、Developer Mode disabled 均继续产生稳定 blocker。
4. CLI fixture 证明 parser 产出的同一个 ready target 可通过 selector，并进入既有 iOS install plan；执行 argv 使用 raw CoreDevice identifier，公开 target 与 source command 继续脱敏。

## 验证证据

1. RED：shared parser fixture 起初得到 `state=offline`、`ready=false`、`blockedReasons=[offline,ddi-missing]`；CLI ready selector 起初返回 `target_not_found`。
2. GREEN：`TKHostAdapterModelsTests` 40 项通过；覆盖 available-paired 与 explicit offline、unpaired、locked、Developer Mode disabled、DDI missing、malformed/missing JSON。
3. GREEN：`DeviceCrossPlatformTests` 97 项、`FailureDiagnosticsTests` 13 项、`AppOpenURLFlowTests` 7 项通过；available-paired selection/install plan 专项通过。
4. GREEN：root `swift test --scratch-path .build/sp155-shared` 235 项通过；`swift build --package-path CLI --scratch-path .build/sp155-cli --product triton` 通过；`git diff --check` 通过。
5. CLI 全量独立 scratch 回归暴露与本改动无关的既有/基础设施问题：部分测试硬编码 `CLI/.build`、testrec 基线 target 状态不一致、并发 proxy 用例波动；相关聚焦套件通过后，长时间无输出的残余进程已中止。
6. `check-docs.sh` 在此独立 worktree 因尚未集成 SP-142～154 而报告 SP 编号不连续；SP-155 必须由主控按序集成后重跑文档门禁。
7. 未执行真实 iPhone/iPad install、tunnel 或 DDI activation；真实 smoke 按授权与环境边界 skipped。
