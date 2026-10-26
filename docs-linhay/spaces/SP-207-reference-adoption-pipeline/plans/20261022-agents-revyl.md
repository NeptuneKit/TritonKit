# 2026-10-22 agents / Revyl 官方参考审阅

影响层：CLI/HTTP/shared core 静态评估；独占输出本目录，未修改共享 docs/state、未执行上游代码/二进制、测试、构建或设备操作。实际 main 基线采用主控确认的 `409670ef`。

## 结果

| 仓库 | 固定 HEAD | Release | 完整性 | 相对昨日 | 结论 |
|---|---|---|---|---|---|
| getsentry/MobileBuildMCP | `d13ff0c707b0` | v2.7.1 | complete | 无变化 | no_new_adoption |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | complete | 无变化 | no_new_adoption |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | complete | 无变化 | no_new_adoption |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial | 无变化 | no_new_adoption |
| RevylAI/revyl-cli | `66086f78f2fe` | v0.1.182 | partial | 有变化 | defer |
| RevylAI/app-explorer | `b3edc443dbfb` | — | partial | 无变化 | no_new_adoption |
| RevylAI/greenlight | `fcb36e395bd4` | v0.2.0 | complete | 无变化 | no_new_adoption |
| RevylAI/mobile-devtools | `efc1dae5da08` | — | partial | 无变化 | no_new_adoption |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56` | — | partial | 无变化 | no_new_adoption |
| RevylAI/visual-regression | `2758e8a88f4e` | — | partial | 无变化 | no_new_adoption |
| RevylAI/figma-design-checker | `8b4e5cea045d` | — | partial | 无变化 | no_new_adoption |
| RevylAI/CogniSim | `3d8902e01198` | — | complete | 无变化 | no_new_adoption |

5 complete / 7 partial；11仓身份、Release、许可证与昨日相同，不重复通知或创建采用项。许可404与此前partial属于保留问题，没有恢复成功或授权源码复用的含义。

## 唯一新增量：Revyl CLI

固定源： [HEAD](https://github.com/RevylAI/revyl-cli/tree/66086f78f2fe8448bdf7b808d1cfd2aeb590aa22)，[v0.1.182](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.182)。相对成功检查点21 commits、267 paths；compare提交完整，21个commit均按100文件分页读取，144文件提交已取第二页。每页JSON保存在raw。全部Release分页和完整body保存在results.json及raw/releases-*；没有下载资产。

重点源码读取：device_session.go明确管理cloud-hosted sessions，owner测试失败关闭；durable session ID禁用共享会话列表持久化，防止并发覆盖；untargeted stop测试拒绝多个live或starting会话，并区分不可读inventory与cached信息；错误surface测试统一下一步文案；action timing测试保留十进制精度并独立过滤非法/负值，原worker success/error不应被遥测字段覆盖；script timeout测试要求report和summary保留实际timeout_seconds，legacy/unknown不伪造默认。来源为raw/RevylAI_revyl-cli/source/中的固定HEAD源码与测试。仅静态读取，无上游测试通过声明。

仍为partial：许可证官方固定HEAD端点404；267个变化文件涉及generated OpenAPI、hosted computer/Web和pyc二进制，未逐一完成源码语义审阅。读取了完整文件清单和相关源码不代表全量审计。docs/computer.md在该HEAD已删除，contents404为删除事实，不视为权限恢复。

## 本地覆盖与边界

已对照SP-192、196、200、203～205、216的README/INDEX交付状态与当前源码入口。SP-192/196已经覆盖alias身份/新鲜度、预算及unknown结果语义；SP-200设备契约不引入云租赁；SP-203～205已完成发现/日志/Runner鉴权；SP-216已完成HDC ownership清理。具体本地证据：CLIObservationModels.swift:215 freshnessRejected；CLIObservationBudget.swift:41/91/102/108预算；CLISchemaObservationOutputContracts.swift:30超时unknown且不自动重放；CLIHostHarmonyArkWebRuntime.swift:309 listing失败ownership未知即拒绝；CLIEvidenceArtifactsRuntime.swift:152 freshness。

新增remote owner/多会话stop和computer telemetry属于托管服务具体语义，不能推定本机CLI存在同类缺陷，也不据此新增MCP/云设备面。未发现有固定证据且尚未交付的本地采用项；不创建实现任务。若后续独立证据显示本机指标污染业务success/error，再单独建立BDD：给定非法可选timing字段和真实失败，当输出JSON时保持原失败，剔除非法遥测；当前仅观察候选，不作为本轮采用授权或缺陷结论。

## 许可与来源边界

MobileBuildMCP固定LICENSE SPDX为NOASSERTION，保留全文hash，不按历史MIT标签许可复制；harness、ai-phone、greenlight、CogniSim官方许可全文已保存并SHA-256。eyes-on-my-phone与Revyl CLI/app-explorer/mobile-devtools/mobile-pr-reviewer/visual-regression/figma-design-checker许可404，不建立源码复用权限。

所有12仓官方repo metadata、默认分支HEAD、完整Release分页及固定HEAD许可响应均归档raw/<owner_repo>/。每仓精确SHA/hash、checked_at、错误、比较基线和证据位置见results.json。无API403；许可404已明确partial。

## 治理检查

已读取ops-governance、subagent-supervision与经验索引参考更新条目。无本地实现修改，无新增可复用经验；完整性/许可边界沿用现有权威规则，本次只在独占证据目录记录，交由主控统一写回。
