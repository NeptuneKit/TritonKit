# Typed App Preferences 最小切片

影响层：macOS CLI app prefs；限 bundle app-data plist。App Group、suite、Web、HTTP不在本切片。

## BDD

- Given false/0/empty/missing key，When get，Then present 明确区分存在与缺省，已有value合法值编码保持兼容。
- Given JSON/plist dictionary 与重复 --key 白名单，When import，Then 整包严格类型校验，缺选中键、null、Date或非法数字失败不写；只原子合并白名单 keys，其它keys保留，默认receipt不输出值。
- Given set/import 默认选项，Then 仅写磁盘，不自动终止/启动。显式 --relaunch 才串行terminate→launch。
- Given terminate/launch失败，Then receipt保留diskWriteVerified:true与明确失败阶段，退出非零；runtimeConsumptionVerified始终false。

先写测试，再最小实现。默认不设备动作、不启服务、不提交。现有single-key JSON/Data/plist和atomic基础迁移复用；大型CLIHostAppCommands prefs块拆出，降低1500行风险。主控接管schema与最终全包回归。

## 实现收口

- `CLIHostPreferencesCommands/Runtime/Models.swift` 独立模块；原命令注册名称保留，`CLIHostAppCommands.swift` 降至1428行；`CLIHostRuntime.swift` 仅迁移原prefs段，主控截图改动保留。
- `get` 在兼容原有value/typed字段上新增 `present`。false、0、空字符串存在；missing（包括缺省plist文件）返回 `present:false`，不以false/0/empty推断缺失。unsupported实际值报错，不冒充missing。
- `import --input <file> --input-format json|plist --key <key>`，`--key`可重复，default input-format=json。整包严格校验后只合并显式白名单keys；缺selected key、null、Date、非有限数字、超范围整数、超32层/1MiB失败不写。plist Data沿用现typed编码；无意外Date/string转换。
- set/import新增 `--relaunch`（default false）。磁盘原子写后readback，显式请求时terminate→launch串行；失败保留 `diskWriteVerified:true`、`relaunch.status`、稳定 `preferences_relaunch_failed`与非零退出。所有stdout failure保持一个合法envelope。
- import receipt只输出keys/types和交付状态，不输出旧/新值；原set输出已授权选中值保持兼容。`runtimeConsumptionVerified:false`不因launch exit0而改为true。
- 修复迁移后的helper visibility；get/set/import path只从bundle app-data container解析，拒绝非法bundle path组件、失败或截断container查询。

## 验证

先新增 `HostPreferencesSetTests` 场景与 `HostPreferencesDeliveryTests`，按主控要求不启动源码不稳期间全CLI编译。使用现缓存Shared/ArgumentParser object链接**实际**新Models/Runtime与禁止host动作的stub，纯executable fixture通过：presence/type；整数0保留int；presence/失败receipt最终JSON编码；整包null/Date拒绝；白名单atomic合并；launch失败receipt；无效包在pathProvider前拒绝且无写入。

fixture运行：`.build/sp196-resource/preferences-fixture/run`（ignored scratch）；编译日志 `/tmp/sp196-preferences-fixture-build.log`。`git diff --check`通过。最终CLI parser/focused/full门禁交由主控统一；本轨道没有设备、服务、提交或push。纯fixture不构成真实App消费偏好证明；可选relaunch的实际terminate/launch效果仍需主控授权隔离目标验证。

Schema同步由主控拥有：prefs get `present`；prefs set `--relaunch`和`diskWriteVerified/relaunch/runtimeConsumptionVerified/error`；新增prefs import命令及上述options/receipt。App Group/suite仍在边界外。

## 主控最终验证

主控最终回归：完整CLI通过。专用App missing present:false；白名单导入false/0/empty后均present:true，未选notImported仍missing。未运行App时relaunch按契约terminate-failed/diskWriteVerified:true非零；显式先launch后import --relaunch exit0/status:launched。runtimeConsumptionVerified始终false。私有证据`.triton/sp196-validation/prefs-*.json`。
