# TritonKit 开发进度回顾（2026-07-24）

> 审计范围：本地 Git / worktree、`docs-linhay` 记录与 GitHub 当前可见状态。本文区分已发布产品、已提交未推送文档、未合入本地工作与待裁决方向；未经确认不对遗留分支或 worktree 执行合并、删除或推送。
>
> 后续更新：本文件保留 2026-07-24 的审计快照。其后完成的 SP-126～SP-136 本地执行栈、已实现功能与未集成边界见 [2026-07-27 follow-up](./20260727-development-progress-followup.md)；后续状态不得倒读为本快照当日已经可用或已发布。

## 一句话结论

项目并非停在未验证的半成品：公开产品基线已完成 [`v0.2.15`](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.15) 发布。恢复开发前最重要的不是重做近期已归档功能，而是先厘清一个带未提交修改的 #164 独立 worktree，再按 #166、#168、#167 的顺序处理当前远端缺口；`testrec` 方向则仍等待产品裁决。

## 已交付基线

- `v0.2.15` 已于 2026-07-23 发布，包含 macOS arm64/x86_64 CLI、checksum、公共 skills bundle 与 Homebrew 更新；release workflow 和远端 `main` 最新 CI 均成功。CocoaPods 本轮只完成 lint，**尚未发布到 trunk**。
- 近期 #159–#165 已完成归档，覆盖 UIKit alert/table/menu 行为边界、iOS 真机 selector 与 screenshot scope、embedded screenshot PNG 契约、iOS Simulator host framebuffer evidence、Xcode build settings / `xcresult` 兼容与 scheme discovery 韧性。详细证据见 [2026-07-23 memory](../memory/2026-07-23.md) 和 [路线总览](../spaces/README.md)。
- 实现面不是原型空壳：macOS `triton` CLI、Hummingbird HTTP/WS 服务、Debug-only iOS embedded runtime、Android ADB host adapter / 可选 Bridge、Harmony HDC host adapter 与 React/Vite Web Device Hub 均已有代码和测试契约。Android Bridge 不等同业务 App embedded SDK；Harmony embedded SDK 仍是外部对齐/HAR 路径，尚非本仓已发行 OHPM 产品。
- 上次完整本地验证记录为 2026-07-23：`docs-linhay/scripts/verify.sh --local` 通过，含 231/231 Swift tests、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、iOS Simulator build、docs 与 diff 门禁。本次只整理文档，未重复执行功能测试。

## 当前可继续推进的队列

GitHub 当前没有开放 PR，未关闭 issue 为 3 个；下列优先级是基于可复现性、用户影响和绕过路径的审计建议，不是远端标签。

| 建议优先级 | 事项 | 当前事实 | 建议边界 |
| --- | --- | --- | --- |
| P1 | [#166](https://github.com/NeptuneKit/TritonKit/issues/166) | 真机 embedded runtime 输出 JPEG 时，CLI screenshot 拒绝写入，导致有效截图字节丢失。 | 统一编码或安全转码，并补充 artifact / evidence 契约测试。 |
| P1 | [#168](https://github.com/NeptuneKit/TritonKit/issues/168) | iOS 真机 `app terminate` 未提供 `devicectl` 所需 PID，稳定失败。 | 先明确 PID 解析与 error/recovery 契约；`launch --terminate-existing` 只是临时绕过。 |
| P2 | [#167](https://github.com/NeptuneKit/TritonKit/issues/167) | `xcode run --device <alias>` 在子目录中先做完整构建，再发现 alias 缺失。 | 把 target/alias 解析前移到构建前；当前可用重建 alias 或 install/launch 绕过。 |

当前编号索引已有 125 个登记 space。因此真正开始上述任一 issue 时，应先按当时索引创建下一个 `SP-126-...` space、独立 branch 与 worktree，而不是直接在历史 #164 worktree 上叠加新工作。

## 暂停而非遗忘的方向

唯一明确标为“待定”的 space 是 [Test Recorder Replay](../spaces/20260622-test-recorder-replay/README.md)。它已经有 P0 合同和 `local-simulated` executor，但真实设备 executor、系统级监听、真实 VLM、proposal apply 与 live network policy 均未落地。

恢复条件是产品裁决：继续保留独立 `testrec` 产品面，或将有效的 `.tritontestcase` 合同并入既有 `workspace/test/replay`。在此结论前不应继续新增实现，以免形成第二套运行时和成功判定。

空间编号物理迁移仍为 0/125；这是保护旧链接的独立文档治理待办，不是功能交付 blocker。

## 恢复时应正视的产品边界债务

- 当前 `triton serve` 代码默认绑定 `0.0.0.0`，而治理规则规定 HTTP 固定为 `127.0.0.1:19421`；这是安全/契约口径不一致，恢复服务端工作前应先裁决并收敛。
- Web 文档定位为只读 Device Hub，但现有前端已有 gesture 与 node-property 的 POST 写入口。它与“Web 只消费只读 DTO、不承载业务写操作”的项目边界不一致；在明确保留或移除前，不应再把它描述为严格只读原型。

## 恢复前必须处理的本地状态

1. 主工作区 `main` 干净，但比 `origin/main` 领先两个**文档/治理**提交（`80540784`、`931645ed`）；尚未推送，不能当成远端产品基线，也不应在未经授权时推送。
2. `../TritonKit-worktrees/20260722-issue-164-evidence-simulator-screenshot-fidelity` 仍有 7 个未提交的 evidence Swift/测试文件修改（约 +444/-46）。该分支相对 `main` 为 main-only 7、branch-only 1；尽管 #164 的产品交付已在 `main` 归档，这份本地 WIP 的意图与基线尚未确认。**保留、不要合并或删除**，先确认 owner、目标和与现有 #164 修复的关系。
3. 还有两个未合入远端的本地分支：`codex/20260707-github-issue-batch` 含一个代码提交 `9c0b63b0`，`codex/20260707-issue-140-redaction-preflight` 含一个文档提交 `ab6f1263`。它们需要单独对比当前 `main` 后再决定保留、整合或归档；不应混入新 issue。

## 建议的重启顺序

1. 对 #164 dirty worktree 做只读比对并确认归属；确认前不清理任何本地分支或 worktree。
2. 单独审计 `9c0b63b0` 的行为是否已被后续 main 覆盖；结果再决定是否另建补救 space。
3. 从 #166 开始，每个 issue 独立建 space / branch / worktree，按 BDD + TDD 完成并等待 main CI 后再关闭 issue；接着处理 #168、#167。
4. 另开一次产品决策，只处理 Test Recorder 的并入/保留选择，不和上述 bugfix 混做。

## 本次整理的边界

- 已补齐当日 memory，并把 Test Recorder README 中过时的“直接进入 P0 实现”表述标为历史记录，明确以 2026-07-11 的待定裁决为准。
- 未修改产品代码、未触碰任何遗留 worktree、未创建 space、未推送或关闭远端事项。
