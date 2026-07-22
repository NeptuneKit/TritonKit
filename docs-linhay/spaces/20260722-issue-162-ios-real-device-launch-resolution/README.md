# GitHub Issue #162：iOS Real-Device Launch Resolution

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#162](https://github.com/NeptuneKit/TritonKit/issues/162)
>
> Branch：`feat/20260722-issue-162-ios-real-device-launch-resolution`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-162-ios-real-device-launch-resolution/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。本 issue 明确建立 iOS 真机 app lifecycle 的有限边界，不扩展到远端设备、设备云或 Web 控制面。

## 背景

显式 `ios-real:*` selector 在初始 offline/DDI-missing 状态下可被 `app install` 与 `app info` 动态建立 tunnel 后接受，但 `app launch` 在等价 live-device resolution 前返回 `target_not_found`。

## 范围

- 统一 real-device install/info/launch 对显式 selector 的 live tunnel/readiness 解析语义。
- launch 复用现有受测 resolver/service，不复制一条独立 selector 分支。
- 若 launch 确实需要更严格状态，返回一致、可操作的 readiness error，而不是错误的 `target_not_found`。
- 保持 devicectl argv、环境变量脱敏、sourceCommand 与 app lifecycle schema 契约。

## BDD 场景

### 场景 1：显式 selector 可经 live resolution 启动

- Given paired real device 初始 inventory 为 offline/DDI-missing
- And live resolver 可建立 tunnel 并返回 ready target
- When `app launch` 使用同一显式 selector
- Then 调用 devicectl launch 并返回 resolved target

### 场景 2：install/info/launch 解析一致

- Given 同一 selector 与同一 fake/live inventory sequence
- When 分别执行 install、info、launch
- Then 三者使用相同 target identity 与 readiness transition

### 场景 3：真实不可用时错误可操作

- Given tunnel 建立后仍无法得到 launch-ready device
- When 执行 launch
- Then 返回稳定 readiness/target error 与 next action
- And 不误报已启动或泄漏敏感 selector/environment value

## 验收门禁

- 先补 fake devicectl/resolver 失败测试并确认红灯。
- focused CLI tests、nested CLI full tests、release build 与本地门禁通过。
- 真机动作前保存 `triton status/doctor/capabilities/schema/plan`；只有 Triton 失败/unsupported 后才用 devicectl fallback，并保留脱敏证据。
- 同步 real-device app lifecycle 文档、相关 public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化验证、可用环境下的脱敏真机 smoke、main 集成与线上 CI 全部满足后评论并关闭 #162。
