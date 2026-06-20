# 20260621 Issue 76: Simulator media fixture seed

## 背景

Issue #76 要求为 iOS Simulator 提供一个机器可读的媒体 fixture 导入小切片。TritonKit 需要把 Apple 的 `xcrun simctl addmedia` 收敛在 `triton sim` 合约后面，供 agent 通过 schema 发现、通过 JSON 输出审计，而不是直接暴露裸 `simctl`。

## 目标

- 新增 `triton sim media seed --manifest <file> --simulator <udid|booted> --json`。
- manifest 最小字段包含 `fixtureId` 与 `files[]`。
- `files[]` 支持字符串路径，路径相对 manifest 所在目录解析，便于 fixture 目录整体迁移。
- 输出包含 `fixtureId`、导入数量、manifest path、`sourceCommand`、artifacts 与 metadata。
- `triton schema --command sim --json` 能发现该命令、参数、能力、失败码与输出合约。

## 非目标

- 本期不实现 `media list` / `media reset`。
- 本期不管理 Photos 权限弹窗或业务 App 内部相册读取结果。
- 本期不新增 Web/Wails UI，不把媒体导入作为前端业务控制入口。

## BDD 场景

### 场景 1：从 metadata manifest 导入媒体 fixture

Given 一个 manifest：

```json
{
  "fixtureId": "onboarding-gallery",
  "files": ["photos/welcome.png", "videos/intro.mov"]
}
```

When agent 执行：

```bash
triton sim media seed --manifest /fixtures/gallery/manifest.json --simulator booted --json
```

Then Triton 解析 manifest，将相对文件解析为 manifest 目录下的绝对路径，并通过内部 host adapter 执行：

```bash
xcrun simctl addmedia booted /fixtures/gallery/photos/welcome.png /fixtures/gallery/videos/intro.mov
```

And JSON 输出至少包含：

- `ok=true`
- `action=sim.media.seed`
- `fixtureId=onboarding-gallery`
- `importedCount=2`
- `manifestPath=/fixtures/gallery/manifest.json`
- `sourceCommand` 为经过 Triton 封装的 addmedia 命令
- `artifacts[]` 包含 manifest 和每个源媒体文件
- `metadata.fixtureId`、`metadata.files[]`

### 场景 2：schema 可发现媒体导入能力

Given agent 需要判断当前 CLI 是否支持媒体 fixture 导入

When agent 执行：

```bash
triton schema --command sim --json
```

Then schema 中包含 `media seed --manifest <path>` 用法、`--manifest` 参数、`sim-media-seed` 能力、`media_seed_manifest_invalid` 失败码和 `host.simulator-media-seed` 输出合约。

### 场景 3：manifest 不完整时不触碰 Simulator

Given manifest 缺少 `fixtureId` 或 `files[]` 为空

When agent 执行 `triton sim media seed --manifest <file> --json`

Then Triton 返回 `ok=false` 与稳定错误码 `media_seed_manifest_invalid`，并且不调用 `simctl addmedia`。

## 验收

- Shared 测试覆盖 manifest 解码、相对路径解析、空文件列表拒绝、`TKSimctlCommand.addMedia` argv。
- CLI 测试覆盖 `sim` schema 暴露媒体 seed 命令与输出合约。
- focused Swift tests 通过。
- CLI build 与 `triton schema --command sim --json` 通过。
- `git diff --check` 与 `docs-linhay/scripts/check-docs.sh` 通过。

## 风险与后续

真实 `simctl addmedia` 会修改目标 Simulator Photos/Media library，且结果可能受本机 Photos/Simulator 状态影响。本期默认以 parser、command planning、schema 与 CLI build 验证为主；如没有明确安全的 booted simulator fixture，不宣称真实 Photos smoke 已完成。

## 进度记录

- 2026-06-21：补齐 manifest 模型、`TKSimctlCommand.addMedia`、`triton sim media seed` CLI、schema 输出合约与 focused tests。
- 2026-06-21：未做真实 booted simulator Photos smoke；本期验证限定在 parser / command planning / schema / build 级别。
