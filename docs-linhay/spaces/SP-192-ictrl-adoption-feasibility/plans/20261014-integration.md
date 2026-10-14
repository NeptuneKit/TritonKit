# SP-192 会话整理与 main 集成

状态：执行中。用户授权“整理，沉淀，提交，合入 main 分支”。本次仅集成本 space；其他 worktree 保持原状，远端推送和发布不在本次范围。

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
