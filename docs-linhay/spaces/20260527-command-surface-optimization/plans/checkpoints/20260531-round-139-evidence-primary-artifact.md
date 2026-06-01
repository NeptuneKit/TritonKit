# Round 139: evidence primary artifact

## 背景

继续减少 agent 在 evidence 面上的数组扫描。当前 `TKEvidenceManifest`、`TKEvidenceSummaryResponse` 和 `TKEvidenceRedactionResponse` 已有 `primaryArtifacts[]`，但 agent 只想知道“先看哪一个 artifact”时，仍然要自己取第一个元素。

## 本轮动作

1. 为 `TKEvidenceManifest`、`TKEvidenceSummaryResponse`、`TKEvidenceRedactionResponse` 新增 `primaryArtifact: TKEvidenceArtifactSummary?`。
2. 默认回填规则统一为：
   - 显式字段优先；
   - 否则回填 `primaryArtifacts.first`。
3. 旧 JSON decode 继续兼容：
   - manifest / summary / redact 缺少 `primaryArtifact` 时，沿现有 `primaryArtifacts[]` 排序规则回填。
4. `evidence.manifest`、`evidence.summary`、`evidence.redact` 的 schema output contract 同步暴露 `primaryArtifact`。

## 验证

1. `swift test --filter TKEvidenceModelsTests`
2. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 结果

1. agent 读取 evidence bundle、离线 summary 或 redact 结果时，可以直接消费单值 `primaryArtifact` 作为第一跳诊断入口。
2. `primaryArtifacts[]` 仍保留完整高信号排序，不损失后续 artifact drill-down 能力。
3. 该字段只表达首选 artifact summary，不表达真实“唯一正确”的文件路径或替代 evidence 规则。

## 后续

继续检查 target / host workflow 面是否仍存在类似“一跳首选结论只藏在数组或嵌套对象里”的事实源缺口，优先挑 agent 高频读取但仍需手工聚合的面继续收口。
