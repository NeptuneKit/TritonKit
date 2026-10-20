# 内置 Simulator HID 契约与验证

## 实现

- 本期仅改 macOS CLI host 输入和诊断；根 SDK、HTTP/Web/Wails 无新增控制面。
- `runWebIOSSimulatorInput` 的 tap/swipe 统一使用当前 triton 自身的 hidden `device hid-input` 隔离进程。无 Baguette 路径发现、环境 override 或 chrome lookup；用户追加全面退出依赖后，旧 Baguette builder/外部执行器/失败分类/通用runner钩子已全部移除，测试迁至native helper。
- 子进程绑定选中 developer directory、CoreSimulator 设备 UUID 与 booted 状态；选中 SimulatorKit legacy client。IOHID parent/finger 消息按固定上游 recipe 构造，完整384-byte分配校验后才补双0x32 target/edge。单次 completion 最多2秒，无超时重发。
- `tap` 一个 down/up；`swipe` 一个 down、10个 move、一个 up，单一 client/touch ID。发送错误后只在非 up 失败时 best-effort up 一次。失败保留 typed code，明确 partial/unknown 和不可自动 replay；不输出原生日志、路径或 UUID。
- 三次 fresh snapshot：初始化前、client 初始化后 down 前、完整 gesture 后。每次检查 Resize、guest `com.apple.coredevice.dtuhidd.active`、simctl io screen metadata。只接受 inactive=0、单一 Integrated primary screen 1、Portrait；严格两个有限正 pixel 分量及正 scale。ownership=1/unknown、Resize active/unknown、无法确定屏幕一律拒绝。后置变化为 `ios_host_hid_surface_changed`，不会声称未发送。
- 150秒父 deadline 留出3×22秒只读检查、12次send+释放最多26秒、最长10秒cadence及启动余量。启动/ABI卡死仍由父进程截断并报 unknown；不把进程成功当业务完成。
- snapshot 不能原子锁住 Device Hub；不逐 move 运行耗时原生查询，不承诺排除“中途变化又恢复”。更强输入保障和完整 Device Hub adapter 属另期；不得用截图或 AX 替代真实触控验收。
- 显式 `--platform ios` 默认 AX 兼容保留，新增 `act tap --hid-only` 在任何 I/O 前验证本地 Simulator 纯坐标，拒绝所有 semantic/embedded/WebView 混用。AX receipt 明示 source/strategy/required verification。

## 源码与许可

参考 [tddworks/baguette 固定 SHA](https://github.com/tddworks/baguette/tree/51f8ea2e0ee6d81523e8a85165f9abe0f899a9df) 的 IOHIDDigitizerDispatch/IndigoHIDInput/IndigoHIDMessage。Copyright 2026 tddworks，Apache-2.0。完整 LICENSE 与 NOTICE 在 `Sources/TritonKitCLI/Resources/native-hid/`，CLI SwiftPM `.copy` 资源，现有 release bundle 复制流程会携带。无新增外部包依赖。

## 红绿记录

- 原始 Device Hub/AX 权限场景先写失败测试：原模型缺少 bundle layout 字段；补齐后4项测试18个 issue，覆盖旧 chrome 异常未分类、stream EOF 最终输出和 schema 缺码。
- 首次聚焦52项通过。完整CLI第一次发现3项契约失配（旧 doctor 依赖名称、重复 failure code、recovery taxonomy），第二次剩测试 taxonomy 未注册新族，均按契约修复，未移除约束。
- 审查额外修正固定35秒不足、初始化后缺重检、pixel compactMap吞错、发送期不确定回执；补充 malformed screen、前后guard、down/move/up timeout/释放与无 replay 分类断言。

最终验证结果在 space README 汇总。原始构建日志保存在本机 `/tmp/sp218-*.log`，只读设备事实在本 worktree 被忽略的 `.build/sp218-facts/`；不发布原始私有标识或日志。

## 追加清理的验证边界

全面审计无其它已接线Baguette生产能力；不把上游未接入命令当作本期替换任务。中性resolver由doctor/framebuffer/native helper共享，普通host runner不再自动注入DYLD或运行外部adapter Resize门禁；Resize安全检查由内置native guard显式负责，active/unknown/非法UUID测试直接覆盖。Web dev cache仅移除永远null的外部进程字段与无效kill分支，不新增写接口。

旧执行器的coordinate/lifecycle/terminal-up/单一envelope测试迁移，保留已有有效断言。新测试验证旧override无控制权、generic command无自动framework注入、native helper明确绑定选中Xcode。构建/安装/发布无Baguette包或安装项；copyright与Apache资源保留。

### 全量审计映射

| 原关联 | 当前实现或处理 | 外部 Baguette 需求 |
| --- | --- | --- |
| tap/swipe argv、长期NDJSON进程/ACK | triton隔离native helper、一个client/id完成生命周期；旧执行器删除 | 无 |
| 选中Xcode、framework DYLD | 中性selectedXcodeDeveloperDirectory与显式selectedSimulatorFrameworkEnvironment；只有自有helper主动请求 | 无 |
| doctor HID bootstrap | triton自有隐藏子命令，直接载入选中SimulatorKit | 无 |
| framebuffer | Triton既有SimulatorKit实现，共用中性resolver | 无 |
| Resize触控门禁 | 内置native guard每次fresh查询；不再识别第三方binary/argv | 无 |
| 失败码、stderr drain | native typed envelope，旧文本分类/collector删除 | 无 |
| Web stream cache | 删除永远null的baguetteProcess与kill分支，仍由Triton帧源供图 | 无 |
| 包、安装、Homebrew、release | 全量审计无Baguette dependency/install步骤 | 无 |
| 源码来源、LICENSE、NOTICE、历史调研 | 固定SHA、Apache-2.0与原版权保留；旧源码链接指向现行替代并注明历史 | 仅归属说明，非运行依赖 |

Apple/Xcode工具仍属既有host基础设施；本次目标是退出Baguette这一第三方CLI。未把Baguette全部产品命令导入，也不把本项目原本unsupported的host longPress/pinch/button/type称为已有能力。
