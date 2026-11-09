# TritonKit DSH Host 插件契约

对应 [SP-278](../spaces/SP-278-dsh-plugin/README.md)，使用说明见 [DSH README](../../DSH/README.md)。2026-11-09 首版是四个工具的本地 Host bundle，不是 Swift SDK 搬迁、Web/Wails 业务页或另一个 HTTP server。

## 权威与影响层

- DSH 运行实例：Desktop 内置 `0.2.2-rc.1`。shell 中另一个 `dsh --version` 返回 `0.2.1-rc.2`，不是本次运行接替验收对象。
- live Inspect 核对 `tools.register`、`subprocess.resolveExecutable/spawn`、`workingDirectory.ensure`、`sandboxPolicy.resolve` 及相关类型；按这些 Service 编码，不把 Inspect 方法当业务 Service 调用。
- CLI 验收对象：当前已安装的 `triton 0.2.42`，不是基线 worktree 的 Swift 编译产物。`schemaVersion=1` 本身不证明所有 CLI 版本兼容；更新 CLI 或 DSH 后应复跑定向契约和真实 smoke。
- 新包 `@neptunekit/dsh-tritonkit-host@0.1.1`（0.1.0后补裸alias拒绝与真实打包回归），当前 `private/UNLICENSED`，没有 npm 发布、外部依赖、install scripts 或 native build。包约束已测 DSH 版本；不自动申请版本豁免。

## 执行契约

1. 工具四种：schema、query、action、verify。每种都有命令与参数白名单，绝不提供通用 `run(argv)`。
2. CLI 固定为可信配置 `executable` / `TRITONKIT_TRITON_BIN` / PATH 的 triton；模型不能覆盖 executable、PATH、adb、hdc、endpoint 或 output 路径。`spawn.argv` 是数组，无 shell；文本内 `$()`、引号等保持字面量。
3. 严格工具后端可能要求所有声明字段均提供。非必需字段显式支持 `null`；仅对已知可选字段规范化为 omission。未知字段即使为 null 仍拒绝，相关 operation 不接受有意义的无关字段。不能让 agent 用空字符串、0 或任意枚举值填不适用参数。
4. 所有工具检查 session 存在及 DSH Full access；缺失或较低权限 fail closed。异步 cwd/可执行解析完成后，紧邻同步 spawn 再检查权限，防止准备期间降权仍执行。此检查不改变用户的权限配置，也不自动请求升级。
5. 所有有目标的请求必须保留discovery命名空间（`sim:`、`ios-real:`、`android:`、`harmony:`、`triton:`），裸名称/serial/UUID全部拒绝；CLI alias语法允许普通名称且优先于raw ID，所以仅拒绝 `alias:` 前缀不够。命名空间中的冒号不在CLI alias名称语法内，避免排队期间重新读取映射；同时拒绝`local/triton:local/current/booted/default`等保留段。host selector与embedded runtime ID不混用，不提供provider fallback或跨backend能力保证。
6. iOS host observe 传 `--device`，Android/Harmony observe 传原生 `--target`。输入/按钮的 `platform:ios` 提前拒绝，以免杜撰 CLI 参数。`oid` 是有界 UInt64 十进制字符串，仅限无 host platform 的 embedded 输入，避免精度与 parser 错配。
7. 同一插件的所有 session 共用串行队列；deadline 从入口开始，包含排队。排队取消立即返回，保留不再派发的占位维持序列。
8. `handle.done` 只提供命令退出事实；结果发布与下一命令必须等 `waitForExit` 确认 provider 的管理范围清空。首次等待失败则 terminate 并重检，两级各1500ms；仍不能确认时保留 handle、返回 `cleanup_uncertain` 并阻止后续派发，卸载再清理。macOS fallback 无法证明未观察到的 escaped descendants；这是 provider 的既有边界，不宣称完全消除。
9. 正常/取消/超时/provider 异常统一保留可得 stdout/stderr 与原生 JSON payload。`success` 只代表该 CLI 请求完整成功，不代表某次点击已经完成业务后置条件；动作 ACK 后必须独立 observe/verify。取消或超时不自动重放。

## 输出与隐私

- 每路输出默认262144字节、最大1048576字节，collect 无 spill；截断明确失败，不从尾部 JSON 推成功。
- 原生 schema 没有 `ok`，不能据此误报；非零退出、signal、`ok:false`、`partial:true`、顶层 error 或 skipped error 均不算成功。
- 原生 error code 保持在 payload，不二次改造成 CLI envelope。插件自身权限/校验/超时错误在顶层 `error` 中，语义与 CLI payload 分开。
- `--secure` 仅约束 CLI 输出，不能消除 DSH 工具参数日志；禁止通过该工具输入凭据。UI 内容、原生 stdout/stderr、截图和目标身份也可能敏感，不自动上传。
- discovery 不是严格零副作用：设备探测可能创建临时 artifacts 或启动本机桥接。所有工具因此要求 Full access；不会主动启停 Triton server、Runner、安装/更新/卸载或执行建议命令。

## 配置与资源

运行时校验默认值、显式配置优先级、环境变量和非法值；本首版没有导出 Config schema，因此 inventory 的 Config `status: absent` 仅表示无 schema，不表示插件未运行。用户配置通过 DSH 正常配置编辑机制变更，不手改 profile manifest/patch。

包导出中英 locale metadata 与原创三叉戟 SVG；`files` 列表固定 runtime/patch/locales/icon/README，打包不携带测试、dist、设备证据或内部 skills。SVG 在包内，限制大小且无脚本/外链。当前链接安装需保留 worktree；模块替换应遵守 DSH generation/restart 指示，不能看到相同工具名就假设新代码已生效。

## 自动沉淀检查点

- 第一次 live 调用暴露非适用参数被严格后端补全的问题；先停用移除初次开发安装，补 null 契约与测试，再以明确 Host 包与 `host.js` 冷模块入口安装，确认 `application: applied`，无重复活跃 bundle。不宣称旧模块原地 HMR 已更新。
- 独立审查发现权限 async 窗口、direct outcome 与 range quiescence 差异、动态 selector、UInt parser、队列取消和错误保留；均补生产边界与负例。权限竞态、动态 selector 和 oid 负例分别有失败再通过证据。
- 包首次 registry 空字符串被管理工具拒绝，未误报成功；改为有效 registry URL 后 local link 安装 applied，无 build scripts。
- 实际 GUI 的无凭据 URL返回 authentication required。只完成静态 display resource 验证，未声称插件面板中英文/图标渲染已通过；不为验收读取用户 cookie、token 或改写认证。
- 首轮旧基线只有SP-001～255，其他注册worktree占到277，故如实保留文档失败日志；13:02授权整合后，仅将本插件增量重放到最新远端main，保留远端权威登记与当日发布记忆，没有回灌旧DTUHID/日志产品结论，278个space结构与ci-docs已通过。
- 合并前独立审查发现普通名称alias仍可通过旧字符串过滤；补命名空间强制与进程lookup前负例，32项回归通过。`package.json.files`声明及实际`npm pack`/tar内容进入自动测试和独立Node 22 CI；DSH-only分类contracts，混入Swift/Pod/未知路径仍分别升级门禁，不能以插件测试替代Swift产品测试。
- 当前profile通过正式remove/install更新至0.1.1，观察applied后以“裸alias+空文本”双重无效输入验证新guard：旧版本也会在文本校验失败，确保两版本都不启动CLI；实际返回新namespaced错误，证明新目标检查已生效，不只看相同工具名。

初始0.1.0事实见[首轮报告](../spaces/SP-278-dsh-plugin/plans/20261109-validation.md)，当前0.1.1、提交整合与CI见[整合报告](../spaces/SP-278-dsh-plugin/plans/20261109-integration-validation.md)。真实设备mutation、全量Swift/CLI源码测试、所有provider、GUI实际展示和发布均不从本轮只读smoke推导。
