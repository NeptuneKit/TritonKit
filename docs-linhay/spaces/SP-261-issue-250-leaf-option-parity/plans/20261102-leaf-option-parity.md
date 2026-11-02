# #250 叶子参数契约与 parser 对齐

## 边界与 BDD

影响层仅 CLI 只读 schema 元数据。候选不修改动作 parser、执行器、设备状态或 #247 所负责的 sideEffect 字段。

1. Given `sim boot` 实际 parser，When 查询 full/compact `sim.boot`，Then 显式提供必填 `<udid>`、完整用户参数，叶子 timeout/interval 默认分别为 60/1 秒；父级其他命令仍保留原 300 秒 catalog。
2. Given `act tap` 实际 parser，When 查询 full/compact `act.tap`，Then 提供可选 `<query>`、width/height 及全部公开参数/alias/default，不混入 swipe 参数。
3. Given `device.runner.stop` 与 `device.stop`，When 保存 compact 输出，Then 完整 command/fullSchemaCommand 自包含且不同；空格与点式的同一路径 fingerprint 相同。关联 #245 新增路径身份反馈。
4. Given `DeviceStop` 实际 parser 与两平台统一输出 DTO，When 查询 compact `device.stop`，Then 包含全部合法参数/默认/确认语义，唯一输出契约绑定 `HostDeviceStopOutput`；optional 字段与真实 JSON 编码一致，不借用 `DeviceActionOutput`，不因补输出 selector 而遗漏参数。

## 验证方式

专属 `LeafOptionParityTests` 从三个实际 command 的 help declaration column 提取参数集合，与 full leaf references 和 compact options 比较，并使用真实 `TritonKitCLI.parseAsRoot` 验证默认值、显式值、位置参数和 alias；非法数值/缺失必填参数须拒绝。只 parse，不调用 run，不能宣称设备动作或超时实测通过。

范围仅两个原报告命令及路径身份反馈触发的 device.stop，不能以本测试宣称全库 parser parity。完整 schema 是 metadata 事实来源，compact 成功仍不证明其他源 schema 完整。复用既有经验入口的逐层 schema/parser 核对要求，不改变全局治理规则。

## 当前状态

已先写 BDD 和失败测试。按主控串行安排，使用已验证 SP256 CLI 进行实际只读 schema/help RED：6 次查询均 exit 0，10 项缺失参数/默认值断言全部 false，断言脚本 exit 1；二进制版本、SHA256、查询 argv/stdout digest/help 与实测字段保存在 [RED 证据](20261102-red-evidence.json)。这是实际进程 RED，不是新 Swift suite 已运行。

RED 后最小修改：sim catalog 新增 interval 和 udid argumentForm，boot leaf 显式 timeout/interval override、必填 udid 与全部参数；tap leaf 补 query/width/height 引用。其余 root 默认、parser、动作和副作用字段不变。

原候选 focused Swift 执行及新失败见下节；修复后的候选须重新验证，不能沿用前一候选的通过项作为最终 GREEN。之后应以本候选二进制重跑只读 schema/help 检查，并由主控完成受影响 SchemaFactSource/CompactSchema 与完整门禁。

## 路径身份回归发现与最小补齐

主控在 SP256 `codex/integrate-sp261` 执行实际 focused Swift 验证：142 tests / 3 suites / 1 issue。原四项 `sim.boot` / `act.tap` parity tests 通过；`nestedStopCanonicalPathsRemainSelfContained` 捕获 `No output selectors are declared for device.stop.`。日志与 hash 见 [RED 元数据](20261102-stop-contract-red.json)。这是主控真实执行并经只读复核的新增 RED，不是本源 worktree 的测试执行。保留原测试，不删除断言、不改 compact fail-closed 行为。

源码确认 Android 和 Harmony stop 均编码 `HostDeviceStopOutput`，与已有 `DeviceActionOutput` 不同。因此新增专属 `host.device-stop` contract，字段直接绑定 DTO；参数 refs 对齐 `DeviceStop` 的 12 个公开参数，`--emulator` 的叶子默认覆盖 root 启动命令 union，launchd domain 使用动态 `gui/<uid>` 描述。两平台都要求 confirm，因此声明 `requiresConfirmation=true`；不改变 #247 的 sideEffect 所有权，不运行 stop。

新增测试只调用 help / parseAsRoot / schema / JSONEncoder：验证全部参数与默认、Android/Harmony 合法 argv、拒绝不属于 stop 的 `--scope`、三个真实 DTO 构造（Android、Harmony、skip-launchd）的 JSON 字段集合与 optional 缺省。合同不把命令完成声称为独立设备状态验证；保留 warnings 和 sourceCommands 中跳过 bootout 的语义。

修复后候选已冻结，`git diff --check` 通过。未启动 Swift，等待主控串行复制本源候选后重跑 focused 与相应门禁。没有 Git 写、设备、服务、发布或动作实现变更。原权威 schema/helper 和本计划已更新可复用经验：compact 失败揭示缺失源契约时，应绑定真实 DTO 与 parser 补齐元数据，不能借其他 action 输出或仅补 selector 获得虚假的完整叶子。全局索引/memory 由主控统一收口。
