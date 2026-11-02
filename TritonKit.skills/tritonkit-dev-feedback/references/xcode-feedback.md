# Xcode feedback

For Xcode compatibility findings, preserve `triton device doctor --platform ios --scope all --json` and its `commandSupport`: `help-advertised-only` verifies advertised flags, not successful device actions. Report selected-toolchain runs separately from legacy JSON/help fixtures; never infer old-Xcode execution or retry a failed write through another backend.

If the user defines Xcode26 support as retaining existing commands, verify registrations/argument forms without demanding another SDK installation. Authorized isolated action checks must create and record a new task-owned Simulator, not reuse a shutdown business/default device. For install timeouts, preserve the failure and inspect app info/list before recovery: timeout does not imply no side effect. `xcode run --timeout` should reach Simulator install/launch as well as build/settings; no override retains legacy defaults. Host lifecycle acknowledgements and black screenshots are not UI/business success.

## Build output and cache contracts

- `xcode test --jsonl` 默认 compact；完整 raw 日志在 artifact，显式 `--progress full` 才转发。按子命令 schema 选参数，`xcode run` 不接受 `--progress`。
- DerivedData 存在不证明 cache 命中。`reuseVerification=unknown`，`incrementalExpected=false` 仅表示没有验证过的预期；读取 `observedBuild.taskLogCounts/logCoverage`，不擅自称增量或全量。
- 默认不传 `--derived-data-path`，由 Xcode 使用用户级 DerivedData。该参数必须显式指定，只用于隔离或恢复，可能造成高磁盘占用，非必要不要开启。排查构建缓存用 `triton xcode derived-data inspect --json` 或 `cleanup --json` 预览；`.triton/DerivedData` 只能作为显式 legacy root。Triton 不提供 DerivedData 删除；通用自动删除需求已撤出范围。兼容参数 `--confirm` 在删除前返回 `derived_data_cleanup_unavailable`，活动 Xcode lane 保留 `xcode_not_idle`；等待空闲不会启用删除，不建议重试 confirm。若用户另行要求人工清理，先只读检查并明确该独立操作范围，不自动回退手工删除。统计为逻辑文件字节和修改时间，不是可回收磁盘量或最后使用时间；只接受精确 `.triton/DerivedData` 根或用户全局根，symlink 目标不跟随。

`triton xcode ... --package <Package.swift-or-directory>` 的相对 `--derived-data-path` 按 package 工作目录解析并在 invocation/cache 元数据中给出绝对路径；`xcode test --result-bundle <relative>` 同样按 package 工作目录规范化，执行命令、inline xcresult parser 和最终 `resultBundlePath` 共享该位置。绝对路径保持不变；非 package 工作流保留调用目录语义。
