# Revyl CLI 2026-10-30 增量审阅

裁决：observe；无新增采用切片。影响层只评估 CLI/HTTP/shared contract，不执行第三方代码、安装、设备或 Git 写入。允许文本的本轮增量审阅完成；总体仍 partial，不能推进完整成功检查点。

## 固定来源与读取

- 官方 base `8ecfb9f8b1591ac35ad3a3576e9d1df016dd2c33` → head `b6194f927fc3550fbd8144c56db313787e468b29`。`commits-1.json`分页100项，遇到base停止；19项第一父链连续，未使用带patch的compare/commit接口。
- base/head recursive trees与19个提交recursive trees均`truncated=false`。完整union为50路径，逐提交筛选后45文本路径。`history-path-screening.json`保留每步blob SHA；`history-blobs/`保存所有允许文本中间版本，故不只看净diff而遗漏回滚。
- 用途筛选包括CLI、API、MCP、配置、schema、文档与打包文本；4个`__pycache__/*.pyc`和无扩展名`VERSION`只保存tree元数据，未请求内容。Python bootstrap `_binary.py`完整变化仅版本号。
- `release-notes.txt`保存分页官方非draft记录v0.1.196/201/202/203全文；197～200未列出，不自行补造。最新v0.1.203仅安装、独立computer CLI、skill与checksum说明，无额外功能changelog。只读notes，不下载产物。
- 官方许可证全文API仍404；README/PyPI声称MIT不等于固定SHA许可证全文，hash保持null。旧hosted/binary来源缺口保持，4个pyc语义未审。二进制产物没有下载或运行。

## 机制与本机差距裁决

1. `cmd/revyl/build_project.go`与device/computer路由以`REVYL_COMPUTER_ID`改变默认执行位置，显式flag可覆盖；implicit mobile start绕开before_script/auth_bypass，Web bundle保持standalone。它依赖托管computer与上传build身份，并非本机工具链缺陷。Triton不新增云computer产品面。
2. `internal/api/computer_wire.go`把argv/path改为URL-safe base64、保持解码后预算；`computer_contract.go`只在403+HTML+cf-ray+非JSON同时成立时报告edge_blocked，不自动重试。此为Revyl公网Cloudflare协议适配；Triton loopback HTTP没有该edge，不能移植为本机认证错误分类需求。
3. 新`set-fold-state`CLI/MCP只向托管worker发`/set_fold_state`；不展示SimulatorKit backend。其非幂等名单与unconfirmed后同session观察方向有价值，但SP-192/196已落实unknown不重放，SP-200已有Android posture读回。实际main `CLIDeviceEnvironmentRuntime.swift:106`已明确iOS Duo需要版本门控SimulatorKit、公有simctl无fold/hinge能力；本增量没有补齐该来源，继续观察而不宣称本机支持。
4. API的`recording_status`为Web录制发布状态pending/ready/unavailable/unknown，unknown不证明无录制。Triton本机`CLIDeviceRecordingRuntime.swift`已维护recording/stopping/completed/failed并以实际视频样本和发布成功决定completed；无托管异步发布通道，不增加同义DTO。
5. PR proof paths新增`!`glob排除、code-step stdout JSON引用、Web探索统一gate、partner计费/120分钟租约/工作目录说明、插件支持Web/macOS及Pixel Tablet目录，均属于托管PR/执行/计费/设备目录或文档。没有可直接迁移的本机后端实现。uv.lock中间版本发生marker/wheel列表变化后回撤，依赖版本未变；净版本同步为0.1.203，未执行依赖安装。

## 去重与本地证据

对照真实`main@30185dc277ed305483aa789cb2d8c8b06fa21fe4`的固定blob，未把当前未提交SP-244改动当main。`local-main/`保存DeviceEnvironment、DeviceRecording、WorkspaceActionExecution及对应测试源码。SP-192负责unknown/采集预算等，SP-196负责资源生命周期/配置与只读证据，SP-200负责fold、录制与设备环境；现有adoption-state仅去重核对，无重复分派。当前分支main、多worktree与用户WIP已读取核对，保持原样。

本次仅取证和评估，未实现，未运行测试/构建/设备验收；第三方测试数量和性能不作本地验证声明。复用经验沿用reference-project-adoption-workflow的请求前白名单、固定树和partial规则；无新治理机制，正式文档/state/memory由主控统一写回，子任务没有越权修改。
