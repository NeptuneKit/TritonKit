# SP-204 实施与验收边界

- 候选：`feat/SP-204-ictrl-log-privacy`，基线 `dd613a994abe45aa14e072c381662a0e3d868f03`；所有实现/测试在同名独立 worktree。
- 影响层：CLI 服务端 `handleResponse` 的 stderr 诊断。不改变 HTTP/CLI 返回值、响应缓存、JSON envelope、SDK 或 Runner。原始业务数据仍按请求返回调用者，不宣称其已脱敏。
- 权威来源：主工作区 SP-202 评估只读使用；本 space 原样复制后补充本计划。共享索引和 memory 由主控集成时更新。
- 无外部依赖、新命令或环境配置。serve 当前没有 verbose；日志 helper 不提供 payload 放开开关，任何其它 verbose 设置也不能开启原文路径。

## BDD

1. Given 未知消息类型、任意嵌套秘密字段、超长多字节内容，When 真实 `handleResponse` 处理，Then stderr 只含固定分类及字节/计数，不含未知键、字符串或 payload，单条至多 512 UTF-8 字节（含换行）。
2. Given 普通响应、hierarchy/appInfo 或 manifest 的身份/文本/SDK 字段，Then 日志不含原文；response、hierarchy 缓存及 registration 仍按原值处理。
3. Given id=0 ping，Then 维持既有静默及不缓存。Given 普通健康 ping，Then 聚合成功计数；失败、异常健康状态、无效 payload 始终产生有界元数据事件。
4. Given `ok:false`、legacy TKErrorPayload 或非空 error，Then 保留失败分类及累计失败数，错误 message/code/hint 原文不进日志，业务 payload 保留完整。
5. Given 并发调用或失败紧随成功，Then 日志计数线程安全，失败仍可观察；日志策略不创建额外 stdout / envelope。

## 执行顺序

1. 用真实 stderr 文件捕获写旧实现可编译的负例，记录实际行为失败（不是编译失败）。
2. 实现独立、线程安全、可注入 sink 的元数据 logger，接入 handleResponse；仅成功 ping 聚合，其它响应一帧一行。
3. 增加聚合、失败计数、无效数据、枚举白名单和业务字节完整性测试，运行 focused / 完整 CLI / 根包与适用门禁。
4. 若门禁引用主目录未提交 space，复制所需文档作为上下文，逐项标记为非交付文件；不改其内容。
5. 本地门禁中可选 iOS build 明确跳过，不操作设备。受控本地测试使用隔离端口与独立进程。无提交、推送、合并或发布。

## 字段白名单原则

只记录经强类型解析的 request enum、整数 request ID、frame/payload 字节数、本地计算的结果分类和累计计数；必要 UI 状态只接受 `TKRuntimeUIHealthState` 已定义枚举。禁止从任意字典枚举键名，禁止打印 app/device/bundle/SDK/name/title/message/code/hint/token 等输入字符串。日志边界只保护本响应入口，不把它等同于全进程日志或上游环形缓冲。
