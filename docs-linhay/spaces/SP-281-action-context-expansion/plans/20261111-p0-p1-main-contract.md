# SP-281 P0/P1 — main 执行合同（2026-11-11）

基线：main `607410fb`，开始时工作区干净。用户明确要求在当前 main 串行开发；不创建分支/worktree、不推送发布、不操作设备。

## 已有基础

4d32a545 已加入 shared `TKActionReceipt` / `TKActionAdmissionCoordinator`，两类调用方已使用 admit；device.action 修复了 iOS failure/submitted-only 的执行误判并冻结文本。不得重复宣称这些为本轮新增。

## 本轮范围

1. shared receipt 作为 runner 和 device.action 的生产事实；兼容旧顶层字段，新增 `actionReceipt`。
2. device.action 处理 host 非零返回/throw、timeout、launch failure、iOS malformed/nested error、generation stale；失败不自动 replay，provider 错误码保留，原始 payload 不被成功字段覆盖。
3. 显式 `--evidence-dir` 只允许新目录；执行前预检。保存无原始参数、sourceCommand、auditPath、provider文本的 receipt 和标准 run/events/manifest。日志和原始 provider 响应本轮不导出；保留既有私有诊断入口。
4. 持久化失败不改 provider receipt 的 delivery/outcome；stdout 标 evidence failed，CLI 非零。不得把 evidence failure 反推成动作未执行。
5. generation 仅承诺进程内显式共享 store；不承诺跨 CLI 进程授权或全局锁。lease 检查仍沿用 opt-in HTTP check，非原子 check→provider 窗口明确保留。

## BDD/失败测试

- injected host exit 7 和 throw timeout：一个 host 调用，保留 action/admission receipt，unknown/uncertain/null，无 replay。
- double-tap 第二个提交失败：整体 unknown，不宣称 launch failure 等于零执行。
- nested iOS error 或 contradictory ok+error：非成功、原始 error code 不丢。
- evidence success：标准 JSONL 可解析，receipt refs/digests 可追溯，无输入文本和私有绝对路径。
- evidence root 已存在/符号链接/目录碰撞：零 provider 调用，不覆盖原文件。
- evidence 中途写入失败：provider事实不变，persistence failed；不伪造成功 manifest。
- lease gate 拒绝：零 provider调用，证据记录 not_started，原CLI错误语义保留。
- old generation返回：终态unknown，保留旧action独立receipt，不污染新generation。

## 文件面

- shared receipt/coordinator扩展；CLI device action execution/projection/evidence；runner兼容receipt投影。
- 对应shared/CLI tests、schema、agent CLI说明、SP-281与当日memory。
- 不做P2全量action迁移、approval UI、remote admission、session resume或签名/DDI。

## 验证

先运行新增失败用例证明现有缺口，再集中实现；冻结module后串行focused/shared/root/CLI、local与docs门禁。独立只读review只给证据，主控复核后收口。数值测试结果必须绑定当前候选，历史304/1685不代替本轮结果。
