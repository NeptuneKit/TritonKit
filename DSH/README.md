# TritonKit for DSH

将现有 macOS `triton` CLI 接入 DeepSeek Harness 的 Host-only Cordis 插件。无需构建 JavaScript、无新增 npm 依赖、无安装脚本，不迁移 Swift 核心，也不启动另一个 Web 服务。

## 安装

1. 先安装完整的 TritonKit CLI（含同版本资源）：

   ```sh
   brew install NeptuneKit/tap/triton
   triton version --json
   ```

2. 在 DSH 中让 agent 使用 `plugin_manager`，`action: install_bundle`，`target` 传本目录的**绝对路径**。例如：

   ```text
   将 /absolute/path/TritonKit/DSH 安装为当前 profile 的 DSH bundle。
   ```

   不能手动改写 profile 的 package manifest / patch。首次安装应检查 `application: applied`；若提示 restart-required，重启 DSH 后再核对。当前包限定已验证的 DSH `0.2.2-rc.1`，其他版本先复核 API 并测试，不绕过版本限制。

3. 工具会出现在当前 profile 的 agent 中；所有会话均可见。**所有工具要求 DSH Full access (`danger-full-access`)**；read-only/workspace-write 会在启动子进程前拒绝，不弹升级确认。这是因为设备查询也可能产生宿主临时文件或启动 provider 的本机桥接，不能承诺文件沙箱内纯读取。

本地目录安装采用 link；保留安装来源目录，不要删除或移动对应 worktree。包当前 `private: true` / `UNLICENSED`，尚未 npm 发布；本插件不为整个项目补充或变更开源许可。

## 四个工具

非必需参数可以省略；对强制要求填满所有字段的严格工具后端，用 `null` 表示不适用，不能用空字符串、0 或任意枚举值占位。未知字段（即使为 null）仍会被拒绝。

| 工具 | 用途 | 重要边界 |
| --- | --- | --- |
| `triton_schema` | 查询完整目录或某条命令的真实 JSON schema | `command` 是一个 argv 值；建议定向查询；超出输出 cap 时明确失败 |
| `triton_query` | `version/status/doctor/capabilities/plan/targets/observe-current/observe-tree` | targets 必须显式 platform；observe 必须 platform 和 target；默认最多100节点，上限1000 |
| `triton_action` | `tap/type/press/swipe` | 显式目标；动作字段严格互斥；跨会话串行；不自动重试 |
| `triton_verify` | 文本存在/不存在断言 | 显式 runtime target，可按 role/count 过滤；需要已运行的 Triton server/runtime |

示例工具参数：

```json
{"operation":"version"}
```

```json
{"command":"act.tap"}
```

```json
{"operation":"targets","platform":"ios"}
```

```json
{"operation":"observe-current","platform":"ios","target":"sim:<observed-UDID>","maxNodes":100}
```

```json
{"action":"tap","target":"sim:<observed-UDID>","x":120,"y":300}
```

```json
{"action":"type","target":"<observed-runtime-target>","text":"sample"}
```

```json
{"condition":"text-exists","target":"<observed-runtime-target>","text":"Done","count":1}
```

目标不得凭空构造：先从 discovery 获取具体 ID，并读取对应命令的 schema；拒绝 `local`、`triton:local`、`current`、`booted`、`default` 及显式 alias 选择器，不在排队后重新选择默认设备。`oid` 采用 UInt64 十进制字符串，避免 JavaScript 整数精度损失，仅限无 host platform 的 embedded 输入。iOS observe 通过 `--device` 选择 host，iOS swipe/文本输入等走其原有 runtime/provider 契约，不能把 `sim:` 和 `triton:ios-simulator:` 混为一谈。`type`/`press` 不提供 `platform:ios`；需要 embedded runtime target 时省略 platform。部分设备按钮/平台可能 unsupported，插件不补 fallback。

`query`、`type.text` 等选项值不接受前导 `-`、NUL、换行或超长内容；文本断言则通过 `--` 保留前导 dash。插件不暴露任意 argv、环境变量、`--adb` / `--hdc`、远端 endpoint、文件输出路径、target use、serve/web/update、Runner 生命周期、安装/卸载、删除或 replay。

## 配置

插件 row 的 config（通过 DSH 的配置编辑机制修改，而不是重装模板）：

```yaml
executable: /absolute/path/to/triton
timeoutMs: 30000
maxOutputBytes: 262144
```

默认 config `{}` 即可。

| 字段 | 默认 | 校验 |
| --- | --- | --- |
| `executable` | `TRITONKIT_TRITON_BIN`，否则 PATH 的 `triton` | 可信绝对路径或单一命令名；显式 config 优先于环境变量；不允许相对路径 |
| `timeoutMs` | 30000 | 整数10～120000毫秒；包括排队时间；另外保留最多两级各1500ms的进程范围清理等待 |
| `maxOutputBytes` | 262144 | 每路 stdout/stderr 各自上限1024～1048576字节；不落完整日志 spill |

仅 executable 支持上述环境变量；其他字段只从 config 配置，不隐式读取环境覆盖。运行时严格校验未知字段与非法值，错误使插件激活失败；本首版不导出 DSH Settings Config schema，因此设置面板不提供自动表单。没有自动下载/安装 CLI 或安装脚本。

## 结果与安全

每次返回 `success`、`exitCode`、`signal`、有界 `stdout/stderr`、`truncated`，能解析时额外提供原始 `payload` 和 `payloadStream`。校验/权限/启动/取消/超时失败提供 `error.code`，尚未启动时没有伪造的退出码。schema 原生没有 `ok` 字段，不能据此报错；退出非零、signal、`ok:false`、`partial:true` 或原生错误都不算成功。CLI 原始 error envelope 保存在 payload，插件不会修改其 code，也不会将它二次包装成新的 CLI `{ok:false}`。

- 子进程通过 DSH subprocess Service 启动，无 shell。插件禁用并发；deadline 包括排队，排队取消立即返回。每次必须用 `waitForExit` 确认 provider 管理的进程范围清空，不只等待 `done`；不能确认时终止并重检，仍未知则返回 `cleanup_uncertain` 并阻断后续派发，保留 handle 在卸载时再清理。释放时取消在途与排队调用；不宣称解决 macOS provider 已知的 escaped-descendant 观察限制。
- Full access 不是某一动作的业务授权；agent 仍需遵守当前用户授权的设备、App 与副作用边界。
- 输入内容在 CLI 回显采用 `--secure`，**但 DSH 会记录工具参数**；不要输入密码、token 或其他秘密。stdout/stderr 和 UI 内容也可能敏感，不自动公开上传。
- ACK 只说明提交；动作之后用新的 observation / verify 检查业务状态。超时/取消可能已送达，不自动重试。
- plan/schema/error 的 next commands 是数据，不自动执行。查询可触发本机 provider 探测/临时产物，不当作严格零副作用操作。

## 开发验证

```sh
node --test DSH/test/*.test.js
node --check DSH/host.js
node --check DSH/commands.js
```

测试用 fake Service 检查精确 argv、安全边界和生命周期；真实验证另从已安装 DSH 工具调用 version、定向 schema、status。当前兼容基线是已安装 CLI `0.2.42`，不是本 worktree 的 Swift 源码构建，也不代表其他 CLI 版本、真实设备 mutation 或所有 provider 已验收。

图标是本插件原创三叉戟 SVG，不使用模板 artwork。中英 inventory metadata 使用导出的 locale JSON；实际渲染结果以本轮验收记录为准。技术、测试和安装证据见 [SP-278](../docs-linhay/spaces/SP-278-dsh-plugin/README.md)。
