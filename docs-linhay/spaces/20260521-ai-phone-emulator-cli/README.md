# 20260521 ai-phone Emulator CLI

## 结论

重新校准边界：TritonKit 当前做 **本机 CLI + 本机模拟器/仿真器**，不是只做 Apple Simulator。

纳入范围：

- iOS Simulator
- Android Emulator
- HarmonyOS / DevEco Emulator
- 业务 App 内 embedded runtime
- 本机 `.tritonevidence` / `.tritonplan` / `.tritoncase` / `.tritonbatch`

排除范围：

- 真实 iOS / Android / Harmony 设备
- 远端 agent
- 中心 Server / 设备云
- Web / Wails UI
- Postgres / Kafka / Webhook / 运维大盘
- 内置 VLM loop

这个边界比“只做 Apple Simulator”稍复杂，但仍远低于 ai-phone 的三端真机中台。好处是：我们可以覆盖三端本机 emulator 的主要准备、执行、证据和回归链路，同时避免真机和分布式系统带来的高复杂度。

## 参考

- ai-phone GitHub：`https://github.com/dongxinsuperman/ai-phone`
- ai-phone 参考归档：`docs-linhay/references/ai-phone.md`
- Simulator takeover：`docs-linhay/spaces/20260520-simulator-takeover/README.md`
- Harmony Emulator alignment：`docs-linhay/spaces/20260520-harmony-emulator-alignment/README.md`
- Harness UX run evidence：`docs-linhay/spaces/20260521-harness-ux-run-evidence/README.md`
- AI CLI 契约：`docs-linhay/dev/ai-cli-readable-control.md`

## 新边界

### 只做 CLI

对外产品入口只有 `triton ... --json` / `--jsonl`。`triton serve` 可以作为本机 runtime bridge，但不作为对外 HTTP 产品。

### 只做本机模拟器/仿真器

每个平台只接本机 emulator/simulator：

| 平台 | 本机目标 | 底层工具 |
| --- | --- | --- |
| iOS | Apple Simulator | `xcrun simctl`、container、plist、host screenshot |
| Android | Android Emulator | `adb`、`emu` console、`uiautomator` / screenshot、logcat |
| Harmony | DevEco Emulator / HVD | `hdc`、DevEco Emulator、`uitest`、`aa`、`bm`、`hilog` |

不做真机 USB 授权、WDA、scrcpy 生产链路、hypium 真机链路或跨机器 agent。

### 不做 Web

不做 Web 工作台、队列页、设备大盘、报告大盘、审批流。证据和报告先是本地目录或静态文件，由 CLI 输出路径和摘要。

## 为什么功能仍然可以更多

只做本机模拟器/仿真器后，复杂度主要来自各平台 CLI 差异，但都能通过本机 process runner 收敛。相比真机中台，少了这些高风险问题：

- 真机 USB 信任、解锁、pairing、开发者模式。
- 多办公室接机、远端 agent 心跳、路由、鉴权。
- 分布式设备池、全局锁、中心队列。
- Web 运维大盘、Kafka/Webhook、Postgres。
- 三端真机镜像流和长期 driver 生命周期。

因此 P0/P1 可以做更多“agent 真的会用”的本机 CLI：

| 能力域 | 可做能力 |
| --- | --- |
| Target lifecycle | list/use/boot/shutdown/wait-ready |
| App lifecycle | install/uninstall/launch/terminate/open-url |
| App data | container、prefs、清数据、`.xcappdata` / Android data / Harmony app info |
| Environment | iOS privacy/location/status bar、Android permission/settings、Harmony boot readiness |
| Artifacts | screenshot、logs、layout/AX、diagnose bundle |
| Runtime actions | ax/find/tap/type/wait/assert |
| Evidence | command ledger、run events、manifest、artifact summary |
| Replay | `.tritonplan`、checkpoint、final assert |

## CLI 进入决策

### 必须进 CLI

| 能力 | CLI 形态 |
| --- | --- |
| 能力发现 | `triton schema/doctor/capabilities/plan --json` |
| 本机 target 发现 | `triton device list/use --platform ios|android|harmony --json` |
| 等待可操作 | `triton device wait-ready --platform ... --jsonl` |
| iOS Simulator | `triton sim list/use/boot/shutdown/screenshot/privacy/location/ui --json` |
| Android Emulator | `triton device list/use/wait-ready --platform android --json`、`triton app install/launch/terminate --platform android --json` |
| Harmony Emulator | `triton device doctor/list/use/wait-ready --platform harmony --json`、`triton app inspect/launch --platform harmony --json` |
| App 生命周期 | `triton app list/info/install/uninstall/launch/terminate/open-url --platform ... --json` |
| App 数据 | `triton app container/prefs/data --platform ... --json`，按平台能力返回 unsupported |
| 截图 / UI 树 | `triton screenshot/ax --platform ... --json` |
| Runtime 动作 | `triton find/tap/swipe/type/paste/clear/wait/assert --json` |
| Plan / replay | `triton record/plan inspect/replay --json` |
| Evidence | `triton capture/evidence/evidence inspect/evidence commands --json` |
| Case lint / local batch | `triton case lint`、`triton run submit --file` |

### Issue #14：坐标 tap 的非 UIControl 编辑 surface

- Given 当前 App 页面存在富文本编辑器、WebView-backed editor 或自定义 UIKit 编辑 surface
- And 坐标命中对象不是 `UIControl`，但 view 或其父链可成为 first responder / 符合 `UIKeyInput`
- When agent 执行 `triton tap --at 70,135 --json`
- Then embedded runtime 应聚焦该编辑 surface 并返回 `ok=true`
- And 后续 `triton type <text>` / `triton paste <text>` 可写入当前 first responder
- And 普通未知 `UIControl` 仍不得伪成功；没有 public target-action 或 text input responder 时继续返回明确失败

### Issue #15：Harmony host-side smoke adapter

- Given 本机存在一个 `hdc list targets -v` 可见且 Connected 的 DevEco / Harmony emulator target
- When agent 执行 `triton app install --platform harmony --hap <debug-signed.hap> --json`
- Then TritonKit 通过 `hdc -t <target> install -r <hap>` 安装 HAP
- And JSON 输出保留 action、runtimeScope、target、sourceCommand 与后续验证提示

- Given 已知 Harmony bundle、ability 与 deep link URL
- When agent 执行 `triton app open-url --platform harmony <url> --bundle <bundle> --ability EntryAbility --json`
- Then TritonKit 通过 `aa start -a EntryAbility -b <bundle> -U <url>` 发起深链
- And 不把 host 命令成功误当作业务状态成功，提示继续使用 `wait`、`ax` 或 `screenshot` 验证

- Given 当前页面有可通过 `uitest dumpLayout` 发现的语义文本
- When agent 执行 `triton ax --platform harmony --output <path> --json`
- Then TritonKit 执行 `uitest dumpLayout`、解析 `DumpLayout saved to:<remote>`、再 `file recv` 到本地 artifact
- And JSON 输出返回本地 layout artifact 路径与 sourceCommand，不内联真实业务页面内容

- Given layout 中存在 `.attributes.text == <text>` 且 `.attributes.bounds` 为 `[x1,y1][x2,y2]`
- When agent 执行 `triton tap <text> --platform harmony --json`
- Then TritonKit 计算 bounds 中心并通过 `uitest uiInput click <x> <y>` 点击
- And `triton wait --platform harmony --text <text> --timeout <seconds> --json` 可轮询 layout，超时时返回机器可读失败

- Given 需要 CI 截图证据
- When agent 执行 `triton screenshot --platform harmony --output smoke.jpeg --json`
- Then TritonKit 通过 `snapshot_display -f <remote.jpeg>` 截图并 `file recv` 到本地
- And JSON 输出只返回 artifact 路径、target、sourceCommand 与 redaction 提示

### 可以进 CLI，但非 P0

| 能力 | 决策 |
| --- | --- |
| Android emulator console 深度控制 | P2/P3，只做 bounded 能力 |
| Android logcat / bugreport | P2/P3，诊断模式 |
| Harmony hilog / hidumper | P2/P3，bounded collection |
| iOS xctrace / crash 深度采集 | P2/P3，诊断模式 |
| `.xcappdata` / Android data snapshot / Harmony sandbox snapshot | P2/P3，写入动作带 destructive metadata |
| 三端统一 local batch fan-out | P2，仍是本机顺序或有限并发，不做中心队列 |

### 不进当前方向

| 能力 | 决策 |
| --- | --- |
| Remote agent | 不做 |
| 真实设备 | 不做这条线 |
| Web / Wails UI | 不做 |
| HTTP 对外 API | 不做产品面 |
| Postgres / Kafka / Webhook | 不做 |
| 多租户 / 权限 / 大盘 | 不做 |
| 内置 VLM loop | 不做 |
| V2/V3 轨迹自动重定位 | 不做首期 |
| 系统安全绕过 | 不承诺 |

## 分期

### P0：iOS Simulator Core + 跨平台 target envelope

- iOS: `sim list/use/boot/shutdown/wait-ready/screenshot`
- iOS: `app list/info/install/uninstall/launch/terminate/open-url/container/prefs get/dump`
- 跨平台 `device list/use/wait-ready` DTO 先覆盖 iOS/Harmony 已有能力，Android 留 adapter slot。
- 所有命令 JSON/JSONL，稳定 error code。
- 所有 host action 可写 command ledger。

### P1：Harmony Emulator Core

- Harmony: `device doctor/list/use/wait-ready/stop`、`app inspect/launch`、`ax/screenshot`。
- 三端 command ledger schema 先保持可容纳 Android，但 Android adapter 可以后续接入。

### P2：Environment + Evidence

- iOS: privacy/location/appearance/status-bar。
- Harmony: hilog bounded collection、uitest layout/screenCap。
- `capture/evidence` 纳入 host artifacts 和 command ledger。

### P3：Android Emulator + Fixtures + Replay Safety

- Android: `device list/use/wait-ready`、`app install/launch/terminate`、`screenshot/logs`。
- iOS media/contacts/pasteboard/push。
- Android intent/deeplink、test data、bounded bugreport。
- Harmony aa/bm/hilog/hidumper 诊断包。
- `.tritonplan` checkpoint。
- `case lint` 和本地 `.tritonbatch`。

## 验收场景

### 场景一：三端本机 target 可发现

- Given 本机存在 iOS Simulator、Android Emulator 或 Harmony Emulator
- When 执行 `triton device list --platform <platform> --json`
- Then 输出统一 target DTO
- And 不要求真实设备或远端 agent

### 场景二：动作进入本地 command ledger

- Given agent 执行 `triton app launch --platform <platform>`
- When 命令完成
- Then evidence 中记录 target、method、source command、elapsed、ok/error
- And result 明确下一步应验证业务状态

### 场景三：平台能力差异稳定表达

- Given 某平台不支持某个能力
- When agent 调用对应 CLI
- Then 返回 `unsupported_capability`
- And 给出可用替代或 nextAction

### 场景四：动作结果和业务结果分离

- Given host 命令或 runtime tap 返回 ok
- When 后续没有 `wait/assert/screenshot/evidence`
- Then evidence 写入 `unverified_host_action` 或 `unverified_runtime_action` warning

### 场景五：Harmony Emulator stop 不被 Triton launchd keepalive 拉起

- Given TritonKit 通过 `triton-harmony-emulator` launchd job 启动并监督 Harmony Emulator
- When agent 执行 `triton device stop --platform harmony --hvd <name> --path <deployed-path> --confirm --json`
- Then TritonKit 先对 `gui/<uid>/triton-harmony-emulator` 执行 launchd 检查与 `bootout`
- And 随后执行 DevEco `Emulator -stop <name> -path <deployed-path>`
- And JSON 输出包含 `sourceCommands`、launchd label/domain、HVD 名称与下一步验证建议
- And `Emulator -stop` 成功后不会因为 TritonKit 自己的 keepalive job 自动重启

## 完成定义

1. 文档明确当前只做 CLI、单机模拟器/仿真器、无 Web、无真机。
2. ai-phone 能力已筛选为本机 emulator CLI 能力。
3. P0/P1 可以直接拆成命令 schema、模型测试和 CLI 实现。
