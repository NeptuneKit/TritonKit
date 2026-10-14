# Prepared tests 复用交付

影响层：shared command builder + CLI；不改 Runner 现有 `.xctestrun` 动作，不新增 Web 控制面。

## BDD 与入口

1. Given 已选 container/scheme/configuration/destination/Xcode，When `xcode build --for-testing --test-artifact <fresh.xctestrun|fresh.xctestproducts> --source-root <root> --prepared-tests-manifest <fresh.json>` 成功并产生实际 artifact，Then 保存版本化 manifest。build-for-testing 失败不产出 manifest；构建中源树或 Xcode 改变拒绝发布 manifest。
2. Given manifest，When `xcode test --prepared-tests-manifest <json>` 使用相同原有 container/scheme/configuration/destination，Then 验证源树与 artifact 内容、Xcode DeveloperDir/版本、build settings，再执行 `test-without-building`。执行后再次验证同一身份。
3. Given 源码、配置、目标、工具链或测试 bundle 改变，Then `prepared_tests_identity_mismatch`；不进入测试。
4. Given 显式 result 路径存在或任何父目录为 symlink，Then 拒绝。未给 result 路径时分配 `.triton/prepared-tests/<UUID>.xcresult`；旧结果不能成为新运行证据。
5. Given 进程返回 0，但 xcresult 未解析、没有测试、全部跳过或没有通过的测试，Then `prepared_tests_result_incomplete`，最终 `ok:false`。

成功输出沿用 `TKXcodeActionSummary`，build 添加可选 `preparedTestsManifestPath`；test 中 `resultBundlePath` 和实际 `sourceCommand` 绑定本次运行。失败通过已有单一合法 CLI envelope。

## 指纹边界

- 源根必须是包含所选 container 的实际目录；使用显式 `--source-root`，调用者需覆盖项目外的依赖源树。不会声称自动发现项目外依赖。
- SHA256 按稳定路径、文件类型、权限、大小与完整内容计算。源树排除 `.git`、`.build`、`.triton`、`DerivedData`、`node_modules`；源码若放在排除目录不在此策略保证范围内。
- 每个源/产物集合最多 20000 个节点、1 GiB；超限失败，不截断为成功。源码、`.xctestrun` 及其引用 bundle 内 symlink、特殊文件、文件读取时大小变化均拒绝；仅 exact `/tmp`→`private/tmp`、`/var`→`private/var` 固定 macOS 系统路径别名兼容。
- `.xctestrun` 上限 4 MiB，解析并哈希 `TestBundlePath`、`TestHostPath`、`UITargetAppPath` 的实际文件树，支持 `__TESTROOT__` / `__TESTHOST__` / `__PLATFORMS__`；未解析宏拒绝。
- `.xctestproducts` 仅当当前 `xcodebuild -help` 明确支持 `-testProductsPath`；产物本身以有界完整内容哈希绑定。支持 Xcode 生成的包内相对链接，例如 `Tests/0/Debug → ../../Binaries/0/Debug`；哈希绑定链接原始字节及类型/路径/权限，实体目标内容在包树正常遍历时完整哈希，不经链接递归。
- 测试包先固定 `realpath` 物理根，链接原始目标按组件检查；必须为小于 4096 字节的 UTF-8 相对路径，每个父组件及最终目标必须存在且不能是另一个链接或特殊文件。绝对路径、越界再返回、悬空、直接/间接链接循环与目录别名组成的遍历环均拒绝。物理根、artifact scope 与内部链接策略版本计入 artifact hash。
- manifest 的 fingerprint policy 更新为 `sha256-tree-v2`；旧策略明确返回 `prepared_tests_manifest_invalid`，必须重新 build-for-testing。manifest 结构 version 仍为 1。
- manifest 新建采用独占创建、0600，不覆盖旧文件。源码根内的输出必须放在排除的 `.triton` / `.build` / `DerivedData`，避免输出造成源指纹自我变化。
- 无新增外部依赖。用 Apple CryptoKit 做本机摘要。现有超过 1500 行文件提取 `TKXcodebuildCommand.swift` 与 `CLIXcodeTestRuntime.swift`，保留原公共签名默认行为。

## 验证与状态

Focused 测试：`swift test --package-path CLI --scratch-path .build/sp196-prepared-tests --no-parallel --filter 'XcodePreparedTests|XcodePackageArtifactTests'`。

先新增 BDD 测试再新增实现；首次 red 构建受 shared builder 拆分过程阻塞，未得到独立的行为 red 结果；独立 scratch 后续编译受并行文件发现/resize circular reference 阻塞，已报告对应 owner。本模块测试结果在测试完成后补记。真实 Xcode build/test 由主控串行接管，此子任务未执行任何设备动作、服务操作、提交或推送。

最终候选验证通过：2026-10-14，`XcodePreparedTests|XcodePackageArtifactTests|XcodeCommandTests|XcodeProgressTests` 共 74 项、4 suites 全通过；日志 `.build/sp196-prepared-tests-validation.log`。覆盖源码/测试 binary/configuration/destination/Xcode 漂移、文件和父目录 symlink、fresh result、独占 manifest、正常 prepared fixture、0-result 与 all-skipped 不能成功、原命令/progress/package 回归。真实 CLI `xcode build --for-testing --json` 退出 1 且输出单一 `validation_failed` envelope，证明配套参数预检；私有证据 `.build/sp196-prepared-invalid.json`。

首轮行为回归暴露 macOS 临时路径的系统 symlink 与 Foundation 路径归一化差异；修复后上述 74 项通过。该结论仅为实现/编译/fixture/入口验证，真实 build-for-testing/test-without-building/xcresult 尚未由本子任务执行，交由主控串行验证。

主控真实 `.xctestproducts` 产物只读检查发现一条 Apple 内部链接 `Tests/0/Debug → ../../Binaries/0/Debug`，原严格策略拒绝有效产物。先补合法链接及不安全链接 fixture，RED 为 2 项中 1 项失败（合法内部链接误拒绝），日志 `.build/sp196-prepared-internal-links-red.log`；再补跨目录别名环，RED 为 1 项失败，日志 `.build/sp196-prepared-directory-cycle-red.log`。最小修复后，合法目录/文件别名、binary 内容漂移、原始链接字节漂移、旧策略拒绝、source/普通 bundle 严格策略及全部链接负例均纳入永久测试。

本次候选使用主控已释放的 `.build/sp196-resize` 串行 focused scratch，`XcodePreparedTests|XcodePackageArtifactTests|XcodeCommandTests|XcodeProgressTests` 77 项 / 4 suites 全通过，日志 `.build/sp196-prepared-internal-links-validation.log`。真实 fresh build-for-testing/test-without-building/xcresult 的后续重试仍由主控负责；本子任务未执行真实 Xcode build/test、设备或服务动作。

官方依据：[Apple TN2339 build-for-testing/test-without-building](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)、[Apple Testing in Xcode](https://developer.apple.com/videos/play/wwdc2019/413/)。`.xctestproducts` 能力以实际选中 Xcode 自描述为事实，不仅按版本号推断。

## 主控最终验证

主控真实验收：Xcode27/macOS fixture actual build-for-testing exit0；test-without-building两次各实际1项通过、两个fresh xcresult路径不同；源码改变后prepared_tests_identity_mismatch非零，未开始xcode.test.invocation。`.triton/sp196-validation/prepared-aggregate.json`。此结果证明功能与失效规则，不声明性能收益。
