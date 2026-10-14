# SP-192 会话整理与 main 集成

状态：完成。提交已合入本地 main，集成后本地总门禁通过。用户授权“整理，沉淀，提交，合入 main 分支”。本次仅集成本 space；其他 worktree 保持原状，远端推送和发布不在本次范围。

## 已验收内容

- 五项机制：alias 新鲜度、遍历预算、视觉 settle、Vision OCR 候选、非 UI 健康诊断与 unknown 动作保护；CLI/HTTP 和只读 DTO 合同同步。
- 完整 CLI 1250 项，macOS 59 runtime / 274 shared，Web hierarchy 12 项与 TypeScript/Vite build；真实只读 Simulator AX/alias/OCR/settle 已通过。
- 用户授权处理限制后：iOS runtime xcresult 115 passed / 0 failed / 0 skipped；Android 8 suites / 52 项及完整 Debug APK 构建通过。本地总门禁和 docs 门禁已复跑通过。
- 真机、完整 App alert presentation、OCR 到输入坐标映射、native 硬取消与完全相同 host 树重启识别的边界保持明确。

## 可复用模式

1. 超时只结束等待，不宣称取消原生动作；unknown 保留占用和审计，不自动重放。
2. 视觉 settled 不证明业务成功；OCR 只返回有出处的候选，文件 mtime 不伪装成截图采集时间。
3. 每帧截图使用唯一私有产物路径，兼容 host 产物不覆盖策略；原始设备树、画面和日志不进入提交。
4. UIKit 共享窗口测试在同一外层串行 suite 执行；alert 路由夹具先证明真实挂载、responder 和同坐标背景 candidate，不能以不存在背景目标得到伪绿。
5. UIView.alpha 与 backing layer.opacity 联动，组合 patch 按真实 view→layer 顺序断言最终值，独立入口各有覆盖。

模式已写入现有内部 ops governance 与三个对外 skill；无需新增 AGENTS 规则、依赖或锁文件。构建产物与私有验证脚本仅保留在 gitignored 目录。

## 提交与集成步骤

1. 审计本次全部 tracked/untracked 文件并显式暂存；主工作区仅提交本次已同步的文档和 skill，避免 untracked 文档阻塞合并。
2. 在 feature 分支提交实现、测试和文档；用 merge-tree 做冲突预检，逐文件保留完整验收记录。
3. 在本地 main 合入 feature，复跑 verify.sh --local 与必要文档检查；确认两处工作区仅剩预期状态。
4. 写回实际提交和集成结果，形成最终整理提交。保留 worktree 与私有验收产物，不清理其他任务或历史分支。

## 实际提交与预检

- 文档与模式沉淀：`84c67f88`（主工作区仅包含已审计的本次文档和 skill）。
- 实现、测试与合同：`e308a2eb`（102 个本次文件，6006 insertions / 1374 deletions；无私有日志、图片、APK或构建目录）。
- `git merge-tree --write-tree main feat/SP-192-ictrl-adoption-feasibility` exit 0，无冲突；主工作区干净后以 `--no-ff` 合入，merge commit `da76a708`。
- 合并 tree 与 feature commit tree 完全相同（`git diff HEAD^2 HEAD --name-only` 为空），无需 integration source fix。
- 暂存后完整 diff-check 发现两个新文件多余 EOF 空行，已去除；仅格式清理，不改变实现行为。只读 visual 与 health 审计均无阻塞：确认 settled/business/候选边界，以及 timeout 占用、独立 ping、禁止 unknown 自动重放与 Release no-op。

## main 最终验证

- main `verify.sh --local` exit 0：根 macOS runtime/shared tests、SwiftPM 依赖边界、Debug 隔离、Release CLI build/schema/action smoke、Harmony/iOS fixture smoke、真实 iOS Simulator build、docs/diff 全通过。
- 合并未改变已验收 feature 的源码 tree；完整 CLI1250、iOS115、Android52及APK、Web12/TS/Vite与真实只读观察证据沿用该相同 tree 的实际结果，不将 main build 当作新的设备运行证明。
- main 文档状态、INDEX/overview 与每日 memory 写回已完成。branch/worktree 保留，包含 ignored 私有验收产物；其他 worktree 未处理。没有 push、release、tag 或 GitHub 写入。
