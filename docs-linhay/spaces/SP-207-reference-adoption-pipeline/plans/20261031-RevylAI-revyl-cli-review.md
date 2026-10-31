# Revyl CLI 2026-10-31 固定增量审阅

裁决 observe，无新采用切片。CLI/HTTP/shared contract层只读取证完成；完整性仅指允许文本增量，总体仍 partial，不推进成功检查点。

## 来源和覆盖

官方 [base b6194f9](https://github.com/RevylAI/revyl-cli/tree/b6194f927fc3550fbd8144c56db313787e468b29) → [head 34a9587](https://github.com/RevylAI/revyl-cli/tree/34a9587752f06cdc41cfce7acd46d408c8f799e8)。分页commits每页100，首批遇base后终止，共8提交；对每个实际父边分别读tree（8边/9树），全部truncated=false。父边union43路径；先按用途/文本白名单筛选，38文本路径、84安全blob完整采集并校验Git SHA-1。`path-screening.json`记录每边before/after SHA，`texts/`和`blob-*.json`保存全文，`diffs.txt`保存允许文本增量。未请求含patch的compare/commit全响应。

4个pyc、无扩展名VERSION只记tree元数据，不获取内容。许可证API仍404，README/PyPI的MIT字样不能代替全文，hash保持null；历史hosted backend/分发来源缺口没有独立恢复证据。不得将允许文本完成解释为仓库完整。

[官方v0.1.204 notes](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.204)全文在`release-notes.txt`，本次依既有两页完整release列表；notes只有安装、skill、独立computer/checksum指南。head源码README/npm/python已为0.1.206，不将其当已发布latest或替换已固定release结果。未下载或执行release产物。

## 主要机制及差距裁决

- **Session accepted不等于device ready**：`device_session.go`新增可空device_ready，只有connected health才为true；读取health失败/坏JSON现在报错，最多15次等待后仍可返回session但ready=false。CLI/interactive改为等init事件再宣称ready；MCP指引先检查连接，viewer标题不再冒充设备已就绪。实际main `CLIHostDeviceRuntime.swift`已将设备存在、Android get-state、boot_completed、PackageManager就绪分开探测，返回ready=false或明确失败；WorkspaceActionExecution保持unknown/not_started不当成功，SP-192/196及已合入的Android readiness修正不重复排期。本地没有Revyl worker/session accepted通道，不能直接套字段。
- **测试远端sync批量查询**：`internal/sync/resolver.go`对规范UUID以100项批次请求get_test_info_batch，omit_missing保留孤儿状态，400/404才回退独立查询；其他错误保留明确错误，401/403保持权限语义。此路径服务托管测试库/组织授权，Triton没有对应远端同步产品面，通用减少round-trip不是当前本机缺陷证据。
- **Web build预算与上传**：managed Web打包从200MiB改1GiB，分别限制压缩/解压流并纳入tar header字节；错误区分entry/unpacked/compressed，增加focused测试。上传按文件大小给单次timeout并受2h预签名URL生命周期总预算限制，重试复用URL。Triton Web仅mock且没有云上传；本机SP-200 ZIP/IPA入口`CLIAppArchiveRuntime.swift`已独立限制archive/expanded/file/entry、禁止symlink/特殊路径并核对inflate字节，不借此放宽既有预算或新增托管上传。
- **Schema与Proof模型**：batch lookup、computer source_metadata、build促销/资格/计费枚举、Revyl harness可选model allowlist等均为托管服务DTO。`schema-diffs.json`以结构化完整键值保存两种schema全部变化；generated Go对应同步。没有本机source需要补齐的协议。
- **Dev-loop skill重写**：三个发行入口压缩为从真实app目录选profile、保存context/session、查看build完成、动作后validation与截图、按原context停止；viewer与旧build不能证明新改动已ready。机制与Triton-first、SP-192视觉稳定不当业务验证、SP-196证据链、SP-200目标绑定既有原则一致。manifest仍包含历史runtime固定版本，不把插件版本变化误认当前二进制来源闭合。Python/npm仅版本同步，uv.lock各步仅revyl自身版本变化，详见lock-diffs.json。

## main去重与未运行边界

比较实际`main@1139db7712d485c0927282a4415ac45765567332`固定blob，不把当前跟踪WIP当作产品实现；`local-main/`保存相关源码和SP-192/196/200原文，`adoption-snapshot.json`用于去重。当前主目录main、worktree清单和已有WIP已核对且未修改。

没有新增实现/BDD开发切片，所以未运行第三方代码、依赖、构建、测试或设备动作；上游测试只是阅读证据，不是本地通过。沿用reference-project-adoption-workflow既有安全读取与partial规则，无新增治理经验；正式文档、state、memory仅由主控统一写回。本子任务只写专属证据目录，result.json保持原样。
