# #214 · 原 18.66 GB 缓存的历史调用溯源

## Requested

2026-10-28 用户要求继续调查原报告约 18.66 GB 的缓存来源，先查历史构建记录和调用路径，未查明前保持 issue 开放。取证阶段只读检查历史资料；不删除缓存，不修改外部工程，不启动 App 构建或设备。用户随后明确授权提交推送、创建 PR，并将脱敏结论同步到 #214，issue 继续开放。分析输出和辅助解码程序仅放在本 worktree 的 ignored 证据目录。

基线 `eefac94f`。调查承接 [PR #234 记录](20261028-cache-investigation.md)；之前按单独授权删除的两处小缓存不是本轮的原 18.66 GB 现场，不能以其结果代替原报告归因。

## Observed / Evidence

**取得了真实历史缓存目的地和一个匹配“根 + iOS 子目录”结构的历史索引候选，但仍未找到把任一候选与原 12.13 GB / 6.53 GB 绑定的原始 Mole/du 输出。** 下文 H1/H2 是两个不同的私有工作区别名，与前一轮小缓存 A/B 的编号无关。

### H1：历史磁盘索引有两层目录，子目录有测试调用记录

只读解码 Mole analyzer 的 Go gob 缓存，读取 ScanTime、NeedsRefresh、SchemaVersion 与 DerivedData 条目。没有执行 Mole 分析或清理，也没有刷新其缓存。

| 条目 | 历史索引目的地（脱敏） | 缓存中的 Size | ScanTime（+08:00） | NeedsRefresh |
| --- | --- | ---: | --- | --- |
| H1-root | `<history-workspace-1>/.triton/DerivedData` | 6,695,800,832 bytes | 2026-10-02 22:01:49 | true |
| H1-child | `<history-workspace-1>/<ios-project>/.triton/DerivedData` | 6,826,598,400 bytes | 2026-10-02 22:02:02 | true |

这是 **10 月 2 日的待刷新索引值**，不是 9 月 15 日原 purge 统计或本轮实际占用。两者当前均不存在；不能由此判断由谁、何时删除。Size 与原 12.13/6.53 GB 不直接相等，日期也不同，所以只能用于定位候选路径。

该候选的 2026-07-13 验证文档（证据 H1-child-document，19–26 行）保存以下脱敏调用形态：

```text
xcodebuild -workspace <App>.xcworkspace -scheme <App>
  -configuration Debug -destination <simulator>
  -derivedDataPath .triton/DerivedData
  -only-testing:<focused-test> test
```

文档第 29 行记录 `TEST SUCCEEDED`，第 36 行记录 `<ios-project>/.triton/DerivedData/Logs/Test/Test-<App>-2026.07.13_17-29-39-+0800.xcresult`。由相对 workspace 与结果包位置，可推断路径解析基准为 iOS 子项目；没有独立 pwd 输出，因此 cwd 仍按推断表述。该证据等级是保存的验证记录，不是尚存 xcresult 的重新验收，不能证明首次创建时间、Triton 发起调用或达到 12.13 GB。

同工作区另一份 2026-07-09 文档（H1-root-document 第 18 行）有 `xcodebuild -workspace <ios-project>/<App>.xcworkspace ... build`，却没有 `-derivedDataPath`。不能仅因 workspace 路径带子目录，就把它归为根缓存的创建调用；其中记录的 Triton 版本 0.2.9 也不能追认为创建缓存的版本。根缓存的实际创建调用仍未知。

### H2：原始日志证明显式不同目的地也能产生两份缓存

H2-root-triton 的 JSONL 第 1 行保存真实 `xcode.build.invocation`，命令形态为：

```text
xcodebuild -project iOS/<App>/<App>.xcodeproj -scheme <App>
  -configuration Debug -sdk iphonesimulator
  -destination 'generic/platform=iOS Simulator'
  -derivedDataPath .triton/DerivedData build
```

关联 artifact 目录时间戳 `1783352974303` 对应 2026-07-06 的记录。该 JSONL 第 157 行最终 `ok=false / exitCode=15`，不能把 invocation/中间事件的 ok=true 记成构建成功。随后保留的原生 fallback stdout（H2-root-native 第 2 行）继续使用根相对 `.triton/DerivedData`；第 992 行给出根缓存下的绝对 Build description path，第 48910 行为 `BUILD SUCCEEDED`。因此可以证明根目录缓存被实际构建使用。

另一份完整日志 H2-child-native 自带 2026-09-11 测试时间（第 4 行），第 449 行记录：

```text
xcodebuild -project iOS/<App>/<App>.xcodeproj -scheme <App>
  -configuration Debug -sdk iphonesimulator
  -destination 'generic/platform=iOS Simulator'
  -derivedDataPath iOS/<App>/.triton/DerivedData
  -resultBundlePath <result-bundle> build
```

第 1519 行的绝对 Build description path 落在 iOS 子目录缓存，第 4700 行为 `BUILD SUCCEEDED`。**这个候选的两种缓存目的地有显式路径差异，不能只归因为从不同 cwd 调用。** 相同相对 project 路径与各自绝对产物路径支持其共同以工作区根解析路径；未找到单独 pwd 原始输出，不扩大成首次创建调用证明。

H2 根缓存的 10 月 2 日 analyzer 索引值为 14,576,066,560 bytes，与原报告的根 6.53 GB 也没有直接对应。本轮未对 H2 历史内容做重复度判断。

### 原报告时间窗口与资料缺口

- #214 创建于 2026-09-15 **20:47:56 +08:00**。SP-179 首次实现是在次日 00:16:50；最早 README 只描述功能范围，没有原现场路径或日志。当天 memory 中 8 bytes/2 files 是临时 fixture，不是原大缓存的证据。
- Mole operations.log 的第 5829–5830 行记录 9 月 15 日 19:46:50–19:48:31 的 purge 会话摘要：229 items、32.14GB。没有目标路径或逐项操作记录，不能证明它包含原两处缓存、不能解释原 18.66 GB，也不能把这个摘要认定为某个已授权删除动作。
- 当前 `triton-xcode-artifacts` 留有 1,257 个目录，名称毫秒时间戳范围为 2026-10-14 05:26:03.798Z 至 2026-10-28 03:24:18.131Z；早于原 issue 的候选为 0。当前目录没有覆盖原报告窗口，不知道旧记录何时或为何消失。
- 定向检索相关仓库历史、shell history、Claude 项目记录、Codex 历史投影及 **6,685 份 9 月 17 日之前创建的本地会话归档**，没有找到原 purge/du 的完整路径输出。归档命中仅为无关的早期 Mole 文本，10 月 issue 正文/本轮复述不作为独立来源证据。这个结果不代表其它机器或未保留会话中也不存在记录。

## 已排除的过度归因

1. 旧默认相对路径受 cwd 影响只是机制；H2 的直接证据还展示了显式目的地变化，不能把所有“双缓存”归为同一个原因。
2. 后来的磁盘索引和版本记录不能追认为原 9 月 15 日容量、创建版本或最后使用时间。
3. 结构相符和数值接近都不足以把 H1/H2 指认为原 18.66 GB 工作区；没有首次创建日志、内容摘要或原 purge/du 映射。

## Gaps / 后续计划

#214 保持 **OPEN**；交付只同步结论，不关闭或消除未查明项。待补的是原 9 月 15 日 `mo purge --dry-run` / `du -sh` 输出中的路径，或包含该输出的原会话/终端记录；取得后先与 H1/H2 候选映射，再查该工作区对应时间段的调用和版本。没有这个锚点，不再无边界遍历其它私有工程，也不重建或删除缓存来模拟原现场。

仍未知：原两处确切工作区、首次产生调用/版本/cwd、原内容重复程度、是否泄漏、实际独占物理可回收量，以及当前缺失目录的消失原因。

## 验证与沉淀

[脱敏证据索引](20261028-history-trace-evidence.json)保留源文件 SHA-256、行号、历史索引字段和检索覆盖。原始私有路径与相关日志片段仅保存在 ignored `.build/issue214-history/source-evidence-private.json` 等本地证据，不进入公开文档。

没有产品代码改动或真实构建，跳过 Swift/设备测试；使用只读解码与源文件散列核对验证证据。沉淀到既有 SP-240 与 EXPERIENCE：历史索引仅作候选线索，双缓存需要同时核对 cwd 和显式 derived-data 参数。`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`、脱敏检查、JSON解析与源文件SHA-256复核均通过；无产品变更，未运行Swift/设备测试。交付范围为独立分支、PR 与 issue 脱敏更新；本次文档变更不包含产品实现或新版本发布。
