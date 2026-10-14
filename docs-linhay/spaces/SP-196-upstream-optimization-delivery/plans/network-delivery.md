# Network capture 完整性与 URL 脱敏

影响层：CLI host proxy 的 metadata capture / export 与 .tritonevidence 接入。保持 header names-only、TLS 不解密、不扩大 body 采集。真实转发与 mock 匹配保留原请求值。

## BDD

- 空文件、非法 UTF-8、坏 JSON、无 newline 的半条、未知 schema、超过字节/单行/记录数上限时，summarize/export 必须失败，既有输出保持原字节。
- 合法旧 capture 在新的 NDJSON/HAR 导出中去掉 URL userinfo、query、fragment；现有请求落盘、JSONL eventWriter 同样脱敏；不修改 upstream forwarding 或 policy matching。
- 完整读取的 event 数、request 数、failure 数与 HAR `_triton` 统计来自同一次验证数据。
- 旧 `triton.network.v1` 零计数空 events placeholder 只表示 `not-observed`，混合来源表示 `partial-source`；不伪装为完整实测流。
- capture append 达到 64 MiB 硬上限后保留原 capture 并落私有 `.incomplete` marker，后续导出 fail closed。禁止将限额内前缀认作完整流。

## 实现

- `CLIHostNetworkCaptureIntegrity.swift`：按 32 KiB 分块，最多 64 MiB / 256 KiB 单行 / 100,000 条，拒绝非 regular/symlink final source，shared 文件锁；只接受已知 event schema 与严格旧 placeholder。
- `CLIHostDeviceProxyServer.swift`：完整验证后原子导出；HAR `_triton` 附统计与完整性；append owner-only 创建、nofollow、exclusive lock、容量 marker。readback 跟写入锁串行，仍不声明对不遵循锁的外部生产者有原子快照保证。
- `exportNetworkProxyCaptureArtifactWithSummary` 给 session export 一次验证的数据与 summary；generic evidence capture 需读 validator 数据，由主控接线。
- 默认 redaction 变为 `headers-names-only,url-credentials-query-removed`；placeholder 保持 `default`。此脱敏不意味着设备身份或 URL path 全面可公开，generic evidence 仍标 sensitive。

## 验证

- 基线反例通过 `git HEAD` 提取原函数独立执行复现：空文件、非法 UTF-8、坏 JSON 均返回 `truncation=none`（`.build/sp196-network-baseline.log`）。
- 新核心独立编译运行通过：原事件 URL 凭据/query 清理，空/非法 UTF-8/JSON/半条拒绝、容量限制、原前缀不改、incomplete marker阻断（`.build/sp196-network-core.log`）。这不替代 CLI 整合测试。
- 新 focused tests `NetworkCaptureIntegrityTests` 覆盖上限/原输出保留/完整性统计/placeholder/落盘/符号链接/目录，CLI 独立 scratch `.build/sp196-network`。
- CLI 首两次整合构建失败来自 resize worker 处理中间态（probe type 暂缺与默认参数循环引用）；第三次增量构建在主控接线 screenshot helper 前失败于该 helper 暂缺。网络文件无 compiler error；最终整包 focused 测试待主控统一验证，当前不标通过。
- 真实设备/真实 app/外部 proxy 流量：未执行；无 TLS/body 场景，retention 清理未新增，只有显式 capture 容量边界。


## 整合 fixture 修正

主控完整 CLI 回归发现四处旧 evidence/replay proxy fixture 只写任意 JSON subset，缺 `schemaVersion`/必要 event 字段/newline；新 reader正确拒绝它们，未放宽契约。已将 EvidenceBundleTests 的直接导入/argv导入/三平台导入与 ReplayCommandTests 的失败归档 fixture 改为通过真实 `parseNetworkProxyHTTPHeader` 生成完整 event并NDJSON换行；保留 artifact、argv、platform、target 断言。GET fixtures额外携带URL凭据/query，导入产物必须不含凭据、token值和用户名；CONNECT保持真正CONNECT语义。修正后受影响focused tests由主控复测。

## 主控最终验证

主控最终CLI完整回归通过，严格reader及修复后的Evidence/Replay夹具无失败。未运行客户代理或扩展采集范围。
