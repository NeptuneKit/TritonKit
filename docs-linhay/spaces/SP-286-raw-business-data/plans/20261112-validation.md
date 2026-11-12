# SP-286 原始业务数据实现与验收（2026-11-12）

> 后续用户已授权整理和本地提交；只读app误分类窄修及提交候选最新验证见[本会话收口](../../SP-281-action-context-expansion/plans/20261112-session-closeout.md)。本报告保留SP-286实施时的1875项候选记录，不伪造历史数值或覆盖原始日志。

## 结论与基线

按用户裁决移除本次审计发现的默认业务内容猜测、丢值/替换和流程阻断，并将“提供原始数据、业务策略归上层”写进项目agent环境。当前main基线 `6467b4137c6667eb7a8a0bf564108a2bd51f6b9a` + 既有SP-281/研究WIP；实施验收记录时在main串行开发，尚未stage/提交/推送/发布，未创建branch/worktree，未安装升级全局agent环境或已发布skills。

这不是关闭认证或取消执行正确性：自有协议凭据、文件安全、目标/观察绑定、预算、真实unknown与不重放保留。明确请求的--secure/evidence redact仍可转换副本/输出；默认不按业务内容猜测。

## 已实现

| 修复前问题 | 当前实现 | 证据/测试 |
| --- | --- | --- |
| type/paste按password/token/secret、邮箱、长数字判敏感，compiled inputText丢值 | 删除testRecorderLooksSensitive和自动privacy finding，原String包含空串/空白保留；replay构造argv不跳过空String | RawBusinessDataTests多输入参数化、真实record→compile→dry-run链 |
| 导入按目标文字内容拒绝tap/assert | 删除importTargetLooksSensitive，空值/sentinel/identity/unsupported等技术校验保留，返回rawText而不是trim后文案 | TestImportTests邮箱/长编号/关键词、源包前后快照、既有技术负例 |
| 历史privacy finding硬阻断 | legacy privacy_candidate/contract.redaction只作为历史信息，不否决导入/回放；其它真实quality findings仍按合同处理 | legacy finding导入成功；其它identity/unsupported/quality用例仍在全量 |
| 网络fixture改写body并从compiled DTO省略responseBody | body原String进入fixture，Codable真实保留responseBody；nil和空body分开；同名/清洗碰撞分配独立路径避免覆盖 | 真实compiler空body、body Codable、a/b与a?b和重复id不同body各自保真 |
| URL query/fragment和错误被改写 | 无userinfo时直接返回原URL，保留编码/query/fragment；只移除userinfo认证段；error原值保留 | RawBusinessDataTests、NetworkCaptureIntegrityTests、HTTP metadata/HAR与evidence/replay档案链 |
| 旧v1 capture标记被新常量拒绝/误标 | 同schema兼容旧redaction标记，summary保留实际标记；不宣称恢复历史已删query | legacy source→validated capture/summary反例 |
| iOS按键名递归删业务text/token/authorization | 仅处理已知envelope控制字段，receipt嵌套解析绑定实际receipt operation；business result及found/receipt同形对象保持 | 普通/嵌套业务同名键、resident lifecycle/receipt恢复测试 |
| WebView所有forms硬编码length-only | 增加value字段，snapshot/focus/input脚本→payload→shared DTO→CLI decode/JSON真实贯通；focus元数据默认none | JavaScriptCore执行、实际macOS WebKit、CLI JSON字段roundtrip、旧JSON缺字段兼容 |
| 正文text[]规范化容易被当原文 | text[]作为legacy normalized summary保留；另加rawText保留空白/Unicode，UTF8预算截断有rawTextTruncated标记 | 实际脚本raw正文/换行/低预算prefix；不把summary冒充原文 |
| Harmony因secure/掩码/缺password=false禁止输入 | 不猜字符内容；provider标记只影响canVerifyText，在send后判断；无法读回时submitted+verification unavailable；原值observedValue默认输出 | mask可提交一次但不能verified；普通星号是正常文本；--secure仅变输出 |
| 原始action输出被排除 | explicit evidence保存provider原response/host各attempt stdout/stderr；native XCTest附件保存读取时原Data，无原Data时另存derived runner诊断 | 真实native attachment fixture未知business键/原Data相等，二次tap、非零、writer失败与hash测试 |
| 原件prefix/派生诊断可能被当完整数据 | raw artifact标retainedBytes/observedBytes/truncated/available/fidelity；截断或输出缺失使manifest.partial=true、receipt.partial、CLI非零；timeout不虚构stdout | prefix/coverage反例、原始delivery不被capture失败抹除、完整manifest bytes/SHA验证 |

## Agent环境写回

- 根AGENTS新增原始数据职责，覆盖默认采集、显式转换、技术例外、本地与公开分享的区别。
- 内部ops governance新增同一执行检查点。
- 三个业务public skills新增Raw data responsibility：emulator-cli-takeover、dev-feedback、real-project-regression。
- 清除接入模板自动设置redaction策略、safety-rules本地证据必须默认脱敏、Harmony掩码字段一律禁发、WebView必须隐藏field value等旧指令。
- README、CLI长期合同、EXPERIENCE、项目长期MEMORY和当日记录同步；旧审计报告明确是修复前快照，当前实现以本space为准。

没有修改 `~/.agents/AGENTS.md`、用户全局profile或已安装skills副本。本轮改的是当前项目实际维护的agent规则及可发布skill源码；公开分享仍需单独授权，不因本地raw采集而自动外发。

## Red → Green 与复审

- 初始CLI反例：4 tests / 1 suite失败，19 issues，真实抓住原输入丢值、privacy blocker、body/URL改写、nested业务字段删除。
- 初始WebView反例：10 tests / 2 suites失败，5 issues，实际脚本返回未含原值。
- 两名只读复审发现并修复：空值→占位符、fixture命名覆盖、旧capture兼容、截断原件假完整、focus元数据矛盾、native/derived附件身份。复审未写文件或运行测试，结论不代替下面运行结果。
- 新合同下旧测试中“必须隐藏业务参数”的断言改为核对原值；CONNECT无query夹具仍断言没有凭空出现参数。未通过放宽技术错误/target/freshness/timeout/文件安全门禁换绿色。

## 运行验证

| 检查 | 当前候选结果 |
| --- | --- |
| 完整CLI `swift test --package-path CLI --no-parallel` | XCTest 167项；Swift Testing 1875项/205 suites，通过exit0 |
| 原始数据完整性focused | Swift Testing 58项/3 suites及Apple runner XCTest16项，通过（最终完整CLI另外覆盖新增coverage等用例） |
| `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` | exit0；root runtime 132项/26 suites、shared313项/45 suites，以及XCTest2+5项通过；release CLI build、CLI/Harmony/iOS observe smoke、依赖/DEBUG边界、docs/diff通过 |
| `docs-linhay/scripts/verify.sh --ci-docs` / `git diff --check` | 本地链和最终资料收尾后均exit0；docs/skill/release契约通过，不沿用早期doc失败 |
| 真机/Harmony IME/用户iOS App/Simulator动作、签名/DDI | 未执行；本轮本地fixture和macOS WebKit不代替这些验收 |

最终实现/测试文件hash与private日志归档写入本机ignored `.triton/sp286/20261112/`。归档只绑定实际运行候选，不把当前已扩充的test文件冒充初始red测试源码；红日志与最终源码hash分开保存。

## 兼容性与边界

1. 默认输出语义有意改变：调用方不应再假设普通业务文字会被自动脱敏。公开issue/远端分享在上层对副本另做处理，不篡改本地原件。
2. 旧compiled contract/fixture若已经丢值，必须从仍在的原始录制流重新compile；旧capture已删query不能凭新版本恢复。旧标记如实保留。
3. WebView新字段是additive optional；旧JSON仍解码。用户App须重编译/更新embedded SDK；只更新CLI不会改变旧App内脚本。
4. 有界raw采集不是无限采集：预算prefix、provider未返回字节、系统掩码/不支持能力必须标partial/unavailable。大小/hash只说明已保存字节，不证明未采集部分。
5. Names-only headers和TLS正文未采集仍属于原有网络观测边界；此项没有伪造完整网络抓包。
6. 结构化receipt/legacy text摘要不是原件；原provider artifact、rawText/value与fidelity/completeness要分别读取。自有protocol PNG有独立artifact路径，非业务敏感识别。
7. 本次解决职责审计列出的路径；不是声称全仓所有专用摘要均变成字节级采集器，更不声称P0-P2全局执行owner/Stop/resume已完成。
