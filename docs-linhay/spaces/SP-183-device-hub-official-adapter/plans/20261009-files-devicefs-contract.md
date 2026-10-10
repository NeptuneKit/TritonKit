# 下一批：Device files / DeviceFS 公开契约与安全清单

> 2026-10-09；只读subagent审查有closing，未写文件/build/test/设备操作。主控复核Apple官方文章后补充crashLogs与mountpoint事实；本文件是实施计划，未实现/未动作验收的项保持missing，不把缺项泛化为platform-unsupported。

## 官方可用接口，不猜私有挂载路径

[Apple命令行文章](https://developer.apple.com/documentation/xcode/interacting-with-devices-using-the-command-line)（本轮直接读取官方JSON文章）明确：

- 文件域：appDataContainer/appGroupDataContainer/systemCrashLogs/temporary；必须遵循各域权限，不代表全部设备均可读写。
- appDataContainer需要App bundle ID。temporary用非空客户端字符串隔离客户端空间；不能仅凭描述断言获取该空间没有隐含创建副作用。
- 官方crash reports示例为`device info files --domain-type systemCrashLogs`，未带identifier。因此不能因本机help没有逐域细则而把该域统一unsupported；应建模identifier可省略，且单独验证文件JSON和权限失败。
- `device info mountpoint --device ...`是公开DeviceFS位置查询，不需要硬编码用户路径或打开Finder。通用DeviceFS默认位于`~/Library/Developer/CoreDevice/DeviceFS`；具体设备位置必须使用query结果，验证设备绑定，不遍历整个共享卷。
- 子目录包括AppDataContainers/AppGroupContainers/DiagnosticReports/Temporary，mostly-readonly且部分App域允许写；文件系统浏览不等于额外写权限。
- Simulator已启动、physical已配对是前提；不自动boot/pair/unlock。JSON文件版本化、终端文本不可作为结果parser。

本机帮助已经private保存，只算help-advertised-only：files的用户参数是`--username`，copy为`--user`；files缺省递归，必须显式`--no-recurse`。copy from help出现remove-existing-content的设备写描述歧义，readonly/evidence接口永不传该flag，也不能把copy to混入只读列表。

## 可复用代码与新增限制

- [现有两个App域和copy from builder](../../../../Sources/TritonKitShared/TKHostAdapterDevicectlModels.swift#L3-L83)：argv数组、artifact JSON/log、evidence risk和timeout metadata可复用；新增crash/temporary应逐域建模，不能要求无意义bundleID。
- [App pull输入与发布](../../../../Sources/TritonKitCLI/CLIHostAppPullCommand.swift#L98-L230)：ready iOS real、bundle/group互斥、同目录staging/校验后发布可复用，不能当全域/Simulator文件支持。
- [目录验收](../../../../Sources/TritonKitCLI/CLIHostAppPullCommand.swift#L254-L310)：maxBytes是复制完成后校验，不限制远端传输与磁盘峰值；需要maxEntries/maxDepth/大小求和overflow测试。现有source仅trim/nonempty，不是域内相对路径安全规则。
- [private info runner模式](../../../../Sources/TritonKitCLI/CLIHostDeviceInfoRuntime.swift)：0700目录/0600文件、runner/reader注入、非零/缺失/畸形失败可复用；新增bounded file reader，不能用无限Data(contentsOf:)假称硬限制。
- [pull tests](../../../../CLI/Tests/TritonKitCLITests/HostAppPullTests.swift)：已有bounded artifact/overwrite/目录与互斥基础，但不是以下新增安全场景的完成证据。

## BDD / TDD 队列

1. `device files`独立metadata-only请求：显式domain及按域identifier规则，默认shallow且显式no-recurse，CLI/schema说明系统约束；temporary列为需独立side-effect policy的域，不按readonly契约直接试跑。
2. 先RED精确argv（用户名flag分开、路径为一个argument、不带copy to/remove），非法域冲突/backend前拒绝、绝对路径/..段/NUL/控制字符拒绝；只对list显式允许域根。
3. 已实际捕获：owned Simulator files明确CoreDevice1001/com.apple.coredevice.feature.listFiles unsupported，但mountpoint成功result.dataPath；probe boot→query→finally shutdown，name/state及其它实例不变。physical systemCrashLogs metadata浅列表成功，无identifier、无内容获取/写，JSON result.deviceIdentifier/domain/files[]；entry包含metadata(size/date/owner/permissions/xattrs)、name/relativePath与resources bool属性。原始JSON/文件名/device IDs/mount path仅private0700/0600；后续第三批Triton files shallow readonly已实现并实际验收，见[ledger](./20261009-files-verification.json)；第四批mountpoint CLI已实现/owned实例真实验收，exact echoed --device绑定、native path只private JSON/token且不访问返回路径；safe浏览仍待实施，详见[mountpoint ledger](./20261009-mountpoint-verification.json)。Parser以真实匿名fixtures开始RED，精准匹配deviceIdentifier/domain；资源isWritable不算写授权、非目录不自动算regular file。未知type/错误outcome/非零/缺JSON/超大JSON fail closed，不把help或backend probe当Triton动作成功。
4. 白名单文件metadata，raw JSON/log private。默认不公开敏感domainIdentifier、原始device aliases、全文路径或文件内容；需要可复用entry token及显式内容artifact入口，而不是将敏感字段简单全部删除导致CLI无法操作。
5. JSON字节/entries/depth/整数overflow/路径逃逸、symlink父目录和dangling link、旧输出原子保护、JSON/text/error/sourceCommand全脱敏测试。
6. `device mountpoint`独立只读query：位置DTO不等同列出文件；在公开machine contract中以权限、敏感artifact引用和明确范围表达，不能自动打开Finder或对共享DeviceFS全卷递归。
7. 实际设备写/temporary namespace创建/copy to与download-container replacement另设审计/显式确认，禁止自动fallback后重复写；无真机写验收时保留证据缺口，不把模型测试称真机完整支持。
