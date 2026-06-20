# 20260621 Issue 73 Evidence Ingest

## 背景

GitHub issue #73 需要为业务 App 自己产出的结构化 evidence JSON 提供一个最小、schema-backed 的离线导入入口。该入口用于把 App 侧生成的结构化证据纳入 Triton `.tritonevidence` bundle，便于 agent 后续统一 inspect / summary / redact / handoff，而不是要求 evidence 只能由 Triton runtime 在线采集。

本期不做通用 artifact registry、复杂 schema 校验器或多文件批量导入，只实现一个可回归的小切片。

## 范围

- 新增或扩展现有 `triton evidence` CLI 离线动作，支持导入单个 JSON artifact。
- 输入 artifact 必须是合法 JSON 文件。
- 可选 schema 文件也必须是合法 JSON；导入时记录 schema 路径、字节数与 SHA-256，作为 manifest artifact metadata。
- 输出目录必须是 `.tritonevidence` bundle，包含 `manifest.json` 与复制后的 JSON artifact。
- manifest 的 `artifacts` 与 `primaryArtifacts` 必须体现导入 kind。
- artifact 默认按 app 结构化证据处理为 sensitive / included 前状态，即导入包内标注 `redactionStatus: "sensitive"`，便于后续 `evidence redact` 安全处理。
- schema 中必须可发现该 ingest 入口、关键参数、输出契约与 artifact kind。

## 非范围

- 不实现 JSON Schema draft 校验。
- 不支持多 artifact 批量导入。
- 不要求连接 runtime server。
- 不新增 Web / Wails UI。
- 不推送、不关闭 GitHub issue。

## BDD 场景

### 场景 1：导入有效 app structured evidence JSON

Given 一个合法 JSON artifact 文件
And 调用 `triton evidence ingest --file <artifact.json> --kind app.structured-evidence --output <dir.tritonevidence> --json`
When 命令成功
Then 输出目录包含 `manifest.json` 与复制后的 artifact JSON
And manifest `artifacts[0].kind` 为 `app.structured-evidence`
And manifest `primaryArtifacts[0].kind` 为 `app.structured-evidence`
And artifact `sourceCommand` 记录 `triton evidence ingest --file <file> --kind app.structured-evidence`
And artifact `redactionStatus` 为 `sensitive`。

### 场景 2：导入时记录可选 schema metadata

Given 一个合法 JSON artifact 文件
And 一个合法 JSON schema 文件
When 调用 `triton evidence ingest --file <artifact.json> --schema <schema.json> --kind app.structured-evidence --output <dir.tritonevidence> --json`
Then manifest 中导入 artifact 的 metadata 包含 schema path、schema SHA-256 与 schema bytes。

### 场景 3：输入文件不存在或不是合法 JSON 时失败

Given `--file` 指向不存在文件或无效 JSON
When 调用 `triton evidence ingest ... --json`
Then 命令以失败退出
And 输出单个 JSON 错误 envelope，code 为 `validation_failed`。

### 场景 4：schema 可发现

Given agent 调用 `triton schema --command evidence --json`
Then evidence 命令描述中包含 `ingest --file <path> --kind <kind> --output <dir>`
And artifacts 包含 `app.structured-evidence`
And output contract 暴露 artifact metadata / schema hash 字段。

## 验收

- 先补失败测试，再实现。
- 聚焦 Swift tests 覆盖有效 JSON、无效文件/无效 JSON、schema 可发现。
- 运行 `git diff --check`。
- 运行 `docs-linhay/scripts/check-docs.sh`；若脚本在当前分支不存在，记录替代校验。
- 更新 `docs-linhay/memory/2026-06-21.md`。
- 创建本地 commit，不 push。

## 进度记录

- 2026-06-21：创建 space，确定最小实现形态为 `triton evidence ingest` 离线动作。
- 2026-06-21：补齐红灯测试与最小实现：JSON artifact 复制到 `artifacts/<kind-slug>/`，manifest 记录 schema bytes / sha256 / path metadata，schema 暴露 ingest 入口与输出字段。
