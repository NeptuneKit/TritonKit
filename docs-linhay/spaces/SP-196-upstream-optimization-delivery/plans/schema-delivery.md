# SP-196 Schema 最后集成修复

日期：2026-10-14。影响层为 CLI 机器可读 schema 与 shared recovery 分类；不改执行行为、设备动作、HTTP 或其他 schema 文件。

## BDD 与红测事实

- 给定 `xcode build --for-testing` 的真实解析器已接受 prepared 参数，schema 必须将 `--for-testing`、`--prepared-tests-manifest`、`--test-artifact`、`--source-root` 归属到 build 子命令。
- 给定子命令会返回 prepared 测试错误，父 schema 与其 failure shape 必须覆盖这些错误；artifact 输出拒绝必须有 archive 类的只读恢复命令。
- 给定 Resize Mode 阻止新触摸/视频，schema 必须描述相应真实错误；截图允许活动会话按 display 路由，未知状态失败。键盘入口不添加触摸失败。
- 给定 preferences 已落盘但 relaunch 失败，schema 必须保留 `preferences_relaunch_failed`，恢复提示优先检查状态与观察，不建议重写已交付偏好。
- 给定 skills 更新锁冲突、prepared 结果缺失或空 app-map suite，分类必须精确枚举并指向检查/规划，不能增加接受任意未知错误的兜底。

主控 `.build/sp196-validation/cli-full-2.log` 记录 1318 tests 中 6 issues：3 个 build option 未归属；父 xcode 缺 6 个 prepared/artifact 错误族；3 个新错误 recovery taxonomy 缺失；build artifact failure 缺 archive 恢复命令。该现有集成失败为修复前红测证据，未另起完整回归。

## 实现边界与文件

- `Sources/TritonKitCLI/CLISchemaXcodeCommands.swift`：build 归属四个 prepared flags；父 failureCodes/failureShape 补 prepared 六码；build nextCommands 增加只读 xcresult summary。
- `Sources/TritonKitCLI/CLISchemaHostCommands.swift`：sim 父包含全部五个 Resize 错误；tap/swipe 包含 touch 三码；sim/device screenshot 只增加 capture state unknown；record 包含 capture 两码及只读 doctor/截图恢复入口；app/prefs 父子包含 relaunch failure。其他既有错误列表保留。
- `Sources/TritonKitShared/TKCLITransportSchemaModels.swift`：精确分类 skills busy、prepared 族、empty suite、artifact output、prefs relaunch 和 Resize 错误。触摸未知/不可路由使用 diagnose/plan；目标非法使用 prepare-target/diagnose；capture 不可路由另含 archive；prefs 与 incomplete result 保留 verify/观察或 artifact 检查。
- 经主控追加授权，`CLI/Tests/TritonKitCLITests/SchemaFactSourceTaxonomies.swift` 仅新增具体错误枚举映射；原断言、未知失败行为及通用兜底未改。

## 验证

独立 scratch `.build/sp196-resize`，串行执行：

```sh
swift test --package-path CLI --scratch-path .build/sp196-resize --filter 'SchemaFactSourceTests|XcodeSchemaParserContractTests' --no-parallel
```

第一次 focused：128 tests / 2 suites 通过（`schema-focused.log`）。第二次覆盖补充的 device screenshot schema：128 tests / 2 suites 通过（`schema-focused-2.log`）。`git diff --check` 通过。未启动完整 CLI 测试、服务或真实设备动作；主控负责最终全局回归与 space/index/memory 收口。

## 经验

父 schema 与子命令解析器/错误 inventory 是同一可执行契约。新增错误必须同时更新实际生产 recovery mapping 和独立测试 taxonomy 的具体枚举；保留未知错误失败，避免通过宽泛后缀或弱化断言掩盖遗漏。恢复命令的根分类还必须满足 artifact failure 的 archive 验收，单纯增加错误码不足以闭环。
