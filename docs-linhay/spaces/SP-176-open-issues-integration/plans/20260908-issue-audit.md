# 2026-09-08 GitHub issue 审计与集成

## Requested

处理当轮 GitHub 全部 open issues：#207、#208、#209、#210、#211、#212。范围不包含此前已关闭 issue、不发布新版本。

## Observed

主仓 main 基线 a56d7d6a 与远端 main 相同；CLAUDE.md 有用户既有修改。SP-170/#210、SP-171/#209、SP-173/#207 已有本地实现，SP-172/#208 仅起步；它们均未进入主分支。

## Gaps / Fixes made

| Issue | 已确认缺口 | 修复边界 |
| --- | --- | --- |
| #207 | Unix socket 转发地址/清理不匹配、stale ID 落到另一页面、继承函数与 callback 提前成功 | 明确 endpoint 与页面绑定、own-method allowlist、callback/Promise 与有限等待、清理；不声明导航 session 证明 |
| #208 | UIControl sendActions 不能驱动 recognizer；tap --duration 被忽略 | embedded typed unsupported；tap 提前拒绝 hold duration；恢复建议不虚构可用手势 |
| #209 | 原实现具备公开 selection 路径，但 UIKit fixtures 未运行、弱 dataSource 可能释放、CLI schema 旧断言未更新 | 保留 eligibility/select/delegate 与 required verification，补 fixture 和契约验证 |
| #210 | 原始输出过大，旧实现还可能丢失 pipe 尾部；parser test 仅看错误文案 | compact 默认、完整日志留存、bounded final failures、真实 parser 合同测试 |
| #211 | attrs 接受 CALayer oid 而 nodes 可给 UIView oid；缺富文本 run 样式 | MainActor UIView/CALayer 解析，有界 UTF-16 runs、有效字体颜色、旧 text 属性保留为有界预览 |
| #212 | 目录存在被当作 warm/reuse | 存在状态与 reuseVerification/observedBuild 分开；统计日志头及覆盖，不按阈值假称增量或全量 |

## Evidence

- CLI：`TRITON_CLI_PATH=<built-triton> swift test --package-path CLI --scratch-path .build/cli-test --jobs 4 --no-parallel`，977 tests / 76 suites 全通过；最终日志 `/tmp/triton-sp176-cli-verified.log`。
- 根包：本地门禁中 269 tests / 34 suites 全通过。
- UIKit：Triton-first 保存 status/doctor/capabilities/schema/plan，创建专用 Simulator，`triton xcode test --package Package.swift --scheme TritonKit-Package --only-testing TritonKitTests/TKUIKitWindowTests --only-testing TritonKitTests/TKLabelAttributeGroupsTests ... --json` 实际 iOS26.5 46 tests 全过。初轮46中27失败是窗口fixture前提，第二轮剩旧tabbar坐标与pinch缺viewForZooming；均修正测试前提并保留原业务断言，未放松生产window检查。
- Xcode真实公开package build：新的 CLI 返回 `cacheState=directory-exists`、`reuseVerification=unknown`、`incrementalExpected=false`，`observedBuild.classification=no-compilation-observed`、coverage=complete，各编译头计数0，compact progress 2705 bytes。该结果只描述观测，不升级为warm cache证明。
- `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 通过；此开关仅避免脚本重复使用默认 iPhone17，已用上述独立Simulator执行实际UIKit验收。包含Release CLI build、CLI smoke、fake Harmony smoke、HTTP iOS runtime fixture smoke、docs/diff。
- `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 通过。分项红/绿证据与修补在 SP-170～175。
- 授权前检查点：主仓仅保留原有 CLAUDE.md 修改，当时尚未提交、合并、push、issue 评论/关闭或 tag/release；授权后结果见下文。

## Remaining risk

私有业务工程与真实 Harmony ArkWeb 未作重放；公开 fixtures 只能证明命令和运行时合同。不得用 host acknowledgement 或 delegate callback 直接判断业务成功。远端更新与关闭状态以实际 GitHub 查询为准。

## 用户授权后的提交与主分支集成

2026-09-08 用户明确同意“提交、合入 main、推送并关闭这 6 个 issue”。所有 issue 分支分别提交并串行 merge；冲突仅为 space 索引的并行追加，保留每个条目，再用已验收集成快照复核73个文件。唯一代码文本规范化为 CLITapCommands.swift 删除末尾多余空行。

实现提交：#207 ef73884f；#208 3a1b36a9 + host duration follow-up 741747ab；#209 5681f96e；#210 cce98e4d；#211 3f668601；#212 2916fcf5 + schema follow-up 247aa677。共享schema门禁修复 d2a805a5 单独提交。主工作区 CLAUDE.md 的用户改动以 SHA256 校验保持不变，未暂存、未 stash。

main push 与对应 CI 成功后再关闭已验证 issue，并独立 docs-only 归档提交/push，等待该归档 CI 与最终 open 查询后确认清零。

## 远端关闭与归档

已合入并推送 main（`82a13db5`），[代码 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/34179623896) 通过；#207～#212 已逐条回填证据并关闭，关闭后 open 查询为 0。

| Issue | 关闭时间（UTC） | 修复与验证回填 |
| --- | --- | --- |
| #207 | 2026-09-08T02:30:22Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/207#issuecomment-5578206483) |
| #208 | 2026-09-08T02:30:28Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/208#issuecomment-5578207400) |
| #209 | 2026-09-08T02:30:33Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/209#issuecomment-5578208060) |
| #210 | 2026-09-08T02:30:39Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/210#issuecomment-5578209007) |
| #211 | 2026-09-08T02:30:45Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/211#issuecomment-5578209600) |
| #212 | 2026-09-08T02:30:50Z | [关闭说明](https://github.com/NeptuneKit/TritonKit/issues/212#issuecomment-5578210515) |

初始及代码 CI 期间的 open 队列均为 #207～#212；关闭后复查为空。main 本地总门禁及 docs 门禁在集成后再次通过。归档内容只更新 space、索引、验收 JSON 与 memory；推送后需等待此 docs-only 提交自己的 CI 并最终复查 open 队列。保留所有 worktree 与用户 CLAUDE.md 修改；未发布 release/tag。
