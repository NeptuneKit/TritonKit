# SP-201 本地 main 整合（2026-10-16）

用户授权“合到 main”。功能提交 `2711565f` 与 main 基线 `3000be92` 在独立worktree联合验证后整合；不推送、不发布，保留worktree供后续试用。

## 冲突与行为

- SDK启动保持 main 的 discovery 安全检查先执行，通过后才启动picker。拒绝发现结果时不连接，picker保持停用；原有失败启动测试加入显式启用picker的场景。
- shared transport保留main新增discovery字段与picker selection三处映射。
- space、索引与memory合并双方记录；主工作区其他任务WIP逐文件备份并三方恢复，不使用stash、不纳入本次提交。

## 验证

| 入口 | 结果 |
| --- | --- |
| `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` | 通过；根包291项，Release CLI构建与smoke、文档门禁通过 |
| `TRITON_CLI_PATH=$PWD/.build/cli/release/triton swift test --package-path CLI --no-parallel` | 1459项、145 suites通过 |
| `triton xcode test` / RuntimeValidation | iOS27专用模拟器，UIKit与启动回归107项通过 |
| `triton xcode test` / PickerGesture + fixture companion | 真实触摸1项、CLI7步通过；拖选无业务点击，guard拒绝不产生点击，有效tap后计数为1 |

本地门禁的通用Xcode步骤显式跳过，实际iOS测试由独立host工程完成；不冒充全平台/Release/pod lint本轮验证。触感、特殊渲染和多scene矩阵等原有限制仍见space README。

原始日志位于worktree `.build/sp201-evidence/main-integration-*`；xcresult位于同级 `.sp201-validation-host/picker-main-integration*.xcresult`。公开[摘要](20261016-main-integration.json)绑定本轮源码SHA-256；旧closeout摘要保留为功能提交阶段历史证据。

## 沉淀

本轮在原有启动失败测试补齐picker的联合状态断言。复用既有“候选联合验证、逐文件保护WIP”的治理方式，无新增跨项目规则。
