# SP-202 — iCTRL 更新采用评估

## 状态与边界

- 用户请求：评估 iCTRL v1.98.12 的更新哪些值得纳入 TritonKit。
- 状态：评估完成；后续SP-203～205已实施，由SP-206联合验证与本地整合。
- 影响层：文档与 memory；建议涉及 CLI serve、embedded SDK 发现和连接、Runner 协议与日志。HTTP 仅考虑复用现有只读状态，不新增 Web/Wails 写控制面。
- 本次是当天只读源码评估，在主工作区完成；基线 `main@dd613a994abe45aa14e072c381662a0e3d868f03`。保留已有 SP-201、CLAUDE.md 及其他未提交改动；未提交、推送或发布。
- 上游事实沿用 [SP-193 增量报告](../SP-193-ictrl-reference-tracking/plans/20261016-v1-98-12-update.md) 的固定 SHA `d88bbf0b3a5addead31b4298d605d7ac7a87d6e7`，不把上游说明当成本地运行证明。
- 评估与后续切片、文件面和验收条件见 [采用评估](./plans/20261016-assessment.md)。用户随后授权拆新会话执行，已登记 SP-203～205 实现 space / 独立 worktree；此授权不改变监控任务边界。

## BDD 与验收

1. Given 上游新机制，When 对照当前 main 源码与既有测试，Then 分清已有保护、实际缺口、验证缺口和未来扩展，不重复立项已经实现的机制。
2. Given 默认 serve 仅绑定 loopback，When 评估发现边界，Then 分别核对广播与 SDK 自动连接，不能推出“没有 LAN 广播”或“发现即认证”。
3. Given 已有 Runner 和配置存储，When 比较身份与配置安全，Then 记录现有会话/USB Serial 绑定及预检/原子替换，单独保留本机恶意监听器与运行态配置事务边界。
4. Given 仅评估，When 收口，Then 保存建议排序、验收场景、来源和风险，完成文档门禁，不宣称已修复或通过产品测试。

## 验证与沉淀

源码和已有测试只读复核已完成；Runner 子任务为只读审计，主控复核了关键身份、凭据和传输代码。产品代码未改，未运行 Swift/Web 测试、上游程序、服务或设备；安全结论是静态审计，未做攻击复现或兼容性实测。

2026-10-16：`verify.sh --ci-docs`、独立 `check-docs.sh` 与 `git diff --check` 均通过，202 个 space 登记一致；新增报告的本地链接核对通过。文档门禁不代表建议的功能已实现或已通过安全运行验收。

经验写回原 [iCTRL 参考档案](../../dev/ictrl-reference-tracking.md) 与当日 memory；Bonjour 结论承接 [SP-129 剩余风险](../SP-129-serve-loopback-default/README.md)，不重复计作新缺陷或已有修复。

## 用户授权后的分派

2026-10-16 用户要求拆新会话执行，已登记 [SP-203 发现与连接](../SP-203-ictrl-discovery-hardening/README.md)、[SP-204 日志隐私](../SP-204-ictrl-log-privacy/README.md)、[SP-205 Runner 鉴权](../SP-205-ios-runner-auth-hardening/README.md)。评估本身保持完成状态；实现与验证结果分别归属新 space，不自动提交、推送或发布。
