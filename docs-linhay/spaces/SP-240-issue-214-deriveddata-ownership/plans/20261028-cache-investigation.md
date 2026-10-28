# #214 · 2026-10-28 `.triton/DerivedData` 只读现场调查

> 本文为先前只读阶段的历史记录；用户随后单独授权删除，当前结果见[授权删除记录](20261028-authorized-cache-deletion.md)。原始统计保留为删除前快照。

## Requested

用户要求继续调查来源、实际占用和重复情况，明确不删除任何缓存；随后限定处理 `.triton/DerivedData`。影响层为 CLI 只读观察与文档。本轮没有启动构建、改配置、清理缓存或进行 GitHub 写入。

## Observed / Evidence

扫描本机选定开发目录（Desktop、Documents、Developer、Projects、Code、ZCodeProject、src、MN、zizzania、Sites、Downloads，存在者才扫描）及用户根 `.triton/DerivedData`，忽略 `.git`、`.build`、node_modules、Pods、build、现成 DerivedData 等依赖/构建树，不跟随目录软链接。最终定位两处实际目录 A、B；这不是全磁盘/外接卷普查。私有工作区只保留别名，完整路径与原始证据仅留在本地 ignored `.build/issue214-investigation/`。

- A：外部 iOS 项目的 `.triton/DerivedData`。`info.plist` 的 WorkspacePath 与该项目对应；4 份 XCBuildData build-request 均记录 Debug、iphonesimulator26.5，arenaInfo 的 DerivedData 与实测目录一致。Build 日志清单有 6 个命令行构建/测试条目。
- B：本仓库 `Examples/TritonKitDemo/.triton/DerivedData`。`info.plist` 与 Demo 工程对应；1 份 build-request 记录相同配置/SDK，arenaInfo 与该目录一致；当前 Build 日志清单为空。
- A/B 属于不同项目，不能把它们当作原 issue 所述“同一工作区根与 iOS 子目录”的原始两处大目录。原 12.13 GB / 6.53 GB 尚无对应现场证据，不推断其已删除或缩小。
- 当前可证实来源是 Xcode 项目构建产物和 SwiftPM 依赖状态；尚无原始调用 argv、cwd 或创建时 Triton 版本，无法断言一定由 Triton 的旧默认创建。目录 birthtime/mtime 或 plist LastAccessedDate 不作为实际最后使用证明。

### 占用

2026-10-28 12:48:51–12:48:56 +08:00 完成文件扫描与摘要核对。`triton 0.2.33 xcode derived-data inspect --root <A/B> --json` 均成功、dryRun=true；其逻辑 bytes 与独立 lstat 统计完全相等。

| 目录 | 普通文件数 | 逻辑 bytes | 分配块 bytes | 分配块 GiB |
| --- | ---: | ---: | ---: | ---: |
| A（external-ios-project） | 24,842 | 1,372,470,802 | 1,437,212,672 | 1.339 |
| B（TritonKitDemo） | 16,435 | 610,858,640 | 656,203,776 | 0.611 |

合计逻辑大小 1,983,329,442 bytes（1.847 GiB）；分配块合计 2,093,416,448 bytes（1.950 GiB）。分配块按 lstat.st_blocks × 512、device/inode 去重，包含目录/链接自身的块，不跟随链接；与两次 `du -sk`（1,403,528 / 640,824 KiB）一致。普通文件无多链接 inode，跨根也未发现共享 inode。A 跳过 19 个软链接，B 跳过 5 个。APFS clone、压缩、快照保留和独占 extent 未测，以上不是可回收物理空间。

| 类别 | A 分配块 MiB | B 分配块 MiB |
| --- | ---: | ---: |
| `SourcePackages` | 608.20 | 396.09 |
| `Build` | 411.52 | 68.71 |
| `ModuleCache.noindex` | 219.10 | 133.41 |
| `Logs` | 87.95 | 0.03 |
| `Index.noindex` | 42.36 | 26.07 |
| `SDKStatCaches.noindex` | 1.47 | 1.47 |
| `CompilationCache.noindex` | 0.03 | 0.03 |
| `TestResults` | 0.00 | 0.00 |
| `info.plist` | 0.00 | 0.00 |

SourcePackages 是最大项：A 的 repositories/checkouts/artifacts 约 232.59/188.82/186.78 MiB，B 的 repositories/checkouts 约 219.86/176.21 MiB。它们是包仓库、工作副本及二进制依赖，不能仅因都在缓存中就视为同一文件的重复副本。

### 内容重复

两处共 41,277 个普通文件；对所有尺寸存在重复候选的 36,918 个文件（705,279,816 bytes）完整读取并计算 SHA-256。唯一尺寸的文件在本次两根集合内不可能与另一普通文件完全相同，因此无需读取正文。读取使用 O_RDONLY/O_NOFOLLOW，前后 fstat 核对身份、大小、mtime/ctime；扫描后再次核对普通文件全集及元数据，没有变化，错误为 0。零长度文件不计入重复内容组。

- 跨根有 7,738 个非空 SHA-256 相同内容组；每组只算一份内容，合计 **172,813,708 bytes / 164.808 MiB**。这些组在两根全部成员共 20,153 个文件、351,845,928 bytes，不能把成员总量当成多余空间。
- 主要来自 SourcePackages 的相同内容 149.544 MiB、Index.noindex 14.289 MiB；依赖源码、测试向量与生成索引占主导。模块缓存和其它小文件也有少量重合。
- 两根中同相对路径有 9,435 个，8,920 个 SHA-256 相同，515 个不同；目录树和文件内容整体都不相同，不是两份完整复制品。
- 各目录内部按“同内容保留一份”的纯逻辑计数：A 额外内容副本 104.064 MiB，B 7.179 MiB。此计数也包含构建机制正常产生的多位置文件，不能作为自动去重/删除清单。
- workspace-state 记录 A/B 分别有 32/29 个包；共 24 个身份相同，其中 11 个记录的 revision 相同，13 个不同或未知。即使包名相同，也不能直接替换其整个 checkout。

### 历史路径机制

只读核对 Git 历史：`v0.2.25:Sources/TritonKitCLI/CLIXcodeRuntime.swift:140` 按显式参数 → 配置 → 默认 `.triton/DerivedData` 选择路径。普通 `--project/--workspace` 不根据项目父目录改写路径，也不切换执行 cwd，因此从根与子目录运行会落到不同物理目录；`--package` 会解析到 package 目录并在其中执行，是不同分支。

`772ef10c60510503e0b0623015f906bd19243162`（2026-10-13，已包含于 v0.2.26）改为默认不传 -derivedDataPath；旧配置恰为 `.triton/DerivedData` 或 `./.triton/DerivedData` 时迁移到默认，显式参数和其它配置仍保留。当前解析见 `CLIXcodeRuntime.swift` 的 resolveXcodeDerivedDataOverride、`CLIXcodeResultRuntime.swift` 的 xcodePackageArtifactPath、`TKXcodebuildCommand.swift` 的 packageWorkingDirectory 与 `CLIHostProcessRuntime.swift` 的 configureHostProcessExecutable。

该旧机制与原报告形态吻合，是有源码支持的可能解释，不能替代原调用证据。升级不会迁移/删除已有目录。

## Gaps / Remaining risk

1. 原 18.66 GB 报告的两处目录未定位，原始版本/调用/工作目录与重复程度仍未知；#214 继续保留 OPEN。
2. 本轮证明 A/B 有部分相同内容且不是完整重复；未证明缓存泄漏、最后使用时间或可回收独占物理空间。
3. 本轮没有活动构建排他验证，普通文件元数据稳定仅覆盖这次扫描窗口，不是删除许可。未读取/改写 live build.db，不测删除，不调用 cleanup/confirm。

## 后续建议

普通构建继续使用 v0.2.26 起的 Xcode 默认策略；只有需要隔离时显式传绝对 DerivedData 路径，并记录其用途。已有 A/B 保留。若继续追踪历史大目录，需补原路径或历史 inspect/构建调用证据；若另行要求回收，先独立确认目录归属、依赖影响和无活动构建，再申请实际删除授权，本轮不执行。

## 验证与归档

机器可读脱敏结果见 [cache-inventory.json](20261028-cache-inventory.json)，含 CLI 二进制 SHA-256、扫描口径、完整候选摘要覆盖与原始本地证据 SHA-256。报告写入位于 SP-241 集成 worktree 的现有分支，主仓 WIP 未变；本轮不提交、不推送。产品代码无变化，未运行 Swift/设备测试；文档门禁结果见下方追加记录。

验证结果：`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 均通过；脱敏检查及 JSON 数值一致性断言通过。未跟踪报告另行检查无尾随空白；写回验证结果后再次通过文档结构与差异检查。
