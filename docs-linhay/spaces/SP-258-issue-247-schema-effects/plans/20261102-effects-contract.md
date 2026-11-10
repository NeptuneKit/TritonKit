# Schema 副作用契约与 BDD

影响层为 shared schema wire model 与 CLI 元数据；不改变执行 parser、动作权限或 retry 行为。来源 GitHub #247，五个样本只是入口，审计 act/app/sim/build 全部一层声明。其它未审计操作不猜测无副作用。

## BDD

- Given 未声明 effect 的未来命令或旧 JSON，When 初始化/解码，Then sideEffect=unknown；明确 reserved unsupported 的 sim.type 仍显式 none。
- Given input、App/Simulator lifecycle、build/artifact 操作，When 查询完整或 compact schema，Then 声明相应潜在 effect；readonly 查询与文件落盘区分。
- Given sim runtime delete --dry-run、proxy --plan-only、prefs get/dump、UI 只读形式，When 查询schema，Then 返回结构化条件；非 dry-run delete 保留确认要求。
- Given 根公共模型增加条件，When 经过 schema decorator、JSON roundtrip 与 compact 投影，Then 条件不丢失、不丢 scope。未知条件不匹配只读 case，不解除保守 base effect，也不授权 retry。
- Given build ios/android/harmony，Then 不编造 --dry-run（实际 parser 没有此 flag）；内部 plan 函数存在不代表 CLI 暴露 plan-only。

## 最小字段方案

现有 usageForms 只有人读描述，不能可靠表达 flag=true/false 与同一个 UI 命令的查询/写入形式。新增向后解码兼容字段 sideEffectCases，元素含 sourceCommand、argumentPrefix、可选 argumentCount、optionValues、sideEffect 与可选 requiresConfirmation。optionValues 匹配 parser 解析后的值（包括已知默认值），所有条件同时满足才适用；缺值/未知不匹配。字段缺失解码为空数组。base effect 仍表示潜在操作类别，条件只描述已审计分支，不是执行授权或成功证据。

sourceCommand 防止 ancestor 条件在 compact flatten 后错误套用到其它命令；UI 查询的 argumentCount 防止只匹配 appearance 前缀就把 appearance dark 当只读。requiresConfirmation 缺失表示沿用 base，不能隐式变 false。

## 验证计划

新增 SchemaEffectsTests：公共 unknown 默认/旧 JSON、四类 table-driven 元数据、只读与 dry-run 条件、roundtrip/decorator/compact、parser-only 拒绝虚构 build flag、安全确认/不自动 retry。先运行真实 RED，再实现。命令为 swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter SchemaEffectsTests。共享模型变化还需完整 root/CLI 回归及标准发布门禁，由主控串行调度。全部验收无设备写入，无私有项目访问。

## 已审计事实与边界

58 个现有一层声明逐项覆盖：act 12、app 12、sim 31、build 3。事实源是 CLIActionCommands/相关 action runtime、CLIHostAppCommands、CLIHostPreferencesCommands、CLIHostSimCommands、CLIHostSimulatorMaintenanceCommands 和 CLIBuildCommands 的实际 parser/执行分支。映射集中于 CLISchemaSideEffects.swift，未知新命令不会按命名推断为 readonly；未审计其它命令族保留 unknown。

- app uninstall 与 sim erase 的现有 --confirm gate 仅补入元数据；不增加或撤销执行权限。
- app prefs dump/get 无偏好写入；set/import 可额外 --relaunch，因此该条件声明 App lifecycle 效果。
- sim runtime delete 的 --dry-run 查询不删除；真实 delete 与 dyld-cache remove 保留确认语义。personalization 的 remove/revoke 分支同理。
- sim proxy doctor/status 为只读，start/export/stop 的 --plan-only 先返回计划；真实 start/stop 仍需确认和现有审计门禁。基础 effect 是可能的主机网络与制品写入。
- sim ui appearance/increase-contrast/content-size 省略可选 value 才是查询；必须匹配精确 positional token 数 1。
- sim.type 是已存在且始终拒绝的 reserved unsupported 路径，显式 none 只描述未提交输入，绝不表示支持。
- 三个 build CLI 没有 --dry-run；已删除 schema 中 Run or plan 的误导文案，真实构建分类含进程执行及文件写入。

此变更只证明 schema 与已审计 parser/分支的契约一致，不证明任何真实 App/Simulator 执行成功。unknown/default 改动是有意的安全语义修正，默认 full 输出模式保持、字节内容不保持；新增字段缺失时解码为空数组，旧客户端通常忽略新增键。

requiresConfirmation 是声明而非授权字段。混合命令组的旧 base bool 保留；未匹配 case、未知 mode 或未知 effect 都不证明无需确认，更不允许自动执行。仅已知、已审计的 case 可细化相应模式；实际 parser/guard 始终权威。本切片不扩大 bool 聚合语义。
