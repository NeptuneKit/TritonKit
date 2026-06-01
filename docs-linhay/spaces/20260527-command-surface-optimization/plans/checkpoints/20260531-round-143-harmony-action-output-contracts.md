# Round 143: harmony action output contracts

## 目标

补齐 Harmony host-side action 成功输出的 schema contract，避免 agent 只能从 `successShape` prose 判断 `tap/swipe/type/paste --platform harmony` 的 JSON 字段。

## 变更

1. 新增 `host.harmony-tap` output contract：
   - model: `HostHarmonyTapOutput`
   - kind: `host-action`
   - 覆盖 `query/x/y/match/sourceCommands/note`
2. 新增 `host.harmony-swipe` output contract：
   - model: `HostHarmonySwipeOutput`
   - kind: `host-action`
   - 覆盖 `startX/startY/endX/endY/velocity/sourceCommands/note`
3. 新增 `host.harmony-text-input` output contract：
   - model: `HostHarmonyTextInputOutput`
   - kind: `host-action`
   - 覆盖 `x/y/secure/redacted/insertedLength/sourceCommands/note`
4. `tap` / `swipe` / `type` / `paste` schema 继续保留 embedded `input.result` contract，同时注册各自 Harmony host output contract。
5. 三个 public skills 同步说明：`tap/swipe/type/paste --platform harmony` 应读取 `host.harmony-*` output contract，不要套用 embedded `input.result` parser。

## 验收

1. `triton schema --command tap --json` 同时暴露 `input.result` 和 `host.harmony-tap`。
2. `triton schema --command swipe --json` 同时暴露 `input.result` 和 `host.harmony-swipe`。
3. `triton schema --command type --json` 同时暴露 `input.result` 和 `host.harmony-text-input`。
4. `triton schema --command paste --json` 同时暴露 `input.result` 和 `host.harmony-text-input`。
5. 所有新增 contract 满足现有 selector、kind、model 和 field type taxonomy。

## 验证

已通过：

```text
swift test --package-path CLI --filter SchemaFactSourceTests
git diff --check
docs-linhay/scripts/check-docs.sh
docs-linhay/scripts/qmd-sync.sh
qmd query "Round 143 harmony action output contracts"
```

## 风险

本轮只补 schema contract，不改变 Harmony HDC action 运行时输出，也不扩大 embedded runtime action 能力。

## 下一步

继续检查 host-side wait / smoke / app open-url 等多 envelope 命令是否还有 prose-only 输出分支。
