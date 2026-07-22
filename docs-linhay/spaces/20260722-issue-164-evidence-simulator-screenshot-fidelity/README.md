# GitHub Issue #164：Evidence Simulator Screenshot Fidelity

## 状态

- GitHub：[#164](https://github.com/NeptuneKit/TritonKit/issues/164)
- 状态：执行
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

