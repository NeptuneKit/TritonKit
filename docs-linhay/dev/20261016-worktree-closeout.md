# 2026-10-16 本地 worktree 与分支收口

## 范围与验收

用户要求 worktree / branches 合并 main 后清理。本轮仅本地 Git 集成、验证及治理记录；不推送、不发布、不删除远端分支。延续[前次 worktree 收口](../spaces/SP-195-ios-runner-product/plans/20261014-worktree-closeout.md)和[分支收口](../spaces/SP-195-ios-runner-product/plans/20261014-branch-closeout.md)。

- Given 已完成候选，When 收口，Then 先确认 main 祖先关系或逐文件吸收证据，再删除工作区及本地分支。
- Given dirty/ignored 文件，When 清理，Then 保留恢复快照、原始证据和文件校验；不把旧文档状态重新合入 main。
- Given 其他会话正在合并，When 处理共享 main，Then 等待其结束后串行操作，不竞争共享索引或构建目录。
- Given 主仓已有其他任务 WIP，When 合并本轮候选，Then 按文件/hunk整合并保留其余内容，不使用 stash。

## 初始事实

起点 main 为 `3000be92`，另有9个registered worktree。

| 分支/工作区 | 初始证据 | 处理边界 |
| --- | --- | --- |
| SP-194-view-annotation（正式space SP-197） | clean，tip `cbb36000` 已是main祖先 | 清理已完成worktree及分支 |
| SP-196-upstream-optimization-delivery | clean，tip `f13c963b` 已是main祖先 | 同上；保留原始验证证据 |
| SP-200-mobile-device-parity | clean，tip `10acfae6` 已是main祖先 | 同上；纠正旧“待合并”记录 |
| SP-201-sdk-floating-picker | 另一会话正在处理main合并和冲突回归 | 等待原会话交付后再清理 |
| SP-203 / SP-204 / SP-205 | branch tip已合入main，工作区保留源候选WIP | 64个冻结文件SHA一致；main联合42文件SHA一致；归档历史快照后清理 |
| SP-206-ictrl-security-integration | 两个收口commit未成为main祖先，但整棵tree与main相同 | 补齐历史合并关系，保留main内容 |
| SP-208-update-version-alignment | 产品已验证，源worktree和主仓均保留未提交候选 | 独立提交候选、合入main并验证后清理 |

## 恢复与证据

仓库外私有目录 `../TritonKit-worktree-archives/20261016-worktree-cleanup/` 保留初始worktree/HEAD清单、`local-branches.bundle`、主仓WIP快照，以及各worktree的binary diff、文件归档与SHA256清单。bundle verify与已生成归档的逐文件读取校验通过。敏感原始日志不进入公开Git。

源SP-203～205未发生冻结后源码写入；main补强了Serve参数矩阵、Runner socket/deadline反证及说明。三个源工作区的SP-201旧HTML/验证记录只作为历史副本保留，不覆盖最新版。

## 执行与验证

- SP-201由原会话以`3f1b500a`完成本地main整合；原会话停止后本轮继续，未竞争main写入。
- SP-206整棵tree与原main `3000be92`相同，已逐文件确认；以`057d1012`仅补齐两条收口commit的祖先关系，保留当前main。
- SP-208候选`d61499ed`（24文件）以`6c120ccd`整合。无产品源码冲突，唯一冲突为当日记录，保留SP-201与SP-208各自段落。用临时index构造联合tree并保存双亲merge commit；产品文件逐字节核对，主仓其他WIP原样保留，已有发布审计文档另保留为未提交差异。
- 共移除9个worktree和9个本地feature分支；最终registered worktree仅主仓，local branch仅main。全部使用普通worktree remove与branch -d，无stash、reset、force或远端操作。
- SP-203/204/205/208的历史WIP保存为4条refs/archive/20261016-worktree-cleanup引用及独立bundle，校验通过后切detached快照并清理；快照不回灌main。
- 保留同级3个非worktree验证host目录（.sp196-release-host、.sp196-validation-host、.sp201-validation-host），包含真实验收上下文，不当空包装目录删除。

### 验证

- main `6c120ccd`：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`通过，根包291项、release CLI build/smoke、Harmony host与iOS runtime smoke通过。通用Xcode build显式跳过；SP-201本期107项iOS/启动回归及真实手势闭环沿用原会话证据，本轮不追加设备动作。
- `swift test --package-path CLI --no-parallel`：Swift Testing 1474项、XCTest59项通过。日志保存在主仓`.build/worktree-closeout-local.log`、`.build/worktree-closeout-cli.log`。
- 第一次local gate因会话中断在release build阶段停止，未计为通过；续跑完整门禁通过后才删除最后三个worktree。
- `verify.sh --ci-docs`、独立`check-docs.sh`、`git diff --check`及仅含候选提交文件的隔离文档树检查均通过（208 spaces、28经验校验用例）；产品未推送、未发布，未接替运行版本。

### 文档与经验

- 修正SP-200旧待合并状态与SP-151误改历史测试计数；各已清理space和两个索引同步。
- SP-208编号依赖既有SP-207连续登记：仅提交SP-207最小README登记与索引占号，完整流程/参考采用WIP保留主仓，不混入本次产品合并。
- 可复用的dirty候选归档、snapshot ref及非强制回收步骤补入原ops governance skill；没有新增AGENTS或产品经验。
