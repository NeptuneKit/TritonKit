# #210 实现审计报告

日期：2026-09-08。影响层：CLI Xcode 进度、最终结果与 schema；保留既有提交 `396c0088`，本次审计修改尚未提交。

## 发现与修复

1. 原进度 runner 在进程退出后取消 `readabilityHandler`，但已经开始执行的回调仍可写日志/发事件。失败基线保存了 5,357,568 / 5,400,012 bytes，缺失尾部标记；20 条 error 仅在函数返回前捕获 4 条。改为调用线程上的非阻塞双流读取，每轮有界读取并检查 timeout/heartbeat；完成前同步读取剩余管道数据，不再有回调越过最终摘要。
2. 原 schema 测试匹配 `Unknown option` 字符串，而实际错误是 `unknownOption`，因此漏掉 build 的 `--env/--arg`。现在每个声明参数都携带有效必填参数，并要求真实 parser 成功；删除 build 的两项错误声明，保留 run 支持。
3. 既有 inline xcresult 只限制失败数量，单条失败文本和 summary 数组可能很大。新增默认脱敏之后的内联限制：最多 3 条失败、每字符串最多 2000 UTF-8 bytes、每个 DTO 总文本预算 8192 bytes（均不含截断标记），每数组最多 8 项；优先保留 result/status 与失败名称/信息，数值计数保持原值，`xcresultNote` 说明截断与完整查询命令。
4. `CLIXcodeRuntime.swift` 原 1604 行；将结果/产品解析与摘要输出移到 `CLIXcodeResultRuntime.swift`，原文件降到 1488 行。缓存相关实现未改动。

## 验证

独立 scratch：`.build/issue210-audit`，构建 jobs=4，未启动设备、服务或真实 Xcode workspace。

- 红灯：收紧的 progress/schema 测试复现日志丢失及不支持参数；长文本/数组测试有 4 条失败断言，确认原实现未设体积限制。
- `swift test --package-path CLI --scratch-path .build/issue210-audit --skip-build --filter XcodeProgressTests`：12 项通过。
- `swift test --package-path CLI --scratch-path .build/issue210-audit --skip-build --filter 'Xcode|Xcresult' --no-parallel`：89 项、6 套件通过，包含 timeout、完整 5.4 MB 日志、compact 事件/字节上界、默认/full 参数与内联结果。
- 默认并行组合运行曾出现 Swift Testing 自身日志混入 stderr 捕获，表现为非 JSON 字符；使用 `--no-parallel` 后所有相关测试通过。未放宽日志字节或诊断数量断言。

## 验收边界

尚未执行真实大型私有 workspace 与真实 `.xcresult` 回归；当前证据来自进程 fixture、注入 runner 和 parser/schema 测试。完整 CLI suite、主控索引/memory/skill 同步与 GitHub issue 最终状态由主控负责；本 worktree 不做远端写入。

## 主控全量门禁的补充修复

- Xcode archive/export 实现与 schema 已存在，但能力矩阵遗漏二者。补注册、xcode 分组、project/xcode/evidence 依赖元数据、host-artifact 证据和带必填参数的可解析下一步；未修改 WebView provider 区段。
- schema artifact taxonomy 补 archive/export-directory/ipa；这些是现有真实产物，不能从生产 schema 移除以迁就旧测试。
- terminate 的 target_lease_conflict 由真实租约检查与 schema 明确支持，补入精确断言。
- collection selection blocked/denied 来自 App 选择资格限制，运行时只建议 schema 诊断；生产恢复分类和测试 taxonomy 统一为 diagnose，不暗示绕过选择委托。
- `swift test --package-path CLI --scratch-path .build/issue210-audit --jobs 4 --filter 'Schema|HostAppTerminatePIDTests|XcodeArchiveCapabilityTests' --no-parallel`：172 项、27 套件通过。
- `swift build --package-path CLI --scratch-path .build/issue210-audit --jobs 4 --product triton`、`docs-linhay/scripts/check-docs.sh`、`git diff --check` 通过。
- 新增门禁修改以独立补丁交主控，不覆盖已集成 Xcode runtime 或缓存字段。

最终内联状态优先级增量：`swift test --package-path CLI --scratch-path .build/issue210-audit --jobs 4 --filter XcresultCommandTests --no-parallel`，5 项通过（0.147s）；确认统计元数据耗尽预算时，result/status 仍保持原测试结果。源码已冻结。
