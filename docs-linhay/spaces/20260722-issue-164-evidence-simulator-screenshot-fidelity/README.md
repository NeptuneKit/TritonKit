# GitHub Issue #164：Evidence Simulator Screenshot Fidelity

## 状态

- GitHub：[#164](https://github.com/NeptuneKit/TritonKit/issues/164)
- 状态：待发布
- Branch：`codex/20260722-issue-164-evidence-simulator-screenshot-fidelity`
- Worktree：`../TritonKit-worktrees/20260722-issue-164-evidence-simulator-screenshot-fidelity/`

## 背景

`triton evidence capture` 当前把 embedded runtime 生成的 App-layer screenshot 作为 evidence 的主截图。iOS 26 system-composited sheet 中，runtime hierarchy 仍能看到标题、关闭按钮、grabber 与底部搜索控件，但 runtime screenshot 会丢失这些 compositor 内容；同一时刻由 `triton sim screenshot` 采集的 Simulator framebuffer 则与用户所见一致。

#161 已修复 runtime screenshot 的 PNG 编码契约。本 issue 只处理视觉来源与 fidelity 语义，不回退 PNG 格式校验。

## 目标

1. iOS Simulator evidence 在可解析 host target 时，以 host-composited framebuffer 作为默认视觉验收截图。
2. 同时保留 runtime screenshot，显式标注 `scope`、`source`、`fidelity` 与用途，避免把 App-layer 图像误判为用户可见画面。
3. host screenshot 不可用时返回机器可读的 partial / skipped 事实与可执行 fallback，不能伪装成完整视觉成功。
4. 保持现有 Android、Harmony、真机与 runtime-only evidence 行为兼容。

## 非目标

- 不在 embedded runtime 内重做 iOS compositor。
- 不新增 Web/Wails 控制入口。
- 不依赖裸 `xcrun simctl` 作为 agent-facing 契约。
- 不修改 #161 已建立的 runtime PNG 格式契约。

## BDD 验收场景

### 场景一：iOS Simulator evidence 使用 host-composited 主截图

- Given 目标是带 `simulatorUDID` 的 iOS Simulator embedded runtime
- And evidence 请求包含 `screenshot`
- When 执行 `triton evidence capture`
- Then Triton 通过 host simulator adapter 采集 framebuffer PNG
- And manifest 的默认/首个 screenshot 代表用户实际看到的 host-composited 画面
- And artifact 明确标注 host simulator scope、source 与 full-screen fidelity
- And embedded runtime screenshot 仍以独立 artifact 保存并标注 app-layer fidelity

### 场景二：host screenshot 失败时不伪装完整视觉成功

- Given iOS Simulator target 可从 runtime identity 解析
- And host framebuffer 命令失败、超时或产物无效
- When evidence capture 收敛
- Then manifest 保留 runtime screenshot 但标记 non-fidelity / app-layer
- And host screenshot 进入 skipped 或 partial 结果
- And JSON 提供 `triton sim screenshot --simulator <udid> ... --json` 的可执行恢复命令

### 场景三：非 iOS Simulator 保持兼容

- Given target 不是 iOS Simulator，或缺少可靠 simulator identity
- When 请求 screenshot evidence
- Then 不猜测 host target
- And 继续采集原有 runtime screenshot
- And artifact 明确其 runtime/app-layer scope 与 fidelity 边界

### 场景四：PNG 契约不回归

- Given runtime 与 host screenshot 均成功
- When evidence 发布 artifacts
- Then `.png` 扩展名、`image/png` content type 与 PNG magic bytes 一致
- And manifest 不把 JPEG/JFIF 数据声明为 PNG。

## 验证计划

1. 先补 shared evidence model 与 CLI capture 红灯测试。
2. 跑 focused tests，最小实现 host/runtime 双来源与 fallback 契约。
3. 验证 `triton schema --command evidence --json` 与相关能力契约。
4. 在安全的 booted iOS Simulator 上执行 Triton-first smoke，保存 status/doctor/capabilities/schema/plan 与 evidence/host screenshot 结果。
5. 运行 `docs-linhay/scripts/verify.sh --local`、文档校验与 `git diff --check`。
6. 合并 main、等待 GitHub CI 通过后关闭 #164，并归档本 space。

## 实现结果

- shared evidence artifact 与 summary 新增可选 `scope`、`source`、`fidelity`，旧 bundle 解码保持兼容。
- iOS Simulator target 具备可靠 `simulatorUDID` 时，host adapter 先采集 Simulator framebuffer，发布为主 `screenshot.png`：`scope=host-simulator`、`source=simctl-framebuffer`、`fidelity=full-screen`、`visualAcceptance=true`。
- embedded runtime screenshot 同时保存为 `artifacts/runtime/screenshot.png`，artifact kind 为 `screenshot.runtime`，并标注 `scope=runtime-app-layer`、`source=embedded-runtime`、`fidelity=app-layer`、`visualAcceptance=false`。
- host framebuffer 失败时保留 runtime App-layer screenshot，但整体结果为 `failed-partial`，附加 `screenshot.host` skipped artifact、稳定错误码 `host_screenshot_unavailable`，以及 `triton sim screenshot --simulator <udid> --output <path> --json` 的结构化恢复动作。
- 非 iOS Simulator 或缺少可靠 simulator identity 时不会猜测 host target，继续发布带 App-layer 边界的 runtime screenshot。
- schema、恢复分类、敏感 artifact redaction 与 PNG 格式校验已同步覆盖双来源契约。

## 验证记录

- 红灯：shared evidence model 测试在 `scope`、`source`、`fidelity` 尚未实现时编译失败。
- `TKEvidenceModelsTests`：3/3 通过。
- `EvidenceBundleTests`：24/24 通过，覆盖 host 主截图、runtime 独立 artifact、host 失败 fallback、非 iOS 不猜测与 schema/redaction 契约。
- `SchemaFactSourceContractTests`：50 项中 44 项通过；本 issue 新增的 failure code 与恢复分类已通过，剩余 6 项均为既有 `device` selector/subcommand 与 `sim app-console` recovery 契约债务。
- 权限恢复后的完整根 Swift 包：231/231 通过；此前 localhost sandbox `EPERM` 不再复现。
- release `triton` CLI 构建成功，evidence schema / validation smoke 通过；public skill package、`check-docs.sh` 与 `git diff --check` 通过。
- 原样 `docs-linhay/scripts/verify.sh --local` 在权限恢复后完整通过：SwiftPM dependency boundary、iOS DEBUG isolation、231 项 Swift tests、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs 与 diff 门禁均为绿灯。
- Triton-first 真实 Simulator smoke：`triton sim list --json` 发现 booted Simulator；`triton sim screenshot --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --output /private/tmp/triton-issue164-host-20260723-01.png --json` 成功返回 1206×2622 PNG、`runtimeScope=host-simulator` 与可审计 source command。
- Triton-first 真实 evidence smoke：启动本机 `triton serve` 后连接到带 `simulatorUDID` 的 iOS runtime，`evidence capture --include list,screenshot` 把 187271-byte host framebuffer 发布为主 `screenshot.png`，manifest 明确 `scope=host-simulator`、`source=simctl-framebuffer`、`fidelity=full-screen`、`visualAcceptance=true`。连接 App 仍返回旧 JPEG runtime screenshot，因此 runtime 辅助 artifact 按 PNG 契约被拒绝为 `artifact_write_failed`，bundle 为 failed-partial，但 host 全屏主 artifact 保持有效；runtime PNG 成功分支由 `EvidenceBundleTests` 直接覆盖。
- 项目内部 host-simulator skill、public skills 与长期技术文档均已同步；尚待提交/推送、main CI、GitHub issue 关闭与 space 归档。
