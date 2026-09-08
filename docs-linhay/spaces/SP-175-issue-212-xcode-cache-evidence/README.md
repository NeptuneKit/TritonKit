# SP-175：Xcode 缓存证据（#212）

状态：本地实现及 focused 验证完成；独立 worktree，等待主控集成。

影响层：CLI 与共享 DTO。边界：DerivedData 保留策略、目录事实和本次构建观察；不预测 Xcode 内部缓存可复用性，不执行清理，不新增界面。

## BDD 与验收

- Given DerivedData 目录存在，When 解析 invocation，Then 只报告 directory-exists、reuseVerification unknown、incrementalExpected false；目录存在不能证明 warm。
- Given 缺失目录或同名普通文件，When 解析 invocation，Then 报告 missing-derived-data 且保留默认不清理策略。
- Given 构建日志包含 C / Swift 编译头、链接和脚本执行头，When 构建完成，Then 输出对应 taskLogCounts 和 compilation-observed；不以固定数量阈值断言 incremental 或 broad-rebuild。
- Given 捕获输出被截断而完整原始日志可读，When 汇总观察，Then 统计原始日志全部可读记录；原始日志不可读或超出界限时，Then 明确 partial 覆盖且不能断言没有编译。
- Given 构建数据库锁、陈旧文件或构建描述日志，When 汇总，Then 提供有界分类计数，不输出私有路径、目标名或签名内容，也不把描述出现推断成描述改变。
- Given xcode run 的 build 成功或失败，When 构建结果被转换为 run summary，Then 保留构建观察与构建日志来源。

详细字段与限制：[缓存观察契约](plans/20260908-cache-observation-contract.md)。

## 验证

先修改既有缓存断言运行 focused test 证明失败；再新增有界日志观察测试与无设备 runner 注入测试。独立 `.build/issue-212-cli` scratch，不执行真实 Xcode 或设备操作。公共索引、memory 和对外文档由主控统一写回。

### 2026-09-08 验证记录

- 先修改 `XcodeDiagnosticsTests` 的既有缓存断言。首次完整 focused 编译仍在解析依赖时，使用未修改 DTO/helper 原文提取的独立 Swift 夹具执行 RED：`swift .build/issue212-cache-red.swift` 返回 exit 1，输出 `FAIL: directory alone reported warm, incrementalExpected=true`。首次 SwiftPM 构建为遵守并行资源上限主动中止，随后统一使用 `--jobs 4`。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 当前失败：`space index must contain exactly one link for SP-175-issue-212-xcode-cache-evidence`，公共 space 索引由主控统一集成后重跑。
- 最终 focused 验证：`swift test --package-path CLI --scratch-path .build/issue-212-cli --jobs 4 --filter 'XcodeDiagnosticsTests|XcodeCacheObservationTests'` 返回 exit 0，26 tests / 2 suites 通过（0.320 秒；增量编译 59.86 秒）。源码冻结后的最终结果有效；此前一次构建因 helper 编译期间更新触发 Swift input-modified 保护而中止，已顺序重跑。日志保留在本 worktree 的 `.build-issue212-green.log`。
- 额外纯 Swift 负载夹具正确统计 600,000 条 CompileC 日志头；完整原始日志 fixture 验证跨 64 KiB 读取，并覆盖 178 条 C 编译与 Swift 编译头。
- 真实 Xcode/设备验证未执行：本 issue 通过纯日志夹具和注入 runner 验收元数据与摘要传递；真实工程的重新编译根因不在本修复承诺范围。

## 2026-09-08 主控集成验收

2026-09-08 用户已授权提交、合入 main、推送和关闭 issue；各实现分支已串行合入本地 main，正在等待 push/CI 后远端收口。最终 CLI 全量 977/977、根包 269/269、专用 iOS 26.5 Simulator UIKit 46/46 通过；本地总门禁通过。UIKit 覆盖包含 collection selection、longPress fail-closed、富文本 run 和实际 trait；Harmony 为离线 CDP/HDC fixture，不声称真实 DevEco smoke。详细证据与失败→修补过程见 ../SP-176-open-issues-integration/plans/20260908-issue-audit.md。
