# 新旧 Xcode 命令兼容验收

## 裁决

公共 `device / target / app / sim / xcode` 入口保持稳定。Device Hub并不意味着所有上游命令改名；优先复用新旧共用argv，不按版本号臆造另一套调用。选中工具链由xcrun与子进程DEVELOPER_DIR决定，不修改全局xcode-select，不在失败后改backend重发写动作。

## 兼容矩阵

| 契约 | 旧版本证据 | 本机Xcode27.1证据 | 调用策略 |
| --- | --- | --- | --- |
| simctl list devices available --json | 共用argv＋合成legacy help测试 | 真实help＋发现验收 | 保留simctl生命周期来源 |
| simctl bootstatus -b | 合成legacy help测试 | 真实help宣告支持，未执行boot | doctor只查询help |
| devicectl list devices --json-output path --log-output path | 既有builder契约、v3 fixture、合成legacy help | 真实help＋v5发现验收 | 文件JSON，不默认用新stdout形式或omit-deprecated开关 |
| devicectl device info details --device | 既有builder＋合成legacy help | 真实help宣告支持 | 不传已移除--show |
| devicectl install app / process launch | 共用argv回归、environment标记脱敏沿用 | launch/launch-environment真实help宣告支持 | 未执行安装/启动，不宣称动作兼容实测 |
| xcodebuild -version | 两个fixture开发目录的process配置测试 | xcrun版本报告27.1/27A9275 | 防PATH-shadowed xcodebuild，尊重选中工具链 |

**用户进一步明确：Xcode26就是之前的命令，不删除即可**。本需求不要求下载或安装Xcode26，不把缺少旧安装作为保留旧命令的阻塞。已有入口、参数与simctl/devicectl/xcodebuild路径继续保留。常见安装目录仅一个Xcode；26/27配置路径、legacy help和旧JSON仍是fixture，不冒充旧SDK实测。若未来需要实测旧安装，下述脚本支持子进程工具链选择。

## 实现与验证

- [命令支持模型与只读help探测](../../../../Sources/TritonKitCLI/CLIHostAppleCommandCompatibility.swift)：精确option token边界、10秒单次help预算；失败明确unsupported，不重试，不携带device动作参数。
- [discovery/doctor](../../../../Sources/TritonKitCLI/CLIHostDeviceDiscoveryCommands.swift)：`commandSupport`输出`verification=help-advertised-only`，只必需discovery影响doctor.ok；可选launch扩展不冒充业务ready。simulator不查询CoreDevice，real不查询simctl，all要求两后端。缺工具不继续nested help。
- [命令兼容测试](../../../../CLI/Tests/TritonKitCLITests/AppleCommandCompatibilityTests.swift)：9项含参数化26/27目录及legacy/modern help；先RED证明scope健康误报、非必要后端查询与PATH版本混用，再修复；option probe RED25issues后GREEN。首轮另修正测试将已有--json误写成-j的假设，未为测试修改共用argv。
- 已有超1500行device命令文件按discovery commands拆分，原文件1477行；DeviceList保持原逻辑，未引入重复runner。
- 全量串行CLI：1011 Swift Testing/81 suites＋14 XCTest，0fail，17.820秒；根包281 Swift Testing＋7 XCTest，0fail；Release构建完成111.29秒。
- 新Release CLI真实doctor三scope均ok，simulator2项、real4项、all6项全部help宣告支持；此前Triton status因server_unavailable exit1，不启动serve，host诊断不依赖App runtime。
- 只读subagent失败且无结论，所有采用证据由主控直接核查。未改系统Xcode、设备或安装CLI，未提交/合并/发布。

## 用户澄清后的保留与真实动作验收

旧命令保留由[注册与单点参数回归](../../../../CLI/Tests/TritonKitCLITests/LegacyAppleCommandRetentionTests.swift)固定：sim 30（含隐藏tap）、app 12、device 13、xcode 12项原有子命令均保留，不引入必需Run。单点boot/install/launch/terminate/uninstall参数仍可解析。首轮完整串行CLI1013 Swift Testing/82 suites＋14 XCTest通过。

Xcode27.1：Triton status/device doctor/capabilities/schema重新捕获；discover返回2个工程、3个package，schemes可读取根package及两个fixture工程。第一轮误用原有Shutdown标准设备，不符合专门隔离要求；已移除本次测试App、恢复Shutdown，不作为隔离验收。随后用Triton sim create新建SP183专用实例，ownership/UDID/原始输出仅保存ignored私有目录。专用实例create/boot/wait-ready/app list/install/info/launch/terminate/uninstall及shutdown全部通过；卸载后info单一app_info_not_available/exit1。截图输出成功但黑屏，不冒充业务渲染成功。

专用实例的高级run构建成功，但先因Shutdown安装失败；显式boot后出现install固定30秒超时，app info/list证明安装已完成，未盲重装。发现`--timeout`没有传到Simulator install/launch。新增[阶段timeout回归](../../../../CLI/Tests/TritonKitCLITests/XcodeRunPhaseTimeoutTests.swift)：先修测试fixture缺derivedDataCache的编译错误，再得到600秒两阶段各一处期望失败；[最小实现](../../../../Sources/TritonKitCLI/CLIXcodeRuntime.swift)仅对两阶段调用withTimeout，nil保持旧默认和全部command metadata。每阶段独立预算，不承诺总流程deadline或自动重试。

最终focused12、完整CLI1014 Swift Testing/83 suites＋14 XCTest（19.773秒）与Release构建（123.65秒）通过。先只读确定fixture已安装，再卸载该已知本次安装后fresh run，新binary的专用实例高级build/install/launch通过（5277ms），并完成info/terminate/uninstall、user apps=0及Shutdown。保留专用实例以供复验；已有业务booted目标仍Booted。Xcode list自动更改的tracked resolution文件已恢复baseline，不带入本片。[脱敏动作摘要](./20261009-action-verification.json)。

下述只读脚本仍仅验证help，不替代上面的真实动作结果。真机动作没有执行；SDK26没有安装或实测，不影响用户要求的旧命令保留。

## 可复跑

[只读命令验收脚本](./20261009-command-acceptance.py)输出当前工具链的实际健康结果，允许旧Xcode缺CoreDevice时simulator可用而all/real为false；仅CLI子进程覆盖环境。原始输出保存到fresh ignored目录。

```bash
python3 docs-linhay/spaces/SP-183-device-hub-official-adapter/plans/20261009-command-acceptance.py \
  --triton .build/cli/out/Products/Release/triton \
  --developer-directory /path/to/Xcode.app/Contents/Developer \
  --output-directory docs-linhay/references/SP-183-command-old-xcode
```

后续完整local再跑：依赖边界、DEBUG隔离、root测试、Release build/smoke、Harmony host/iOS runtime observe smoke全部通过；显式TRITON_VERIFY_XCODE=0跳过非本片Simulator工程构建，不计为通过；最终exit1仅strict docs编号缺181/182。主仓ci-docs/check-docs/diff全exit0，183spaces；本分支独立docs-ci/check-docs为1、diff为0，Python/JSON语法及7个新增相对链接验证通过。[脱敏验收摘要](./20261009-command-verification.json)。

本分支完整local/docs检查仍受未集成SP-181/182编号缺口影响，保持既有可复现限制，不复制无关研究或放宽checker。主仓文档门禁另行复验；串行测试绿也不证明既有并行stdout/deadline干扰已修复。
