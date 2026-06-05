# Round 96: compatibility wording cleanup

## 目标

把 agent-facing CLI 当前契约里的 `compatibility` / `legacy` 口径从 help、schema、README 和随包 public skills 中清掉，避免继续向 agent 暗示项目需要维护旧入口兼容层。

## 完成内容

1. README 的 Harmony `device runtime-url` 示例改成“已知原始 HDC target 时可直接传 `--target`”，不再称其为 compatibility path。
2. CLI help 文案改为显式 selector 语义：
   - `--simulator` 改为显式 iOS selector；
   - `--target` 改为显式 Harmony/raw target selector；
   - `observe.*` / `screenshot` / `hit --x/--y` 改为当前执行语义，不再写 compatibility pair/path。
3. Schema 文案同步改为显式 selector / raw-target 表述，移除 `compatibility default`、`compatibility selector` 等说法。
4. host 侧参数冲突 hint 改为“统一用 `--device`，或只选一种显式 selector 路径”，不再提 legacy path。
5. `type --text` / `press --button` 改成 alternate flag form 表述，保留当前行为但不再宣称其是兼容旧脚本的负担。
6. public skills `tritonkit-dev-feedback`、`tritonkit-emulator-cli-takeover`、`tritonkit-real-project-regression` 同步改成：
   - `--device` 是默认 agent-facing selector；
   - `--simulator` / `--target` 只是显式 selector form；
   - `steps[].command` 是 human-readable/logging form，不再称 legacy alias。
7. CLI 测试命名同步改成 explicit selector / mixed selector conflicts 口径。

## 验证

- `swift test --package-path CLI --filter DeviceCrossPlatformTests`：通过，16 个 Swift Testing 用例通过。
- `swift test --package-path CLI --filter SchemaFactSourceTests`：通过，77 个 Swift Testing 用例通过。
- `rg -n 'compatibility path|kept for compatibility|legacy/logging alias|compatibility with older scripts|legacy selector' README.md Sources CLI TritonKit.skills docs-linhay/spaces/20260527-command-surface-optimization -g '!**/.build/**'`：无命中。

## 风险

1. 本轮只清理对外契约口径，没有删除 `--simulator`、`--target`、`--text`、`--button` 等现存 selector / alternate form 行为。
2. 仍有历史计划、memory 和研究型文档保留“no compatibility burden”决策表述；这是治理事实，不属于 agent-facing 使用口径污染。

## 下一步

1. 继续 Round 94 的 schema-backed `steps[].argv` 校验 helper，把 plan/replay 的执行事实源进一步从 `command` 字符串迁走。
2. 若后续决定真正删除显式 selector alternate forms，需要单独做一轮行为裁剪，并同步 schema、skills、README、tests 和 release 说明。
