# Revyl CLI 2026-10-27 增量审阅

结论：observe；无新增可确认本地gap，不创建采用切片。允许文本增量审完，但完整性仍为partial，不能推进成功检查点。

上游范围：[compare](https://github.com/RevylAI/revyl-cli/compare/ecbe45690fe4605acf7faa62dac7afcccd3690a9...6e66797f4a5c60167bde443f6bffa47d0bb70038)，9 commits、30路径；compare单页9项，9个commit文件单页均少于100项，无分页截断。26个明确用途白名单文本在固定HEAD读取；4个pyc只记路径，不读取内容。源OpenAPI相对固定base的结构化差异仅新增performance endpoint及10个schema（含channel_failure），不把整个生成文件当已闭合的历史来源。

实际本机main `cfda992467fc1ed19ef0c577577c313d79314069`，main分支且只有原目录worktree；对照SP-192/196/200/223机制与当前源文件。仅只读审阅，未实现/构建/运行上游/安装/设备/提交/远端写入。

- **云Computer性能报告、cursor watch与schema — observe**：[固定源码](https://github.com/RevylAI/revyl-cli/blob/6e66797f4a5c60167bde443f6bffa47d0bb70038/cmd/revyl/computer_performance.go)。云computer新增CPU/内存/磁盘/网络/FPS，source live/saved/none，2048 cursor、10s末态等待、超时124/取消130且不停止computer；托管host r3.36依赖超出现有本机产品范围。JSONL为明确watch例外，不能复制进Triton单envelope命令。 BDD：未来若独立批准本机性能采样：Given无数据/取消/超时，Then区分unknown/empty与完成，预算有界、目标绑定、只取消观察不重放动作；当前不新增云报告入口。 本地：Sources/TritonKitCLI/CLIHostProcessRuntime.swift, Sources/TritonKitCLI/CLIHostProcessDrain.swift, docs-linhay/spaces/SP-223-host-process-drain-deadline/README.md, docs-linhay/spaces/SP-192-ictrl-adoption-feasibility/README.md。

- **明确空兼容runtime集合不同于missing — observe**：[固定源码](https://github.com/RevylAI/revyl-cli/blob/6e66797f4a5c60167bde443f6bffa47d0bb70038/internal/devicetargets/targets.go)。runtimesFor以map key presence区分无兼容项和缺省全量；Triton本机sim create显式device-type/runtime交由CoreSimulator校验，无上游托管catalog或把空列表展开为全runtime的相同路径，未证实本地缺陷。 BDD：若将来引入兼容矩阵：Given显式empty Then候选为空且拒绝创建；Given absent Then按明确契约处理unknown/默认，不能把两者等同。当前不为尚不存在的数据结构新增实现。 本地：Sources/TritonKitCLI/CLIHostSimCommands.swift:365, Sources/TritonKitShared/TKHostAdapterModels.swift:421, docs-linhay/spaces/SP-196-upstream-optimization-delivery/README.md。

- **Linux computer托管Android与Web identity测试 — observe**：[固定源码](https://github.com/RevylAI/revyl-cli/blob/6e66797f4a5c60167bde443f6bffa47d0bb70038/internal/mcp/device_session_computer_test.go)。新增Android APK hosted session，Web测试保留canonical app/build/session身份；这是远端云会话，SP-200明确排除云fleet/MCP server。既有本机录制/动作身份约束不意味着具备托管会话。 BDD：Given既有本机target/录制session，Then拒绝不同target/旧PID并保留来源；当前已覆盖方向，不引入computer_session_id或远端Linux资源。 本地：docs-linhay/spaces/SP-200-mobile-device-parity/README.md, Sources/TritonKitCLI/CLIHostSimulatorRecordingRuntime.swift。

- **screen channel_failure结构化stage/reason — observe**：[固定源码](https://github.com/RevylAI/revyl-cli/blob/6e66797f4a5c60167bde443f6bffa47d0bb70038/internal/api/generated.go)。新增offer/answer/gather/transport及timeout等云WebRTC错误schema；本机Simulator provider无该传输，不把生成模型新增当本地功能缺口。 BDD：Given本机provider失败 Then稳定机器可读code、来源与unknown边界；不新增不存在的WebRTC stage。 本地：docs-linhay/spaces/SP-192-ictrl-adoption-feasibility/README.md, docs-linhay/spaces/SP-196-upstream-optimization-delivery/README.md。

- **GitLab连接去feature gate、Web组织Experiments、版本发行 — observe**：[固定源码](https://github.com/RevylAI/revyl-cli/blob/6e66797f4a5c60167bde443f6bffa47d0bb70038/cmd/revyl/gitlab.go)。GitLab保留认证/权限错误并移除组织enabled gating；Web自助开启属于托管组织产品，均非本机CLI范围。v0.1.192 Release仅安装/分发说明，HEAD文本已0.1.193，不能等同已发布0.1.193。 BDD：不为组织/计划开关新建控制面。若未来范围批准，认证与权限仍需独立失败测试。 本地：AGENTS.md, docs-linhay/dev/reference-project-adoption-workflow.md。

Release API一页97条（小于100，分页完整），今日最新[v0.1.192](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.192)，其notes只介绍安装、独立computer及校验和；未下载资产或执行安装。HEAD包版本0.1.193不是已发布证据。

保留故障：仓库许可官方404；旧大增量generated/hosted/binary来源语义缺口；今日4个pyc变化未获取。complete_text_delta_review=true，complete_review=false，不改变历史checkpoint。无新可复用纠正需写tracked资料，本审阅与取证只落本ignored目录，由主控汇总。
