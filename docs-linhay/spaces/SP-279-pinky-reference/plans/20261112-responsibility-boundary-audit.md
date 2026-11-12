# TritonKit 职责越界审计（2026-11-12）

> 修复前审计快照：用户随后授权移除越界；当前实施与验收以[SP-286](../../SP-286-raw-business-data/README.md)为准。下述源码行号/状态属于审计时点，不作为修复后的待办清单。

## 判定

按用户最新裁决：TritonKit负责设备操作、采集、真实结果和技术控制；不自行判断业务数据是否敏感，不因内容看似密码/邮箱/号码而删值或要求审批。上层显式要求的脱敏、系统权限、目标绑定、协议凭据、文件安全与可验证性限制不能混为业务越界。

**当前代码存在越界。确定问题主要在test recorder/import自动内容判断与网络采集默认改写；没有证据表明已实现Pinky式支付/消息/金融App自动审批拦截。**

基线：main `6467b413` + 当前未提交SP-281及研究WIP。只读搜索Sources（Swift）、Tools（Android Kotlin）、Web（TS），重点逐读命中函数及生产caller/测试；不声称覆盖仓库每个文件，不检查依赖与外部Pinky源码作为Triton行为。不改Sources/Tests，不运行设备、构建、server、回放或产品测试。本轮验证仅文档门禁。

## 确认的越界

### B1：test recorder自动猜测敏感输入，删编译值并阻断回放

- [内容识别函数](../../../../Sources/TritonKitCLI/CLITestRecorderCompileQualityRuntime.swift#L128)：任何含password/token/secret、邮箱格式或连续11位及以上数字的输入都算敏感。没有从调用方接收业务判断规则。
- [自动生成privacy_candidate](../../../../Sources/TritonKitCLI/CLITestRecorderCompileQualityRuntime.swift#L9)：编译时增加contract.redaction finding。
- [删除编译inputText](../../../../Sources/TritonKitCLI/CLITestRecorderRuntime.swift#L956)：type/paste输入匹配上述猜测后写nil；原始actions.jsonl仍在，不是删除源包。
- [回放阻断](../../../../Sources/TritonKitCLI/CLITestRecorderRuntime.swift#L1361)：出现contract.redaction就产生redaction_review_required。
- [import阻断](../../../../Sources/TritonKitCLI/CLITestImportRuntime.swift#L205)：存在finding时拒绝导入；privacy被映射为redaction_review_required。
- [测试明确固定了该行为](../../../../CLI/Tests/TritonKitCLITests/TestRecorderContractTests.swift#L1149)：要求inputText=nil、不包含邮箱，并要求dry-run/simulated/matrix均blocked。本轮未运行这些测试，不能称实测复现。

影响：测试账号、长订单号、商品名“secret”等合法业务输入会被工具层自行解释并影响产物/流程。不是仅提示警告，也不是协议凭据保护。

建议：去掉默认内容识别→丢值→硬阻断链。编译/导入保留原语义；脱敏/变量化只接受显式请求或上层已声明规则。路径/格式/不支持动作等真正技术错误仍拒绝。

### B2：import依据目标文字内容拒绝tap/assert

- [importExactAXSelector](../../../../Sources/TritonKitCLI/CLITestImportRuntime.swift#L626)：不只检查空值/占位值，还调用importTargetLooksSensitive。
- [importTargetLooksSensitive](../../../../Sources/TritonKitCLI/CLITestImportRuntime.swift#L648)：复用上述识别，并对任意总计11位及以上数字拒绝；不要求是银行卡或手机号。
- [测试](../../../../CLI/Tests/TritonKitCLITests/TestImportTests.swift#L204)：以长数字目标文字为例，预期不生成plan。

影响：工具替用户决定哪些UI文字不可作为selector，会阻挡按订单号/业务编号断言的正常回归。与selector唯一性、页面新鲜度无关。

建议：仅保留空值/占位值/无法映射/歧义等技术校验，不按文字内容决定可否导入。

### B3：自动生成network fixture时替换业务内容

- [写fixture的实际调用](../../../../Sources/TritonKitCLI/CLITestRecorderNetworkFixtureRuntime.swift#L12)：默认调用redactTestRecorderNetworkFixtureBody。
- [替换规则](../../../../Sources/TritonKitCLI/CLITestRecorderNetworkFixtureRuntime.swift#L49)：邮箱替换为占位符，token类模式也直接替换。
- [compile生产路径](../../../../Sources/TritonKitCLI/CLITestRecorderRuntime.swift#L1069)：writeNetworkMapIfReady默认生成这些fixture。

影响：自动生成的response body不再与源响应等价；邮箱本来就可能是断言或页面匹配依赖。业务body里叫token的字段也不必然是Triton自身的认证凭据。原始流未被此函数覆盖，但编译派生fixture已改值。

建议：原样fixture和显式转换分开；转换后不能冒充原响应。Triton自身的session/transport token仍按协议保护。

### B4：proxy capture默认删除全部URL query/fragment

- [redactedNetworkCaptureURL](../../../../Sources/TritonKitCLI/CLIHostNetworkCaptureIntegrity.swift#L124)：除userinfo外，无条件清空query和fragment，不检查调用方要求。
- [持久化入口](../../../../Sources/TritonKitCLI/CLIHostDeviceProxyServer.swift#L1008)：落盘前必调用redactedNetworkCaptureEvent；该函数也把原始failure文本统一改为泛化消息。

影响：诸如page、sort、search、订单过滤等业务参数一起丢失，影响诊断和可复跑匹配。userinfo认证保护与删除所有query不是一回事。此项不改变上游真正转发的请求；改的是capture/diagnostic副本。

建议：拆分协议认证信息与业务URL；采集保留业务参数，公开分享版本的处理由上层或显式导出选项决定。

## 需要拆分判断，不能直接全删

### R1：Harmony verified input拒绝secure/掩码字段

[布局判定](../../../../Sources/TritonKitCLI/CLIHarmonyVerifiedInput.swift#L70)会根据password标记、inputType或全部圆点/星号拒绝；未明确password=false的TextInput也会拒绝。[CLI](../../../../Sources/TritonKitCLI/CLIActionCommands.swift#L643)同时把--secure与--verify当作不兼容。--secure在同命令中的定义其实只是输出脱敏。

- 明文不可读时无法完成“完整值精确相等”验证，这是技术限制，不能假报verified。
- 但把掩码/secure标记等同“不能提交输入”，或因一个输出选项直接禁止调用，需要拆开；应分别表达可否输入和可否读回验证。
- [当前测试](../../../../CLI/Tests/TritonKitCLITests/HarmonyVerifiedInputTests.swift#L209)固定了TextInput缺password标记时零tap/零send。普通act type仍有独立host输入分支，不是Harmony所有输入被阻断。

结论：存在过宽拒绝/能力混用，不能仅删guard后继续承诺精确verified。

### R2：WebView forms对所有值硬编码length-only

[WebView snapshot](../../../../Sources/TritonKit/TKRuntimeWebViewProvider.swift#L147)读取rawValue后只返回valueLength/valueRedaction，普通input/textarea/select也一样；[focus response](../../../../Sources/TritonKit/TKRuntimeWebViewFormScripts.swift#L133)同样只返回长度。

这不是支付/密码语义识别，但把所有字段固定裁剪为摘要，是工具层写死的采集范围。若上层请求字段值，当前接口不能满足，不能声称完整表单快照。建议明确提供值采集能力和上层选择；保留长度模式作为显式选项，不把系统未提供的值伪造为原文。

### R3：resident iOS sanitizer递归按键名删text

[iosRunnerSanitize](../../../../Sources/TritonKitCLI/CLIIOSRunnerModels.swift#L63)同时删除pngBase64、认证/内部字段及所有text键，[生产调用](../../../../Sources/TritonKitCLI/CLIIOSRunnerRuntime.swift#L222)处理返回envelope时无条件运行。

认证token和大图base64有明确协议/传输理由；业务text字段不能仅因键名与它们共用删除规则。当前实际可观察值是否受影响依赖具体provider返回形状，本轮不夸大为所有文字都丢失；列为需按schema拆分的风险。

### R4：新action evidence只导出receipt，不导出原provider响应

[ActionEvidenceSession.finish](../../../../Sources/TritonKitCLI/CLIActionEvidenceRuntime.swift#L73)只写shared receipt/events/meta，没有原stdout/stderr/响应artifact。本身不是内容审查，也没有检测后删值；它是摘要证据产品范围。此前以“敏感”为理由把原始证据排除出默认设计，是本会话方案的职责漂移。应由采集配置决定是否保留原件，并明确receipt-only不等于完整响应归档。

## 不属于此类越界

- 用户显式调用[evidence redact](../../../../Sources/TritonKitCLI/CLIEvidenceCommands.swift#L138)：属于用户请求转换；但其按artifact种类整份替换占位符的实际效果要说清，不能称为精准内容脱敏。
- 用户主动传--secure、provider/app主动声明redaction：规则由调用方给出，不是我们猜测。
- own session token、Authorization握手、访问控制、0700/0600、no-follow、排他文件、size/deadline限制。
- target/lease/selector/freshness/geometry验证，不重复输入，未知不假报成功。
- 无法明文读回时verification unavailable；不能为了“不要管敏感”而编造匹配成功。
- runtime Debug开关、Release不采集和用户显式allowedActions/allowedBundles，均是部署/执行配置，不是识别用户业务内容。

## 未发现与未验证

在本轮Sources关键词扫描和逐读生产路径中，未找到Pinky式“支付/发消息/金融App→自动审批或拒绝”的规则引擎；Context approval字段与coordinator非allow拒绝不等于这种引擎。不能从搜索未命中推出整个仓库绝无相关代码。

未执行产品测试、设备操作或网络服务；现有测试断言只作为代码行为证据。本轮不改产品行为，不删除任何guard，不创建提交或推送。文档/资料更新用单独门禁验证，不继承历史产品测试计数。

## 处理顺序

1. 先移除B1/B2的默认业务判断/丢值/硬阻断，保留真实技术错误。
2. B3/B4原始采集与显式转换分开，保留源字节/业务参数；认证字段按协议边界单独处理。
3. R1输入能力与验证能力解耦；R2提供采集值选择；R3按返回schema拆内部凭据与业务payload；R4明确完整证据/摘要证据的配置。
4. 失败测试必须用邮箱、长订单号、password/token/secret普通业务字符串证明不会因内容被拒；另证真实认证凭据、路径/权限/错误语义不回归。

这是一份代码审查结果与建议，不是已修复声明。
