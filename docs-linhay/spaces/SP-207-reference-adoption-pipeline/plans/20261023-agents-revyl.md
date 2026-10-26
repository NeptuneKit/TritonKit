# 2026-10-23 agents / Revyl 官方参考日检

影响层：CLI/HTTP/shared core静态评估；main固定409670ef1435aec5950f7e1b30fea8e0b2ecc705。首次请求TLS/connection reset已原样归档first-attempt，随后按主控指示仅做一轮安全重试，官方HEAD/Release查询全部恢复；未绕过TLS。

| 仓库 | 固定HEAD | 最新非draft Release | 完整性 | 相对昨日 |
|---|---|---|---|---|
| getsentry/MobileBuildMCP | `2998ac77ebbca59544e88a27f34bfb830db9d924` | v2.7.1 | complete | 变化 |
| awizemann/harness | `3f58c077ded131cca71d75efb05c5d325f0ed18f` | v0.8.4 | complete | 未变 |
| dongxinsuperman/ai-phone | `d339057bc64aa85002570765e2a20d45e0391bae` | v0.8.0 | complete | 未变 |
| karminski/eyes-on-my-phone | `eef71926e613c3242643923bb21c92beab439990` | 无 | partial | 未变 |
| RevylAI/revyl-cli | `c61af5e0d3cdf193c46524fac4d86bc0db9a9166` | v0.1.185 | partial | 变化 |
| RevylAI/app-explorer | `b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e` | 无 | partial | 未变 |
| RevylAI/greenlight | `fcb36e395bd4ae20448f2535382baecba9396fd9` | v0.2.0 | complete | 未变 |
| RevylAI/mobile-devtools | `efc1dae5da089ec08108a39f1ead39324c11b410` | 无 | partial | 未变 |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56a08f3718aefc82dc911c1b3a2f23` | 无 | partial | 未变 |
| RevylAI/visual-regression | `2758e8a88f4efb3a251b675e0984c091bf8abeb8` | 无 | partial | 未变 |
| RevylAI/figma-design-checker | `8b4e5cea045dcff5c30aa723b923e514d2cdc07a` | 无 | partial | 未变 |
| RevylAI/CogniSim | `3d8902e011981b93cb0ebfafba1794eab93b053e` | 无 | complete | 未变 |

5 complete / 7 partial；MobileBuildMCP、Revyl CLI有新变化，其余10仓身份/Release/许可未变。Release全分页、所有body、固定HEAD许可全文/hash见raw与results.json。首次网络失败已恢复，许可证404不是网络恢复。

## MobileBuildMCP：完整增量，无采用缺口

[固定HEAD](https://github.com/getsentry/MobileBuildMCP/tree/2998ac77ebbca59544e88a27f34bfb830db9d924)，[唯一变化](https://github.com/getsentry/MobileBuildMCP/blob/2998ac77ebbca59544e88a27f34bfb830db9d924/.github/workflows/release.yml#L194)。两个提交、一个文件：MCP Publisher专用setup-go从1.22升为1.26.10；相关workflow全文已读，未执行。最新v2.7.1发布说明未变。TritonKit为Swift CLI，未采用其Go MCP publisher链，不能据此生成Go升级任务。固定许可证SPDX仍NOASSERTION，全文/hash已保存；不把历史MIT标签视为复用许可。

## Revyl CLI：新增量已审，历史partial未恢复

[固定HEAD](https://github.com/RevylAI/revyl-cli/tree/c61af5e0d3cdf193c46524fac4d86bc0db9a9166)，[遥测等待](https://github.com/RevylAI/revyl-cli/blob/c61af5e0d3cdf193c46524fac4d86bc0db9a9166/internal/analytics/analytics.go#L122)，[v0.1.185](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.185)。相对昨日3提交/12路径：Go1.26.9→1.26.10，版本0.1.184→0.1.186，后台analytics flush最多等待250ms→1s，其余4个pyc变化只记路径未取内容。HEAD版本与最新已发布tag不同是实际观察，不伪造v0.1.186发布。Release完整安装说明已读，未执行安装命令。

analytics Flush先有界等待后台payload，再发送终态payload；延长等待没有本地性能或可靠性证明。TritonKit当前源码搜索无同类云CLI遥测出口；SP-204本地脱敏日志是另一职责，不能将等待延长当通用修复。相对成功checkpoint24提交/268最终路径的旧大增量、generated/hosted语义与pyc来源仍不完整；官方固定HEAD许可404，README的MIT徽标不能替代许可全文。因此仍partial、不推进成功checkpoint或复制源码。

## 本地主线、BDD与权限

已核对SP-192/196/200/203～205/216的交付与产品边界，alias/预算/unknown、设备本地契约、发现/日志/Runner鉴权、HDC归属均有既有交付；无新增实际本地缺口，不重复分派、不生成伪BDD。若后续有本地背景遥测丢失的独立证据，再新建“给定慢flusher与终态失败，退出有界且业务失败不被遥测覆盖”场景；目前仅潜在研究场景，不是采用授权或缺陷结论。

仅官方只读取证；未运行第三方代码、二进制、测试、构建、安装、设备或远端写入。源请求前按具体用途/文本路径审阅；pyc与任何身份/密钥/证书均未获取。未修改共享docs/state/git。

治理：已读AGENTS、ops-governance、subagent-supervision、经验索引与参考采用流程。保留首次失败及独立恢复证据；复用现有partial与许可规则，无新产品经验需要扩展权威资料，由主控统一写回。
