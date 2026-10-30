# #237 首轮本地验证 · 2026-10-30

> 历史阶段记录：当时的未提交、待授权或待整合描述不再是当前状态；最终交付见[合并验收](20261030-merged-validation.md)。原失败与未验收证据保留。

> 历史证据：首轮基线30185dc2、旧SP247编号；当前已改为SP249并获持续提交/合并授权，前序Space已真实登记。原日志和失败不改写成后续状态。

## Requested / Observed

要求修复当前源码WebView snapshot生成脚本语法错误，并保留有界和脱敏输出。用户报告CLI0.2.36搭配嵌入SDK0.2.29；在首轮历史基线30185dc2独立复现，不把CLI升级当作SDK升级。影响层为embedded runtime JavaScript及错误提示，无Web业务写入或新HTTP契约。

## Evidence / Fixes made

- 红测试命令：`swift test --build-system native --jobs 2 --no-parallel --filter TKRuntimeWebViewSnapshotExecutionTests`；exit1，JavaScriptCore抛出 `SyntaxError: Unexpected string literal " + element.getAttribute(". Expected ')' to end a compound expression.`。日志 `.build/issue237/red.log`。Swift编译成功并不证明生成JS可解析。
- 修复：snapshot模板改用Swift原始字符串；name及非简单id按CSS字符串编码，普通id保持#id；form resolver移除不解码CSS转义的手动name截取，交由querySelector。错误hint不再建议靠减少节点修复语法错误。
- 首次WK fixture测试失败 `.build/issue237/green.log`：初始about:blank也满足readyState，页面导航覆盖fixtureFields。这是测试装载竞态，已用合成页面唯一title绑定readiness，失败保留不计通过。
- 定向JSC + macOS真实WKWebView两测试通过 `.build/issue237/green-retry.log`，随后将默认includes改为直接取`TKWebViewSnapshotRequest().include`，最终全量覆盖更新测试。
- 最终 `swift test --build-system native --jobs 2 --no-parallel` exit0，403 tests / 63 suites，2.363s；`.build/issue237/root-final.log`。native显式限制自身冷编译jobs2；工具提示native未来弃用，当前版本仍执行成功。
- 默认includes/forms-only两组分别验证14个合成字段的querySelector和form focus准确目标；JSC检查节点/文本截断及密码length-only不泄露原值。
- `git diff --check`通过；新增文件亦逐个执行no-index whitespace check。
- `docs-linhay/scripts/verify.sh --ci-docs` 与 `docs-linhay/scripts/check-docs.sh`：首轮旧分支失败于 `space registry IDs must be contiguous from SP-001: SP-247-issue-237-webview-snapshot`。当时基线只有SP001～243，SP244～246为其它任务WIP，未造占位资料；主控在联合实际文档快照补验。日志 `docs-ci-retry.log` / `docs-check-retry.log`。

## Gaps / Remaining risk

本轮没有启动Simulator，没有在原私有App更新SDK，也未验证iOS/UIKit端完整请求路由；macOS WebKit只证明相同生成脚本与DOM行为。CLI/HTTP未改变实现，未重跑CLI完整套件；CocoaPods和发布门禁未运行。首轮结束时真实iOS匹配SDK/CLI后的用户验收、联合文档门禁及远端动作未完成；当前进度以space README与后续整合记录为准。无新增依赖或公开私有证据。

经验已写回既有public WebView reference并登记EXPERIENCE；新经验为生成脚本必须实际执行、CLI/嵌入SDK分别取证、CSS编码与consumer对称解析。
