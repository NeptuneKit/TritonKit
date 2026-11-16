# SP-290-issue-283-preference-remove — Issue #283 单键偏好删除

状态：已随 v0.2.46 发布并验证，GitHub #283 已关闭。

## 范围与BDD

CLI app prefs remove；显式Simulator/bundle绑定，仅删除指定key，保留其它plist值；不存在时不创建文件；输出existed/present=false和diskWriteVerified，relaunch与runtime消费分开。

- Given 当前main与初始线上需求，When 完成代码、测试与契约后集中验收，Then 每项分别记录实现、fixture、真实运行和发布证据，不以发行成功替代行为验收。
- Given 失败或未知结果，Then 保留原错误和部分效果，不自动重放写操作。

- Given 单个literal键包含点，When remove，Then 只删除该完整键，不作key-path解释，保留false/0/空串/Data/Date及嵌套值。
- Given 键或plist不存在，Then 不创建或重写plist并返回existed=false/present=false；非法/过大键、malformed/symlink plist在写前拒绝。
- Given 测试 App 已从 UserDefaults 读取临时键，When `remove --relaunch` 成功，Then 先终止该 App，再通过选定 Simulator 的单容器偏好服务删除一个 literal 键，核验偏好域和磁盘，随后重新启动。独立观察新 App 实例读到键缺失，附近的原生类型值保持一致。
- Given 终止失败，Then 不提交删除。若已经核验删除而重新启动失败，Then 单一 JSON 保留删除事实并报 `preferences_relaunch_failed`。App 消费由独立观察验证。
- Given 偏好目录或 plist 包含符号链接，或偏好域和磁盘存在会覆盖旁键的分歧，Then 删除前拒绝。缺失属性域以空字典验证，未创建文件。

## 验收

2026-11-16 候选在自有 iPhone 17 / iOS 27.0 验证点号键按字面删除、旁键 `false` 保留、重复删除 no-op。`remove BatchTemporary --relaunch` 返回 `diskWriteVerified=true`、`relaunch.status=launched`、`runtimeConsumptionVerified=false`，随后 `get` 仍报告键缺失。独立截图在界面稳定后仍读到 `Preference: temporary`，原因未查明。原始公开 fixture 本地证据是 `.build/issue-batch-20261116/takeover-prefs-*`。

首轮静态审查发现原实现只对 plist 末段使用 `O_NOFOLLOW`。新实现逐级检查容器、`Library` 与 `Preferences`，并通过已绑定容器的原生偏好服务删除。父目录符号链接、plist 符号链接和旁键类型分歧均有拒绝回归。完整门禁和发布状态见 [SP-292](../SP-292-open-issues-release-046/README.md)。

追加真实对照：同一自有 Simulator 和测试 App，先终止再直接删除磁盘键，重启仍读到 `DiskOrderProbe`。指定同一数据容器执行模拟器原生 `defaults delete` 后，重启前显示 `NativeDeleteProbe` 的 App 显示 `Preference: absent`。两组证据在本地 `continuation-disk-*`／`continuation-native-*`。

候选 CLI 的 `app prefs remove BatchTemporary --relaunch` 再次确认真实生效。公开 fixture 重启前显示 `Preference: ReleasePreferenceProbe`，重启后显示 `Preference: absent`。原生偏好域与磁盘都验证缺失，旁键保留布尔 `false`，再次删除返回 no-op。9 项专项测试通过。原始回执与截图在本地 `continuation-prefs-candidate/`。

## 发布包复验

正式 v0.2.46 的 arm64 CLI 重跑了同一公开 fixture。重启 App 独立读到缺失，原生偏好域和磁盘核验均通过，旁键布尔值及重复删除行为一致。[GitHub 回帖](https://github.com/NeptuneKit/TritonKit/issues/283#issuecomment-6911831888)。
