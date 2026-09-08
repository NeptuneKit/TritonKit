# 缓存观察契约与限制

`derivedDataCache` 的已有字段继续保留。`exists` 仅表示 invocation 解析时路径为目录；`cacheState` 为 `directory-exists` 或 `missing-derived-data`。`incrementalExpected` 保持 Bool 兼容，当前固定 false，含义是没有经过验证的增量预期，不能解读为强制全量构建。`cleanupPolicy` 仍为 `preserve-by-default`。

新增 `reuseVerification: "unknown"` 与可选 `observedBuild`。旧 JSON 可以继续解码；没有新字段的历史报告保持 nil，不能把历史 `warm` 值追认为已验证命中。

`observedBuild` 字段：

| 字段 | 契约 |
| --- | --- |
| `classification` | `compilation-observed` 表示识别到编译或模块生成日志头；`no-compilation-observed` 仅在日志完整、成功退出且有成功终止标记时表示未观察到已知编译头；其余 `unknown`。均不证明缓存命中。 |
| `source` | `raw-logs`、`captured-output` 或 `raw-logs+captured-output`。逐 stdout/stderr 选择原始 artifact 优先。 |
| `logCoverage` | `complete` 或 `partial`；捕获截断、短读、I/O 错误、超出扫描或单行限制均为 partial。 |
| `taskLogCounts` | 固定 key：`CompileC`、`CompileSwift`、`SwiftCompile`、`SwiftEmitModule`、`Ld`、`PhaseScriptExecution`。只计无缩进日志头，不计命令回显。不支持从 Swift 批处理头与单文件头中去重得到唯一任务数。 |
| `diagnosticCounts` | 有界固定类别：`build-description-signature`、`build-description-path`、`build-database-locked`、`build-database-malformed`、`stale-derived-data-outside-root`。只计数，不携带原文、签名值、目标名或私有路径。描述出现不等同描述改变。 |
| `stdoutLogPath` / `stderrLogPath` | 构建阶段原始 artifact 路径，便于 `xcode run` 后续阶段仍能追溯统计来源。 |
| `note` | 明确统计单位、去重限制和缺少基线，禁止由任意数量阈值推导 incremental 或 broad/full rebuild。 |

实现按 64 KiB 块读取原始日志，每流默认最多 128 MiB、每行最多 16 KiB。超限丢弃不完整行并标 partial，不修改原始日志。仅携带构建观察的 build/test/archive summary 及 run summary 消费这份统计；export 与 settings 不伪造构建观察。

复用判断采用保守策略：当前没有 Xcode task-cache hit 的官方结构化证据和同配置历史基线，所以不输出 `verified`、`incremental` 或 `broad-rebuild`。这满足 #212 的“暴露足够统计而不误报增量”路径，不能用于诊断私有工程发生大量重新编译的根因。
