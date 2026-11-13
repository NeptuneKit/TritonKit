# RevylAI/revyl-cli · 2026-11-13

结论：本日安全文本增量审阅完成，未证明 TritonKit 新的可直接采用缺口；整体仍 partial，不推进成功检查点。

固定范围：`dd8c128d8043ca09961fb6e59d0a0cfe95d923ed` → `ebc0e69c8849dba4585b892f07058441127a311b`，实际 main `366ae99b4be84b44e8e0718b39f278315d7c4c96`。base 是前次观测，不是成功检查点。完整历史仍从 `a50ee179e5c01a1f25f15cef951a78eddab5fa3e` 起，11/11 的 83 commit 语义/来源缺口保持；11/12 的 14 commit 与今日 19 commit 分开记录。未改旧归档、metadata 或仓内文件。

## 读取证据与边界

- 完整提交分页到 base：19 commit、19 parent edge、20 nontruncated recursive tree，119 个变化路径。
- 115 个安全文本路径、228 个完整 UTF-8 blob、10,878,439 字节，逐个校验 Git blob SHA-1、大小、SHA256。4 个 `scripts/__pycache__/*.pyc` 在取 blob 前排除，具体路径见 manifest。
- 逐 parent 非 JSON diff 7,888 行；JSON 全量对象值差异 49 项；Go 非 generated 增量独立摘录 2,755 行。已阅读这些完整增量和相关代码上下文；完整 blob 下载不等于声称读过全部未改动历史。
- 全部 release 两页来自本日 metadata；v0.2.8 与 v0.2.4 正文全文留 `review-release-notes.md`。正文只有安装、standalone computer、embedded skill、checksum 等说明，不能从版本号猜机制。HEAD `VERSION=0.2.10`、最新非 draft `v0.2.8`、插件 runtime pin `0.1.215` 三者分别记录。
- 许可证 API 404。README/Python/plugin 自述 MIT 不能替代许可证全文；不复制代码、不新增依赖。发行二进制与远端服务来源未验证，不能用 schema 或源码宣称部署验收完成。

## 机制裁决

| 机制 | 读到的实际变化 | TritonKit 对照与裁决 |
|---|---|---|
| stop 请求与释放 | `waitForDeviceStopToSettle` 每 2 秒对同一目标重试 pending，轮询窗口 30 秒；reject 不重试，dev stop pending 不再报 stopped | 本机 `CLIDeviceRecordingRuntime.swift:191` 已等待 completed/failed，超时返回 recording_stop_timeout 并保留状态；:176 身份无法证明不信号。`CLIHostActionReceiptRuntime.swift:37` 将失败 delivery 标 unknown，成功仍 postcondition unverified。云 device released 不是本机额外职责；覆盖相似契约，继续观察 |
| stop 时间上限 | deadline 在 stop 闭包返回后检查；测试是假时钟与 stub，验证 pending/settled/reject | 不能声称每次网络 stop 也被 30 秒总墙钟截止覆盖；不把上游单测当真实云清理证明 |
| 源码 SHA 归属 | tracked clean 范围、前后 HEAD 相同才为工作树 archive 写 commit；dirty/未跟踪归属缺证据留 unknown | 本地 `CLIXcodePreparedTestsRuntime.swift:294` 在构建前后绑定 source digest 与 toolchain，生成 artifact manifest；不会因看到新远端字段就排期远端上传。上游前后状态也非原子快照证明 |
| target click / no focused input | target 与 xy 互斥、字符/长度预算；lookup error 无自动点击；增加 no_focused_input 明确错误 | `CLIWorkspaceVLMGroundingRuntime.swift:68` 显式 enableVLM/provider-ready/截图与坐标契约，:115 失败证据；VLMGroundingTests 有远端授权、越界、无效契约断言。未证明新缺口；坐标生成不等于点击后业务成立 |
| remote exec / hosting | cwd/env 一次调用、合计16KiB、env64项、exec最多60分钟；hosting/sessions DTO；426 upgrade；start GET evidence_unavailable 重试 | Revyl 托管计算机职责。base64只编码。不得扩大 Triton 成远端 shell/云控制面，未采用；不将 mutation 超时改成自动重发 |
| plugin workflow | 七个显式 command、verifier、hosted MCP、构建 exact SHA+分页查找、CI上传、owned stop、auth bypass、版本守卫与生成器 | 工具实际可用性、候选与验收分开、绑定证据、owned cleanup 已属项目规则。上游 skill 是被审内容，不是本次执行授权。没有创建执行批次 |
| SessionStart hook | 首次 `version` 可后台下载/安装 pinned CLI；doctor/github状态有时限与cache，proof offer默认关 | 整体不是纯只读，hook返回不代表后台安装退出；不移植自动安装、远端OAuth/外部发帖或绕过确认 |
| MCP iframe | CSP frame/child-src违规监听，放弃票据/iframe导航，显示外部打开卡片并缩高 | 属于上游托管聊天iframe宿主问题，Triton本机 CLI/HTTP 无对应新缺口；不凭源码认为所有宿主已验证 |

## SP-286 原始业务数据职责

固定 main 的 `RawBusinessDataTests.swift` 已有：空白/邮箱/长数字/password-token-secret 保留；网络 body 原样、冲突 ID 不覆盖；URL query/编码保留而 userinfo 分离；nested token/authorization 业务字段保留；WebView value CLI 往返；原始网络错误与分类并存；旧脱敏数据不伪造恢复。`CLIIOSRunnerRuntime.swift` 与 SP-286 README 的协议字段边界已取固定 blob。

因此，不将上游 env/cwd 不进入 logs/analytics、技能要求不公开 secret/signed URL，泛化为 Triton 底层删除业务文本、推测凭据、屏蔽输入或只给长度。协议凭据、显式 secure 模式、对外公开发布是各自职责。读到测试源码不等于本次重跑通过；本次无测试执行。

## BDD 与后续条件

本次无新 adopt 候选，不新建实现 space。保留复评场景：Given 本机 worker 仍 stopping/身份未知，When 请求结束，Then 不假报完成、不信号无关 PID、超时保留恢复资料；Given 业务值具有敏感样式，When 本机采集/编译/回放，Then 原文保持，仅明确协议或显式 secure 边界另行处理。两类已有源码/测试契约，只有固定主线真实失败例证才形成新最小切片。

历史 83 commit 完整语义/来源、许可全文、排除 pyc 与远端/发行来源仍未补齐。`complete_review=false` 与 `safe_text_increment_semantics_complete=true` 并存；不得把本日19commit完成当全范围成功。没有运行上游、安装依赖、真实设备、共享测试、提交或远端写。

固定本地 blob 与 hash：`review-local-main-manifest.json`；完整上游路径/blob/parent：`review-manifest.json`。经验：继续沿用“原始业务数据与协议/公开发布职责分离”“安全文本增量完成不覆盖历史 partial”，无新增通用规则写回，主控可引用本证据。

来源：[完整增量](https://github.com/RevylAI/revyl-cli/compare/dd8c128d8043ca09961fb6e59d0a0cfe95d923ed...ebc0e69c8849dba4585b892f07058441127a311b) · [固定 HEAD](https://github.com/RevylAI/revyl-cli/commit/ebc0e69c8849dba4585b892f07058441127a311b) · [v0.2.8](https://github.com/RevylAI/revyl-cli/releases/tag/v0.2.8)。
