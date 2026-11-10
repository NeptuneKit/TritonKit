# SP-256-issue-245-compact-schema

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

状态：PR #253 已合入 main 137afac6，已随 v0.2.39 发布并通过制品/安装验证。关联 GitHub #245；影响 CLI schema 只读契约，保留默认完整输出模式与 response 模型/选择行为；权威元数据补齐见下，不改变设备动作。

## BDD与验收

- Given显式叶子command，When请求opt-in compact schema，Then返回有效继承参数、selector约束、适用output contracts、安全/失败/副作用语义及稳定版本与fingerprint。
- 默认完整输出模式与 response 模型/选择行为兼容；无叶子、未知命令和非法组合返回单JSON错误，不访问设备。
- act.type/test.run真实进程测量payload bytes，排除无关siblings；不能用缩小payload宣称runtime速度提升。
- 先失败测试，再最小实现；focused/full CLI、真实argv与docs门禁、必要CI通过后合main；按持续授权纳入后续发布。

## 归属与边界

基线origin/main 9b3dd908。分支feat/SP-256-issue-245-compact-schema；工具创建的隔离worktree为/Users/linhey/.codex/worktrees/sp-256-issue-245-compact-schema/TritonKit。桌面create_worktree未提供自定义父路径，使用返回路径，未使用主目录WIP。SP252–255仅登记既有全局占号，不混入参考产品成果。主控负责整合、验证、发布与memory；issue不自动关闭。

## 本地实现与验证

实现与边界见 [compact 契约](plans/20261102-compact-schema-contract.md)。CLI-only DTO/resolver，不修改 shared schema wire model；源 schema 补齐 act.type text 二选一与 test.run 既有 local VLM flags。

- 初始 RED：新接口缺失导致测试编译退出 1；同基线真实进程拒绝 `--compact`，退出 64。
- 第一版 focused GREEN：7/7；真实 JSON bytes：act.type 104181 → 26705，test.run 80698 → 28215（含终止换行）。本组数字属于第一版候选，后续约束审查修订后必须复测。
- 主控审查后补强 scoped selectorConstraints：legacy singleton alternatives 不解释为每组必选；多层 complete sets 保留 source。补 alias narrowing、positional/required override 与 VLM parse-only 测试，最终 compact 13 项与 SchemaFactSource 124 项共 137 项 focused GREEN；真实进程复验通过；完整 CLI exit 0（XCTest 162，Swift Testing 1674 / 176 suites；3 项既有条件跳过单独登记）。当前候选字节与详细边界见 [验收记录](plans/20261102-validation.md)，不沿用第一版测量冒充当前数据。
- 原始日志保存在 worktree 外 `TritonKit-worktrees/archives/SP256/`；没有复制其它 worktree build products，没有设备/模型调用。

## 整合检查点

精确候选296f1b07，经独立审阅、完整CLI、root与本地总门禁及PR CI通过，2026-11-02 09:06 UTC合入远端main 137afac6。合后CI已通过，发布验收见顶部SP264。源schema遗漏由#247/#250继续修正，compact成功不证明全库parser parity；未关闭issue；此段为初次整合证据，后续v0.2.39已发布。
