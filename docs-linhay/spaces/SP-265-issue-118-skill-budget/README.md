# SP-265 Feedback skill mandatory-read budget

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

## 范围

跟进 [issue #118](https://github.com/NeptuneKit/TritonKit/issues/118) 在 0.2.38 的新增反馈：入口虽只有 144 行，UTF-8 仍接近 29 KB。影响层为公开 skill 文档与打包校验；不修改 CLI/SDK，不将文档体积下降宣称为运行时性能提升。

## BDD

- Given 普通反馈任务，When 读取入口，Then 一次读取仅包含原则、最小流程、按需路由和安全边界，最多 150 行、8192 UTF-8 字节、单行 600 字符。
- Given discovery/reliability/picker/host/Xcode 特定反馈，Then 入口能定位专用参考，原有详细证据和安全要求不丢失。
- Given 压成长行、中文多字节膨胀、失效参考或专用段落回灌入口，When 打包，Then 在创建公开 tar 之前失败。
- Given 合法入口与参考，Then 命令 schema 验证、版本 stamp、打包与安装验证继续通过。

## 归属与验收

分支 `feat/SP-265-issue-118-skill-budget`，同级独立 worktree；主控负责共享索引、memory、提交、整合与发布。执行者仅维护 feedback skill、布局门禁与相关测试。

[验证记录](plans/20261102-validation.md)。PR #263 已合入 main；发布及安装验收由 SP264 收口，issue 状态不变。

## 当前结果

入口49行/4784字节，布局10测试与公开包31测试通过；详细契约搬移保留。docs/打包/安装与精确 CI 已通过，已合并并随 v0.2.39 发布，公开包和两处 skills 安装验证通过。
