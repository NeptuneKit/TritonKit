# SP-130 Issue #166 Runtime JPEG Normalization

> 状态：已发布（v0.2.16）；GitHub #166 已关闭，SP-149 follow-up 已由 PR #177 合并
>
> Branch：`feat/SP-130-issue-166-runtime-jpeg-normalization`
>
> 基线：`codex/sp126-trusted-baseline-integration@2fddf6a0`

## 目标

修复 iOS real-device 的旧 embedded runtime 返回有效 JPEG 时，CLI 将其作为 PNG artifact 拒绝并丢弃的 #166。`triton screenshot`、PNG-契约的 evidence capture、replay screenshot 与 test-run observation 必须在声明格式和 magic bytes 一致时，将 JPEG 解码并规范化为真实 PNG 后再原子发布。

## 裁决

- Adopt：JPEG -> PNG normalizer，而不是新增 JPEG output mode 或仅保留 raw JPEG。
- 原因：#166 的公开 `screenshot --output <path.png>` 契约和 evidence/replay/test-run 的 PNG/MIME/metadata 契约已经存在；只把原始 JPEG 写为 `.jpg` 会让真实 evidence capture 仍失败，并制造第二条 artifact 语义。
- 不做：不修改 embedded runtime encoder、不改变 `/web/screenshot` 的既有真实格式透传、不扩展 Web/Wails、testrec、Android、设备云或第二 evidence writer。

## #164 隔离

`20260722-issue-164-evidence-simulator-screenshot-fidelity` 的 dirty worktree 继续只读隔离：不 merge、cherry-pick、reset、删除或修改。SP-130 只从已验证 integration 基线编辑自己的同名文件；若未来需要整合 #164 WIP，由用户单独裁决。Simulator host framebuffer 的 full-screen 主图和 runtime App-layer 副图语义必须保持不变。

## BDD

### 场景 1：CLI screenshot 正规化有效 JPEG

Given embedded runtime 声明 `jpeg` 且返回可解码 JPEG magic bytes

When 用户执行 `triton screenshot --output <path.png> --metadata`

Then CLI 原子写出真实 PNG bytes

And metadata `format` 为 `png`

And 不会发布 JPEG bytes、`.png` 扩展名或 `image/png` MIME 的伪 artifact。

### 场景 2：evidence 与执行器保留同一 PNG contract

Given legacy JPEG runtime screenshot 被 evidence capture、replay screenshot 或 test run observation 消费

When 这些路径需要 PNG artifact

Then 使用同一 normalizer 写出 PNG

And evidence 的 scope/source/fidelity、replay 的 content type、test run observation 哈希继续指向实际 PNG bytes。

### 场景 3：坏数据仍 fail closed

Given 声明和 magic bytes 不一致、未知格式、无效 JPEG 或输出不是 `.png`

When CLI 尝试发布 PNG artifact

Then 返回单一 `artifact_write_failed` envelope

And 不发布任何 output artifact。

## 验收与停止条件

- 先写 valid-JPEG red fixture，再实现最小 ImageIO normalizer。
- 运行 ObservationOutput、EvidenceBundle、ReplayCommand、TestRunExecution 与匹配 schema tests，全部使用独立 scratch，串行执行。
- 不启动真实 device、Simulator、Xcode build、`triton serve` 或 Bonjour；只用 fake runtime/fixture 测试。
- 若 macOS ImageIO 不能生成可验证 PNG，或修复必须更改 embedded SDK / #164 dirty worktree / Web 写控制面，则停止并报告。
- 完成后写回本 README、spaces README/INDEX、memory，并仅创建本地 checkpoint；不 push、PR、merge、tag、release 或关闭 issue。

## 实现与验证记录

- 中央 `normalizeRuntimeScreenshotToPNG` 先校验 declared format 与 magic bytes；PNG 保持原字节，合法 JPEG 通过 ImageIO 解码并重编码为真实 PNG。输出不是 `.png`、声明/字节不一致、未知格式或不可解码 JPEG 均 fail closed。
- direct `triton screenshot`、evidence capture、replay screenshot、test-run observation/failure screenshot，以及 HTTP `/screenshot` 都在声明 `image/png` 或 `.png` artifact 前调用这一个边界。`/web/screenshot` 与 Web bridge 继续按真实格式返回 JPEG/PNG，不被本切片重写。
- evidence metadata 对规范化后的 JPEG 记录 `format=png`、实际 PNG bytes，并清空指向旧 JPEG 的 runtime `dataRef`；test-run 的 source metadata artifact bytes 也改为实际写出的 JSON 长度。
- TDD：先以缺失 `normalizeRuntimeScreenshotToPNG` 的编译失败记录 red；随后 `ObservationOutputTests` 覆盖合法 JPEG->PNG、PNG 原样通过、输出扩展拒绝、坏 JPEG 与稳定 `artifact_write_failed` 映射。`EvidenceBundleTests` 以 `dataRef` 返回的 JPEG 回归验证 artifact magic、manifest bytes 与 metadata。
- 串行验证通过：`ObservationOutputTests` 15/15、`EvidenceBundleTests` 25/25、`TestRunExecutionTests` 9/9、`SchemaFactSourceSurfaceContractTests` 4/4、`FailureDiagnosticsTests` 13/13、`ServeCommandTests` 6/6；`ReplayCommandTests` 13/13（显式 `TRITON_CLI_PATH` 指向本 worktree 的独立 debug artifact，避免测试自身硬编码 `CLI/.build`）。release `triton` 在独立 scratch 编译通过，`schema --command screenshot --json` 显示 JPEG normalizer 文案。
- `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 通过：dependency boundary、DEBUG isolation、根包 231 tests、release CLI smoke、fake Harmony host smoke、loopback iOS runtime observe smoke、docs structure 与 diff whitespace 均成功；Xcode 的真实构建按本切片边界显式跳过。
- 未启动真实 device、Simulator、Xcode build、`triton serve` 或 Bonjour。真实 iOS runtime smoke 仍留给后续 canonical proof；本 slice 的 fixture 证明只限于 CLI contract 与本地 artifact 语义。
