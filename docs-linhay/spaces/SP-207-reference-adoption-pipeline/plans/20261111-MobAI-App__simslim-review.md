# simslim 2026-11-11 增量审阅

固定base `d594c230fe9ed5080189b0ce76afabda6104bae0` → head `7e374b3839d49608a681d1f8b9ca0dd83d35189e`，actual main `607410fb3d44bfe02274c13822170c3015c63a99`。[上游增量](https://github.com/MobAI-App/simslim/compare/d594c230fe9ed5080189b0ce76afabda6104bae0...7e374b3839d49608a681d1f8b9ca0dd83d35189e)。3提交/3 parent边、4棵无截断树、14路径、26文本版本全部读取且Git blob hash验证，无排除。LICENSE固定全文MIT/hash确认。[v0.14.0完整notes](https://github.com/MobAI-App/simslim/releases/tag/v0.14.0)与源码一致。

## 裁决

adopt窄范围只读依赖诊断：main SimulatorResourceCatalog.features没有mdm/app-clips/accessibility-assets，resolveFeatures会unknownFeature，使resource doctor无法按这些功能解释实际override。采用服务依赖知识，增加只读feature→labels以及disable副作用解释；不增加slimmableLabels/managedLabels、ci默认禁用集合或自动启停能力。上游新增mdm类别的三个label以及other的axassetsd/clipserviced会改变默认slim行为，未经Triton专用设备功能实测不直接迁入。上游10/225MB与clean-boot测量只记上游自述，未在本地复验。

建议映射：mdm依赖remotemanagementd和RemoteManagementAgent（对应上游features）；app-clips依赖ClipServices.clipserviced；accessibility-assets依赖accessibility.axassetsd（对应上游服务说明）。如需managedassetsd扩充MDM资产诊断，应另列语义并验证，不能自动把category全部当功能必需。

BDD/测试：新feature解析返回明确label；doctor对fixture中已禁用/启用label给准确解释且不执行mutation；旧unknownFeature仍fail-closed；增加诊断后ci/stock desired labels与现有基线相同。候选文件面为CLISimulatorResourceCatalog.swift及对应Catalog/Inspection tests，主控查实际测试命名后建space、先失败fixture再串行main实现。本agent未实现。

## 保留观察

watch新增kqueue监听device-set目录并预写所有shutdown实例的undocumented launchd store，第一启动前只增加disables、允许race后下次启动生效，并在boot后readback；新增设备plist等待2秒、目录重挂、per-device并发和已删设备prune。main watch仅对booted设备用noReboot执行，apply已能对明确UUID离线写入后启动读回。自动扩到所有shutdown设备、额外device sets和preboot持久副作用超出本窄切片，保留观察，不把未实现watch等价描述成已覆盖。

测试warm-up只为macOS首次exec检查不污染fake timeout，Triton本轮无同源失败证据，不改timeout。现有main源码固定副本在local-main。未运行上游/设备/测试，未改产品/检查点；本日证据不冒充历史raw恢复。
