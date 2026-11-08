# SP-276 — Harmony 空白文本读取保真

## 范围与归属

来源：GitHub #246 的2026-11-04评论。影响 shared core layout parser 与 CLI observe/find/wait 的文本读取；不操作设备、不修改SP257人工IME候选、不证明HDC输入送达或业务成功。原私有App现场仍为范围外历史未验证项。

分支 `feat/SP-276-issue-246-whitespace-readback`，同级隔离worktree；主控拥有shared parser和测试、CLI测试、文档。其他WIP保留。

## BDD

- Given text/originalText 含纯空格、换行、制表符或边界空白，When layout被解析并编码为observe JSON，Then 原值逐字符保留。
- Given text为空串/缺失/null/非字符串，Then 维持nil语义和originalText回退；identifier/type等元数据仍按既有规则trim。
- Given 精确find/wait文本条件，Then 只匹配原值，不能将带边界空白的值当作裁剪后的词。

## 验收

先失败测试，再最小修复；共享parser测试、CLI观察JSON与wait路径、完整包回归及必要CI。该确定性JSON转换可通过本地fixture独立完成验收，真实IME输入、clear、延迟业务状态不在此切片。

## 进度

2026-11-08：基于远端main bd0b1dbd建立候选，独立只读审计确认cleanString误用于内容字段。测试与修复进行中。
