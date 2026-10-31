# SP252 / SP253 本地主线收口

实现86662bfe、冻结候选02e7b1ae经独立静态审查及执行者完整CLI后，merge-tree无冲突，于本地main合并为56ef7719266d90f79548b649054710058266f78f。主目录产品路径blob与冻结候选一致；合前干净、候选归档27项hash均通过。

## 实现与验收

后台日志预检后以一次O_EXCL/O_NOFOLLOW/O_CLOEXEC open取得0600文件并直接构建FileHandle，竞争者叶子不能被替换；stdout/stderr各取得后立即defer关闭，保留原typed artifact与launch失败语义、nil/dev-null行为。内部注入seam使旧流程红测可确定性复现，不对外新增参数或依赖。

旧逻辑两轮red各exit1/16断言问题，focused green4测试函数/8场景通过。本机复现为FileManager.createFile替换竞争者叶子；hardlink/symlink目标sentinel未变，不能宣称目标被写穿。stderr retained引用验证新增显式close保障，不证明原ARC后的持续泄漏；launch失败为原行为回归保护。独立审查修正了fcntl=-1按位假通过与FIFO建立失败仍继续执行的夹具缺口。

| 验证 | 绑定候选 | 结果 |
| --- | --- | --- |
| 执行者完整CLI | 86662bfe | 162 XCTest + 1665 Swift Testing / 176 suites，exit0，3明确环境skip |
| 主控合后完整CLI | 56ef7719 | 相同162 + 1665结果，exit0；使用主工作区独立默认scratch |
| 主控适用local gate | 56ef7719 | exit0；SwiftPM/Debug隔离、root XCTest5与Swift Testing110+294、release CLI build/smoke、fake Harmony host和mock iOS runtime observe、docs/diff通过 |
| 主控docs-only收口 | 最终资料候选 | verify --ci-docs、独立check-docs（253 spaces）及diff通过；新增JSON/whitespace与归档hash另作不变量检查 |

根包真实Bonjour按既有开关跳过；local gate显式TRITON_VERIFY_XCODE=0，跳过Xcode模拟器build。未执行设备、用户App/长期detached服务、父目录替换、独立攻击进程、其他文件系统、第三方上游代码、签名/DDI、发布/安装接替或用户验收。测试精确0600基于本机正常umask，额外收紧umask可能更窄。

## 归档与清理

原始红绿/full日志、冻结4文件源码与候选、执行者27文件hash、10份ignored夹具文件已保存在仓外archives/SP-252-detached-log-exclusive-create。主控合后日志/结果、mock smoke目录和实际测试过的release CLI二进制保存archives/SP-253-detached-log-integration；[合并证据清单](20261031-evidence-manifest.json)逐文件记录size/hash（symlink单列target）。没有以.build作为唯一证据位置。

门禁通过后确认冻结tip为main祖先、工作区干净、执行停止，正常git worktree remove和git branch -d完成；仅移除本批SP252。执行聊天01a18fb4-0f41-73e2-a0b7-741aa13b2bc5经set_thread_archived返回archived=true，原始结果已保存。SP253复用当前长期主控聊天，保持开放，其他worktree/聊天原样保留。

当前17条采用均为local_merged且合并SHA可达main。无push/tag/release；本地实现、验收、合并、证据清理与执行聊天关闭均完成。经验回写SP252验证原文、独立审查及参考证据保管规则，保留昨日raw缺失的未知原因，不将今天归档冒充昨日恢复。
