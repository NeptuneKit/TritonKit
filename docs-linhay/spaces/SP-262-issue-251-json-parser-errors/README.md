# SP-262-issue-251-json-parser-errors

状态：调查与失败测试。关联 GitHub #251。

## 边界与 BDD

影响层仅 CLI 入口与 schema 输出契约。显式 `--json`、`--format json` 或 `--format=json` 请求的 parse/validate 失败在 stdout 输出单个 JSON、stderr 为空、exit 64，且不运行 command；运行阶段原有 domain envelope 不二次包装。缺失参数、未知选项、额外参数、非法标量及组合校验分型，输出仅受信任命令/字段名称与计数，不回显参数值或原错误文本。help/version 保持传统成功输出；没有有效 JSON 请求时保留传统 parser 行为，单独非法 format 回退文本。`--` 后的字面量不作为输出请求。

BDD 与验证矩阵见[验收计划](plans/20261102-parser-contract.md)。不操作设备、服务或私有App；全部验收可由agent独立完成。安装版0.2.38的三个安全parser进程均exit64/stdout空，已保存[实际RED证据](plans/20261102-parser-red.json)；生产最小修复和测试候选待主控Swift槽验证，未宣称GREEN。新增Swift测试未在旧源码执行，RED来自已发布旧版真实进程。

## 归属与验收

分支 feat/SP-262-issue-251-json-parser-errors；worktree `../TritonKit-worktrees/SP-262-issue-251-json-parser-errors`。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和 CI 通过后合并，issue 保持开放。
