# 2026-10-20 simulator/runtime 官方只读监测

actual main `f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`；仅写本证据目录。官方GitHub默认HEAD、最新非draft Release（含prerelease，全分页）、固定HEAD许可证全文/hash均逐仓保存。HEAD无变复用20261019同revision完整源码审阅；Baguette旧点为历史导入，provenance保持partial。Release tag与发布metadata独立比较，不把下载计数当版本变化。

| 仓库 | SHA | HEAD变化 | Release metadata变化 | 完整 | 裁决 |
|---|---|---|---|---|---|
| tddworks/baguette | `14b39834fef6` | True | False | False | observe |
| EvanBacon/serve-sim | `a30d70a55e05` | False | False | True | observe |
| lycorp-jp/sim-use | `dc58fe8ea235` | True | False | True | adopt |
| MobAI-App/simslim | `6518ba7eab11` | False | False | True | observe |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | False | False | True | observe |
| JaviSoto/device-hub-ios | `9f5481c3efdf` | True | False | True | observe |
| heoblitz/Loupe | `ff1351242e6d` | False | False | True | observe |
| jfarcand/mirroir-mcp | `845a981163aa` | False | False | True | observe |
| RockxyApp/Rockxy | `de791b63e7f9` | False | False | True | observe |
| ProxymanApp/atlantis | `cc059013de87` | False | False | True | observe |

## tddworks/baguette
相对imported历史点仍有9提交；本日相对昨日观察HEAD/Release/许可无新变化。APK关联源码provenance未闭合，保持partial，不推进旧点。
错误：Prior same-HEAD review partial: APK associated-source provenance remains unclosed; imported baseline is historical only

## EvanBacon/serve-sim
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## lycorp-jp/sim-use
窄采用：本机Simulator多显示器路由安全拒绝。当前AX几何来自mainScreenSize/mainScreenScale且point hit-test displayId=0；Resize guard仅检查appResize，inactive不能证明应用在主屏。Duo副屏active时数值合法几何仍可能映射错屏，SP210数值校验与SP196 Resize gate均不覆盖该事实。

{
  "decision": "adopt",
  "reason": "窄采用：本机Simulator多显示器路由安全拒绝。当前AX几何来自mainScreenSize/mainScreenScale且point hit-test displayId=0；Resize guard仅检查appResize，inactive不能证明应用在主屏。Duo副屏active时数值合法几何仍可能映射错屏，SP210数值校验与SP196 Resize gate均不覆盖该事实。",
  "product_baseline": "main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c",
  "boundary": "只读研究；未执行上游、依赖、设备或产品测试。SP192/196/200/210/212已交付机制不重复排期。",
  "mechanism": "simulator-nonprimary-display-fail-closed",
  "local_gap": {
    "files": [
      "Sources/TritonKitCLI/CLIHostSimulatorAXDriver.swift:356",
      "Sources/TritonKitCLI/CLIHostSimulatorAXDriver.swift:448",
      "Sources/TritonKitCLI/CLIHostSimulatorAXDriver.swift:510",
      "Sources/TritonKitCLI/CLIHostSimulatorResizeRuntime.swift:assertIOSSimulatorResizeTouchAllowed"
    ],
    "evidence": "main-source-check.json"
  },
  "scope": "只读显示拓扑事实/可信主屏判定、单一失败envelope与离线fixture；非主integrated active或拓扑无法确证时不得执行基于主屏的坐标/命中/捕获。具体旧Xcode能力失败兼容需设计，不可无证据把unknown当主屏。",
  "non_goals": [
    "不自动支持iPhone Duo fold/rotate/HID或AX副屏路由",
    "不改变既有默认坐标语义",
    "不复制上游fail-open unknown或永久缓存",
    "不安装idb patch或运行上游",
    "不把本研究当设备验收"
  ],
  "bdd": [
    "Given appResize inactive但非primary integrated display active，When准备主屏坐标动作，Then动作计数0并返回稳定机器错误。",
    "Given单primary integrated active且完整target-bound拓扑，When执行现有动作，Then保留合法单屏行为。",
    "Given虚拟Resizable列于topology但无active resize，Then不因显示器总数大于1误判Duo。",
    "Given malformed/多active/目标不匹配/timeout/unsupported，Then unknown不得伪装主屏可路由；兼容策略单独显式验收。",
    "Given两次操作间折叠/重启切换active或displayUUID，Then新操作重新确证，不沿用永久缓存。"
  ],
  "license_condition": "固定HEAD LICENSE全文为Apache-2.0（GitHub识别NOASSERTION）；采用机制独立实现，若复制须保留版权/许可/变更通知。idb外部patch依赖许可不从根LICENSE推定。",
  "other_decisions": {
    "covered": "Resize unknown拒绝、几何finite校验：SP196/SP210已覆盖；Android活动身份和shell转义：SP212已交付。",
    "observe": "Duo完整副屏路由、fold/rotate、新side-bar outline；需要另定产品契约与实际设备证明。",
    "reject": "直接改变Triton坐标默认或引入上游个人工具目录/未知时回主屏策略。"
  }
}

## MobAI-App/simslim
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## Mastersam07/OpenDeviceHub
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## JaviSoto/device-hub-ios
9f5481c3单提交4文件：视觉snapshot从idiom改viewport size classes、lint调用外部ios-build-support。上游App测试/构建治理，与Triton CLI/HTTP当前需求无可直接采用差距；不引入上游个人目录依赖。

## heoblitz/Loupe
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## jfarcand/mirroir-mcp
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## RockxyApp/Rockxy
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

## ProxymanApp/atlantis
本日HEAD/Release/许可无变化；复用昨日固定HEAD完整相关机制源码审阅，无新增采用。

未运行上游/安装依赖/操作设备/执行产品测试。完整性为读取与有界相关机制评估，不代表运行、性能、真机或新Duo控制能力验收。固定官方来源以各仓head.json、compare页、commit页、source json/full、Release页与LICENSE.full复核。
经验检查：沿用既有独立checkpoint、partial不前移、main固定blob与读取/采用分离规则，无新增治理规则；主控统一更新权威文档/state。
