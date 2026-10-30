# SP-249 · #237 WebView snapshot JavaScript

当前状态：已通过 [PR #240](https://github.com/NeptuneKit/TritonKit/pull/240) 合入远端 main，merge `88cdbba25f91c5047abcd40c62db79a888fda970`；精确候选 CI 通过，合并后 CI 全部必要检查通过。分支 `feat/SP-249-issue-237-webview-snapshot`，同名 worktree；原始实现分支与本地证据保留。

## BDD 与边界

- Given 当前源码生成的 snapshot，When JavaScriptCore/WKWebView 执行默认 includes 或 forms-only，Then 脚本可解析并输出有界可解码结果。
- Given 含引号、反斜杠、换行或选择器符号的 id/name，Then selector 精确匹配原字段，不把属性值变成选择器语法；snapshot → form focus 保持同一目标。
- Given 超过节点/文本限制或密码字段，Then 保持截断和 length-only 字段值语义。
- Given snapshot 脚本异常，Then 恢复提示检查嵌入 SDK/脚本兼容性，不将语法错误简单归因于节点数量。

原报告 CLI 0.2.36 配嵌入 SDK 0.2.29；已在首轮源码独立复现。仅使用合成页面，不操作其他任务模拟器或私有 App。测试、整合、发布及真实 iOS 用户验收分别报告。提交、推送和合并已获持续授权；用户随后明确授权主动验收与发布；关闭issue仍不在授权内。

## 验证与交付边界

首轮旧源码真实复现getAttribute SyntaxError；原始Swift字符串保留JS转义，CSS属性编码与form resolver对称解析。JSC/macOS WKWebView默认includes和forms-only、14字段selector/focus往返及根包403项通过，未变更该已验生产/测试源码。包含 SP248 共享错误码的精确组合候选，远端根包 404 项 / 64 suites、CLI Release 编译与标准 CocoaPods lint 通过；实际候选 docs 门禁通过。

实现、推送、PR 与远端 main 合并已完成，已随v0.2.37发布。2026-10-30真实iOS27 Simulator匹配当前SDK/CLI验收已通过：3项App-host测试与17字段focus/readback。原私有App未升级/未验，issue保持开放；安装版0.2.37快照复验通过。最终状态见[合并验收](plans/20261030-merged-validation.md)，历史过程见[首轮证据](plans/20261030-validation.md)和[阶段复核](plans/20261030-controller-review.md)。

## 编号历史

首轮未提交候选曾使用SP-247-issue-237-webview-snapshot。合并前发现主索引已有SP-247-rhine-page-preferences，仅将本轮未提交候选调整为SP-249；原证据的SP247路径/错误字符串保留历史含义，未改他人的编号。

本轮真实验收及发布状态见[SP250](../SP-250-release-v0-2-37/plans/20261030-release.md)，取代旧合并验收报告中“真实环境尚未验”的阶段状态；原私有App边界继续保留。
