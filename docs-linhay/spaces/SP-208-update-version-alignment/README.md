# SP-208 更新检查与版本对齐

## 边界

修复用户反馈的 CLI Homebrew 更新误报、升级后版本核验和 public skills 同版本验证。影响 CLI、schema 与 public update skill；不修改设备、HTTP 或 Web 行为。独立分支 `feat/SP-208-update-version-alignment`，worktree `../TritonKit-worktrees/SP-208-update-version-alignment`。

## BDD 与验收

1. Given Homebrew旧CLI，When check/dry-run，Then查询GitHub目标版本，输出明确目标与是否可更新，不执行brew写操作；查询失败必须失败，不能报已最新。
2. Given执行升级，When未确认，Then无副作用；确认后brew刷新、升级并读取实际安装的CLI版本，未达目标时报明确错误。
3. Given GitHub领先tap或请求旧版，Then不将错误版本报告为成功，不继续安装不一致的skills。
4. Given skills包元数据缺失/版本不符，Then安装前拒绝；正确bundle安装并核验版本。
5. 保留单一JSON失败envelope；回归CLI参数/分发、完整CLI和本地门禁，真实网络只读check另记，fixture不冒充用户安装验收。

## 状态

实现与验证完成，按用户“合并 main 后清理 worktree / branches”授权整理本地候选提交，待主控合入 main。未推送或发布，用户回复未发送。

- [验收与阶段边界](plans/validation.md)：完整CLI1466+59、focused26、本地总门禁通过；主工作区回写后focused27与docs门禁通过；真实进程6场景及只读网络check通过，独立审查无剩余阻断。
- [TDD证据](plans/runtime-tests.md)、[候选摘要](plans/candidate-files.json)、[进程验收](plans/process-results.json)、[用户回复草稿](plans/user-reply.md)。
- 当前main包含SP-206未发布安全改动，现有发布脚本要求从main发布；需要明确此次是否联合发布，不能将处理本次更新缺陷自动推导为另一批改动的发布授权。
- Xcode/真实设备与反馈用户安装场景未验收；此轮CLI行为验证不需要设备。
