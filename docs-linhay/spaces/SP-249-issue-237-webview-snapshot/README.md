# SP-249 · #237 WebView snapshot JavaScript

状态：本地实现与根包验证通过，待主控整合/用户 iOS 验收；基线 `30185dc2`，分支 `feat/SP-249-issue-237-webview-snapshot`。影响 embedded runtime shared script，不新增控制面；CLI 版本与嵌入 SDK 版本分别核对。

## BDD 与边界

- Given 当前源码生成的 snapshot，When JavaScriptCore/WKWebView 执行默认 includes 或 forms-only，Then 脚本可解析并输出有界可解码结果。
- Given 含引号、反斜杠、换行或选择器符号的 id/name，Then selector 精确匹配原字段，不把属性值变成选择器语法；snapshot → form focus 保持同一目标。
- Given 超过节点/文本限制或密码字段，Then 保持截断和 length-only 字段值语义。
- Given snapshot 脚本异常，Then 恢复提示检查嵌入 SDK/脚本兼容性，不将语法错误简单归因于节点数量。

原报告 CLI 0.2.36 配嵌入 SDK 0.2.29；当前源码仍需独立检查。仅使用合成页面，不操作其他任务模拟器或私有 App。测试、整合、发布及真实 iOS 用户验收分别报告。不提交、推送、合并、发版或关闭 issue。

## 验收结果

实际生成 JS 的旧代码在 JavaScriptCore 复现与 issue 完全一致的 getAttribute 语法错误。改用 Swift 原始字符串保留 JS 转义，特殊 id/name 按 CSS 字符串转义；form resolver 使用浏览器 querySelector 解码属性选择器。snapshot 错误提示明确区分 CLI 与嵌入 SDK。

定向 JSC + macOS WKWebView 2/2、最终根包403项/63套通过；默认 includes 直接读取请求模型，另验 forms-only。14个带引号、反斜杠、换行、制表符、选择器符号和中文的字段在两组 includes 下完成实际DOM选择与focus同目标验证。公开规则已补版本/脚本/选择器证据边界。详细证据见[验证报告](plans/20261030-validation.md)。

本独立基线未含其他任务SP-244～246，docs两门禁停于连续编号校验；主控负责联合真实文档快照验证。未提交、合入main、远端写入、发布或关闭issue；没有私有 App 或真实 iOS SDK接入验收。

主控已完成候选审查与联合文档快照验证，详见[交付复核](plans/20261030-controller-review.md)；独立分支缺前序Space、真实设备与发布边界继续保留。

2026-10-30合并前核对发现主目录已登记SP-247-rhine-page-preferences；仅本轮未提交issue候选调整为SP-249。旧证据保留原采样路径，当前worktree/branch与目录均使用SP-249。

## 2026-10-30 持续授权与整合候选

用户已将开发、测试、提交、推送及合并main纳入定时任务授权，首轮待授权/不提交约束仅为历史阶段。当前以远端main及SP248候选为前置，重放本issue独立差异；排除本地30185dc2旧日检文档。SP244–247为真实登记摘要、其产品WIP不纳入；SP248与本issue分开提交审阅。现场SDK升级/真实iOS验收、issue关闭和发布仍独立。
