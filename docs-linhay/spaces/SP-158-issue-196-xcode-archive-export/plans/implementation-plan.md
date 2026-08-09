# SP-158 implementation plan

## Contract first

- `triton xcode archive`：archive generic iOS destination，输出 `.xcarchive` artifact。
- `triton xcode export`：使用显式 export-options plist，把 archive 导出为 IPA 或 export directory。
- 两条命令均支持重复 `--build-setting KEY=VALUE`，并保留 JSON/JSONL sourceCommand、progress、final result、failure/recovery。
- archive 与 export 的 parser、schema、runner 和 output model 分离；不复用层级 `export archive` 的命名。

## TDD slices

1. command parser / help / schema red tests。
2. command builder argv tests，包括路径空格、条件 build setting、签名参数和 export options。
3. fake runner tests，包括 bounded progress、artifact discovery 和 archive/export failure mapping。
4. implementation and regression.

## Evidence

- 红灯：`swift test --package-path CLI --scratch-path .build/sp158-red --filter XcodeCommandTests` 在实现前因 archive/export parser、builder、schema/failure helper 缺失而编译失败。
- focused green：archive/schema filter 3 tests、export filter 2 tests、`BuildRunnerTests` 8 tests 均通过；schema direct-child 与 parent `providedCapabilities` 均断言 `xcode-archive` / `xcode-export`；`triton xcode --help` 与 release binary 的 `schema --command xcode.archive --json` 已发现新增 surface。
- release green：`swift build --package-path CLI --scratch-path .build/sp158-release -c release --product triton` 通过，真实输出为 `Build of product 'triton' complete! (641.93s)`，仅有既有 selector warnings。
- 真实 host Xcode archive/export、签名资产、IPA 安装与私有 workspace smoke 未运行；不能把 host fake runner 或 schema/help 证据当作真实签名成功。
- full Xcode suite：46 项通过。流式 host runner 已改用 `terminationHandler` 结束通知，避免全局队列上的阻塞式 `waitUntilExit()`；`--destination` schema 保留既有 run readiness 文案并补充 archive 语义。docs gate 仍被原有 SP registry 非连续错误拦截。
