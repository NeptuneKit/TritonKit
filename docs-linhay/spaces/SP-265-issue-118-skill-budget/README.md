# SP-265 Feedback skill mandatory-read budget

## 范围

跟进 [issue #118](https://github.com/NeptuneKit/TritonKit/issues/118) 在 0.2.38 的新增反馈：入口虽只有 144 行，UTF-8 仍接近 29 KB。影响层为公开 skill 文档与打包校验；不修改 CLI/SDK，不将文档体积下降宣称为运行时性能提升。

## BDD

- Given 普通反馈任务，When 读取入口，Then 一次读取仅包含原则、最小流程、按需路由和安全边界，最多 150 行、8192 UTF-8 字节、单行 600 字符。
- Given discovery/reliability/picker/host/Xcode 特定反馈，Then 入口能定位专用参考，原有详细证据和安全要求不丢失。
- Given 压成长行、中文多字节膨胀、失效参考或专用段落回灌入口，When 打包，Then 在创建公开 tar 之前失败。
- Given 合法入口与参考，Then 命令 schema 验证、版本 stamp、打包与安装验证继续通过。

## 归属与验收

分支 `feat/SP-265-issue-118-skill-budget`，同级独立 worktree；主控负责共享索引、memory、提交、整合与发布。执行者仅维护 feedback skill、布局门禁与相关测试。

[验证记录](plans/20261102-validation.md)。本地候选，不等同已发布；issue 不关闭。

## 当前结果

入口49行/4784字节，布局10测试与公开包31测试通过；详细契约搬移保留。docs gate 尚待主控共享索引登记后复跑。候选已冻结，未提交/整合/发布。
