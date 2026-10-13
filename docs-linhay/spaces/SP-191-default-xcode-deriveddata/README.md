# SP-191 — 默认使用 Xcode 全局 DerivedData

## 范围

将 TritonKit Xcode 工作流的默认构建缓存从仓库内 `.triton/DerivedData` 切换为 Xcode 默认的用户级 DerivedData 目录。`--derived-data-path` 保留为显式隔离、复现或恢复入口，并在 CLI/schema/文档中明确：该参数会把构建产物写入指定目录，可能造成高磁盘占用，非必要不要启用。

本 space 只覆盖 CLI、shared Xcode DTO、DerivedData inspect/cleanup 契约、测试和文档；不扩展 Web/Wails、HTTP 控制面或发布流程。

## BDD 与验收

- Given 未传 `--derived-data-path` 且没有旧 workspace 默认值，When 执行 Xcode settings/build/test/run/archive 或 `build ios`，Then Triton 不向 `xcodebuild` 传 `-derivedDataPath`，由 Xcode 使用默认用户级 DerivedData。
- Given 已保存的旧 `.triton/DerivedData` workspace 默认值，When 重新解析 Xcode invocation，Then 将其视为历史默认并回落到 Xcode 默认目录；显式传入 `.triton/DerivedData` 仍保持用户意图。
- Given 显式传入 `--derived-data-path <path>`，Then Triton 传递该路径并在 summary/cache metadata 中标记为显式覆盖。
- Given schema/help/README/skill 文档，Then 明确 `--derived-data-path` 默认不启用、可能造成高磁盘占用，只有隔离或恢复时才使用。
- Given `derived-data inspect/cleanup`，Then 默认 root 使用用户级 Xcode DerivedData；repo-local `.triton/DerivedData` 仍可作为显式 legacy root 检查，但不会再是默认缓存。
- Given 显式使用 `.triton/DerivedData` 且该缓存可能占用过大，Then `derivedDataCache.guidance` 提醒 agent 先询问用户是否清理，并给出 inspect 命令；不得自动删除。

## 验收边界

- 默认路径行为由 focused CLI/shared tests 锁定；命令构造测试确认默认不含 `-derivedDataPath`，显式覆盖仍含该参数。
- JSON/schema 的 `derivedDataPath` 在默认模式下为空/缺省，`derivedDataCache.path` 指向用户级 Xcode DerivedData 根，避免把“Xcode 默认策略”误报成仓库路径。
- 验收阶段仅运行本地测试和文档门禁；不自动删除现有 `.triton/DerivedData`，不执行用户全局缓存清理。远端提交与发布按后续发布流程单独执行。
