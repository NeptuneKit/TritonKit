# Loupe 2026-11-02 增量静态审阅

裁决：adopt（仅DTUHID transport候选，未实现/未验收）。可采用：补充本机Simulator DTUHID服务transport、严格unsupported回退和无事件barrier；main仍仅LegacyHIDClient，明确modern backend unsupported。Web网格/SwiftUI私有遍历另保留观察。

## 来源与完整性

官方 https://github.com/heoblitz/Loupe 。固定base `ff1351242e6dbaba4a0b4de40d10350a668f03b8` → head `180c60584867500b93b43ca6c8b556995bf8be7b`；actual main `44e81f5d333ba842051579639d3834981e7b2340`。分页commit列表读至base，2提交/2父边/3完整recursive tree，全部truncated=false。逐父边路径并集32，54个安全文本(path,blob)完整保存，排除[]，不是仅净diff。见review-manifest.json、review-source/、review-increment.diff。先按源码/测试/文档/配置用途和Swift/Objective-C/C header/Ruby等文本白名单筛选，未获取身份、证书、私钥或二进制；未请求含patch compare/commit。

LICENSE.full固定HEAD SHA-256 `0d7ebd755456885dba28523a5c468e59d06a26c8df2b896938632c9322c9e7e3` 与result一致；API NOASSERTION保留，人工全文识别MIT，不套用API空断言。若引用其标注idb协议来源须另核实来源许可并保留通知。Release当前仍v0.5.1，正文关于SharedFrameworks兼容；HEAD formula已指v0.6.0并去旧bottle，不能据此宣称v0.6.0 release/bottle已存在。未下载或执行产物。

## 机制裁决

1. **adopt — DTUHID现代Simulator transport**：上游新增服务`com.apple.coredevice.feature.remote.hid.digitizer`的SimDevice.lookup/XPC连接。仅方法缺失或已知SimError405走legacy；启动/连接错误拒绝，不吞失败改走另一输入。连接及finish用不产生字符的barrier，4秒超时拒绝；touch typed uint64 phase(0/1/2)、double坐标和keyboard payload，串行连接，完成后释放。main CLIHostNativeDigitizer.init只创建SimDeviceLegacyHIDClient；CLIHostSimulatorHIDProbe明确modern unsupported，未有该service/DTUHID。这是本机Simulator现有范围内的新backend，不需扩真机/云。旧SP-218/237和当前17采用登记包含legacy/resize/DeviceHub既有交付，但不含此service transport，不能把此前普通HID实测当现代transport已覆盖，也不能由上游CI声明推断当前Mac故障。
2. **observe — Web visible-point-grid**：新增Simulator AX request type6采样可见WKWebView区域，25pt格、64并发、总deadline、前台PID校验、frame center同对象复核、secure value屏蔽；输出complete=false，missing不等于不存在。web alias先near再full扫描、身份/role/enabled校验，tap后必须focused才type。main已有AX translator hit-test、SP-192 freshness和SP-196 embedded DOM WebView输入；此网格是不同host只读补充，不宣称已覆盖，但缺少当前实际Web AX缺口复现，不把采样和alias动作直接纳入本次transport切片，避免把incomplete树升为可靠语义target。
3. **observe — legacy message动态stride**：上游保留builder返回event尾部、malloc_size/stride校验，避免ABI固定结构。Triton通过IOHIDEventCreateDigitizerEvent及trackpad wrapper构造，不复制该mouse-message layout。无需把其结构体修复移植到不同wire builder。
4. **observe — SwiftUI update scope**：上游通过匹配begin/end私有symbol包围_viewDebugData，缺symbol安全nil；本地无该Loupe私有debug遍历入口，不新增私有SwiftUI ABI依赖。
5. **covered/observe — framework与测试发布**：main已兼容Contents/SharedFrameworks及版本路径；上游DEVELOPER_DIR.app归一化、deviceByUDID快速路径、测试脚本、fixture和formula更新不能独立证明本地缺陷。SP-192预算/unknown、SP-196 helper隔离、SP-200平台动作契约继续适用。

## 采用切片BDD与文件面

候选只实现本机Simulator DTUHID transport，先离线失败测试，再最小接线；不改embedded SDK、真机、Web业务写面，不自动重放输入。

- Given服务可用且no-event barrier应答，When建立会话并tap/drag，Then同一连接依序down/move/up，finish barrier有界，stdout保留单JSON且source/backend明确；barrier不得输入字符，transport consumed不等于businessVerified。
- Given lookup仅明确unsupported（已知405/方法缺失），Then允许legacy；Given连接拒绝、符号缺失、barrier超时或不明错误，Then fail-closed，不能静默fallback/重发mutation。
- Given移动/释放/finish出现错误或取消，Then保留unknown副作用语义、有限清理自有contact，不重播tap，拒绝并行争抢target。
- GivenResize/secondary或未知geometry，Then沿用现有display policy拒绝，不能将DTUHID target0硬编码扩大路由。
- Given真实Xcode27 DeviceHub主显示专用fixture，Then验证tap实际后置条件、drag实际scroll变化、无事件liveness及legacy环境回归；无法执行则明确未验收，不以XPC fake绿色代替。

建议实现文件面：新增CLIHostDTUHIDTransport.swift/专用wire模型与fixture测试，调整CLIHostNativeDigitizer.swift、CLIHostSimulatorHIDProbe.swift及既有helper routing/schema仅所需字段；专用新space登记边界。主控先核对不与现有17项重复，再独立worktree实施。不得在本审阅目录写产品代码。

## 阶段与限制

只完成静态读取与候选评估；上游源码/测试/设备/依赖均未执行，真实transport、安全时序和性能均未本地证明。local-main-evidence.txt绑定固定main；未改result.json、正式docs/state、Git或其他人WIP。验证：所有blob UTF-8、清单存在、JSON可解码、许可hash一致。经验检查沿用逐父边/许可人工识别规则，无新治理模式；正式BDD/space/memory由主控接续。
