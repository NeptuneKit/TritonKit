# SP-249 · #237 WebView snapshot JavaScript

当前状态：独立修复已提交并重放至远端main dba41b6e + SP248前置候选；等待最终整合检查与PR CI后合并main。分支 `feat/SP-249-issue-237-webview-snapshot`，同名worktree。前序SP244–247已真实登记，不包含其产品WIP；不捎入本地30185dc2旧日检文档。

## BDD 与边界

- Given 当前源码生成的 snapshot，When JavaScriptCore/WKWebView 执行默认 includes 或 forms-only，Then 脚本可解析并输出有界可解码结果。
- Given 含引号、反斜杠、换行或选择器符号的 id/name，Then selector 精确匹配原字段，不把属性值变成选择器语法；snapshot → form focus 保持同一目标。
- Given 超过节点/文本限制或密码字段，Then 保持截断和 length-only 字段值语义。
- Given snapshot 脚本异常，Then 恢复提示检查嵌入 SDK/脚本兼容性，不将语法错误简单归因于节点数量。

原报告 CLI 0.2.36 配嵌入 SDK 0.2.29；已在首轮源码独立复现。仅使用合成页面，不操作其他任务模拟器或私有 App。测试、整合、发布及真实 iOS 用户验收分别报告。提交、推送和合并已获持续授权；发布与关闭issue仍不在授权内。

## 验证与交付边界

首轮旧源码真实复现getAttribute SyntaxError；原始Swift字符串保留JS转义，CSS属性编码与form resolver对称解析。JSC/macOS WKWebView默认includes和forms-only、14字段selector/focus往返及根包403项通过，未变更该已验生产/测试源码。当前包含SP248共享错误码后的整合root复跑与docs门禁单独记录。

用户已授权开发、测试、提交、推送、PR及通过检查后合并main；尚未推送/合并/发布。真实iOS匹配SDK/CLI及原私有App验收未执行，issue保持开放。详见[首轮证据](plans/20261030-validation.md)和[阶段复核](plans/20261030-controller-review.md)。

## 编号历史

首轮未提交候选曾使用SP-247-issue-237-webview-snapshot。合并前发现主索引已有SP-247-rhine-page-preferences，仅将本轮未提交候选调整为SP-249；原证据的SP247路径/错误字符串保留历史含义，未改他人的编号。
