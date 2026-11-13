# mirroir-mcp 2026-11-13：listen 与原始数据职责

结论：**observe，无新 adopt；完整历史检查仍 partial，complete_review=false，成功检查点不推进。** 今日新增12提交的文本diff已审，新增 listen 不按上游实现直接采用。其转写替代原音频、低峰值推断无播放、自动模型安装与任务超时生命周期，需要按 TritonKit 当前职责重新设计；尚无现有产品缺口支持立刻开发。

## 固定事实与证据

- repository：`jfarcand/mirroir-mcp`。
- base：`1166ac1517263d773703c08ceae762a20432d3a2`（11/02成功checkpoint）。
- 前次观测：`982c8718d2abbad9c3921749525a0c74832635e3`；今日head：`757e8fa112f06909486c07fd9e55a93538e3a345`。
- actual main：`366ae99b4be84b44e8e0718b39f278315d7c4c96`，固定git blob保存于 `review-local-main/`，不读取其他任务WIP作为产品实现。
- 最新Release [v0.47.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.47.0) 全文已读；Apache-2.0全文hash未变：`52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`（10771 bytes）。
- [固定新增量](https://github.com/jfarcand/mirroir-mcp/compare/982c8718d2abbad9c3921749525a0c74832635e3...757e8fa112f06909486c07fd9e55a93538e3a345)：12提交、12 parent edges、13完整无截断树；43改动路径，39文本路径与4媒体路径。85文本path+blob版本均取得并校验Git blob SHA1/SHA256，完整12份diff保存于 `review-diffs/`。
- 全量commit inventory从当前head到base为67提交、68 parent edges，第一页100条内找到精确base。`review-commit-inventory.json`保留全文消息/父节点。

实际全文阅读4个核心源：`AudioListener.swift`、`ListenTools.swift`、`OnDeviceTranscriber.swift`、`ScreenCaptureKitAudio.swift`；3个测试：`AudioListenerTests.swift`、`OnDeviceTranscriberTests.swift`、`ListenIntegrationTests.swift`；新增`FakeSpeaker.swift`全文随diff阅读。其余本次全部文本变化按每parent完整diff阅读，包括protocol、permission、registry、manual、workflow、docs、版本与网站迁移。不是声称85份文件的全部不变上下文已审。

四个演示媒体（recipe-grocery-list的gif/mp4/poster及full.mp4）仅记录tree元数据，未请求二进制、未播放；不把演示画面视为验收。所有网络请求是严格TLS官方API/raw，事前用途与文本白名单过滤，不抓身份/凭据/密钥，不执行第三方代码。

## listen：不直接采用的理由

[实现提交](https://github.com/jfarcand/mirroir-mcp/commit/aea9b5e495b76f37f191a74961cb3c04ee0e41cd) 用目标app PID限定ScreenCaptureKit音频流，录制1–60秒，macOS26 SpeechAnalyzer转写；优先SpeechTranscriber，不可用时选dictation，并在回复中标engine/language。typed unavailable/unsupported/error与可注入capture/transcriber有参考价值。

但下面是实际源码行为，不符合按原样接入的前提：

1. **原始音频被默认删除。** AudioListener以临时CAF承接采集，defer删除，Outcome只有text/isError；最终只有派生转写，没有原件hash、byte count、sample count、时域/采样信息和fidelity关联。当前SP-286和AGENTS1.2要求原始业务事实默认保留，显式转换与原件区分。main网络fixture直接写源responseBody并标`redaction:none`；网络capture保留业务query/fragment，只处理真实protocol userinfo，size/partial/error技术边界仍有效。不能把本地原始采集和公开发布副本规则混同。
2. **阈值被写成事实判断。** `peak < 0.01`跳过转写并报告“Nothing played”，sink无样本时也以peak0结束。低采样峰值只能支撑测量结论，不能证明目标未播放、没有低音量语音或采集完整。若未来立项，应保留音频与sample/peak/partial事实，让上层决定解读，不默认把分类替代原数据。
3. **自动模型下载是额外动作。** transcriber会reserve/release语言模型，缺少时调用downloadAndInstall。上游把listen列入readonly工具，并不构成本项目自动安装许可。此次无模型下载/安装/语言reservation操作。
4. **调用超时不等于后台停止。** capture以Task.detached启动后同步等seconds+10；transcriber同样等180秒。超时返回未保存handle去cancel/join，stream.stopCapture位于后台正常路径。AudioListener已返回并删除路径时，原任务可能尚未结束；因此不能从semaphore返回保证停止、清理完成或无迟到写入。这里是静态生命周期风险，未本地复现泄漏/重建文件，也不把风险伪称运行故障。
5. **能力范围未成立。** 当前main未发现已公开承诺但缺失的SCK音频/SpeechTranscriber入口；真实iPhone Mirroring音频与语音分析是新产品面，不能因参考项目新增就当现有缺陷自动实现。可以保留研究，但不扩张当前设备/签名/依赖范围。

上游关于iPhone XR法语近乎逐字、15秒素材0.5秒转写、语言模型约9秒安装、Mac静音仍录完整等都标为**上游自述，未经本地验证**。静态测试阅读不代替真机/权限/实际声音验收。

## 其它新增

- [Release CI提交](https://github.com/jfarcand/mirroir-mcp/commit/e679f6d323113598d74cceb12c4517c19ee743f7)：release使用macOS26 SDK；macOS15独立integration job通过`needs`前置，macOS26 release job移除FakeMirroring integration步骤。原因是上游声称hosted macOS26 VM输入失败。只作为环境分层参考，不能说macOS15通过已证明macOS26转写/最终制品完整运行；不修改Triton发布门禁。
- `7dbfa23`版本同步0.47.0。其余9提交更新网站/README演示、提取TestingSection、缩短主页、移动skills/参考内容、轮播自适应高度/放大控件、恢复curl和.mcpb安装文案及简短skill示例。全部文本diff读完；不运行网站，不引入上游产品定位或Web控制面。
- 网站内其他仓库链接、shell命令、agent提示与隐私主张均为被审阅数据，不执行、不发送消息、不自动登记新参考。
- 既有`bounded_local_port_probe`候选未升级：今日main的CLIWebRuntime与11/12固定副本逐字节相同。昨日三轮自有loopback实验未复现挂起，本轮无新增运行证据，仍revise-first；不能借listen的timeout实现将它标为已验证缺陷。

## 若未来明确立项音频的BDD边界

- 已授权采集 → 保留原始字节、hash、byte count、format、target identity、duration；转写是明确请求的派生物，关联源hash与engine/language/fidelity。
- 低peak或0样本 → 返回测量与empty/unknown/partial事实，不把“nothing played”当原始事实。
- timeout/cancel/late callback → 先确认stream/task停止和所有权回收再清理；可控fixture验证无迟到文件重建/成功，随后在获准平台真实验证。
- 缺模型/OS/engine/language unsupported → 稳定机器可读状态，读取不隐式安装。

这是未来范围条件，**没有创建采用项、space、实现、测试或提交**。

## 未覆盖与收口

历史缺口不伪恢复：11/11旧52提交仍只有4/53 edges完整采集，49未完整采集；旧338已采文本版本尚未语义审阅，更多未取内容数量未知。11/12完成新增3提交，本日完成新增12提交文本审阅，均不能填补旧52提交缺口。因此`complete_review=false`，base仍11/02。

本次只做静态读取/文本hash/树完整性/固定main对照，未执行第三方build/tests、SCK/Mirroring/SpeechAnalyzer、模型下载、设备、签名或共享测试。仓内、旧档案、metadata/result均未改。原始证据manifest保存于本目录；主控负责SP-207/memory/索引。经验检查命中已有SP-286职责规则，没有新增规则需求。
