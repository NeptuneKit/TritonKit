# SP-183 能力矩阵收口（1–4 批）

本矩阵为 SP-183 当前能力与归档决策入口，2026-10-24 更新。每项同时记录实现状态与证据等级；“实现”不自动等于“真实验收”。用户已批准缩范围归档，已交付部分继续维护，未验收实验项退出主动队列；不再以完成整个 Apple Device Hub 能力表作为本 space 的关闭条件。历史实测基线仍为 2026-10-12，本次没有新设备实测。

| 能力组 | 当前状态 | 证据等级 | 下一步 / 明确边界 |
| --- | --- | --- | --- |
| App 容器 bundle → 原生容器 | 已实现 | Simulator 浅 metadata + iPhone SDK 绑定真实 + fixture | 仅接受 SDK bundle identity 与精确目标绑定；不从目录名推断，不读业务内容 |
| App Group group ID → 原生容器 | 已实现 | Simulator 浅 metadata + iPhone SDK membership/path 真实 + 错配 fixture | membership 与 path 双校验；不从 App 名称或目录名推断 |
| 原生 DeviceFS 容器/受限子目录 | 已实现 | 真实既有路径 + mount/目录替换 fixture | 可能隐式挂载，必须显式策略与审计；`mountCreated=unknown`；保留 view、child 和预算 |
| Crash 文件日志域 | 已实现 | 2台 iPhone 浅 metadata 与预算拒绝真实 + 回归 | 与 DeviceFS `DiagnosticReports` 目录、整机诊断 ZIP 分离；不复制内容 |
| Crash DeviceFS 目录 | 已实现 | fixture；当前专用 Simulator 缺目录 | 固定目录和 `directory_unavailable`；不猜 root、不降级为其他域 |
| Temporary 查询域 | 实验性执行边界保留；真实查询未验收 | fixture + 无策略早拒绝 | 可能创建临时域；必须显式策略、intent/completion 审计；仅具体真实项目需求触发独立验收，不主动排期 |
| pair / unpair | 已实现执行后端 | 真机 pair/unpair 后置通过 + fixture | `execute-runner + confirm + audit-record`；file JSON 身份绑定；后置 paired/unpaired 独立确认 |
| diagnose | 已实现执行与安全发布 | 16 Pro真实采集/私有发布成功 + 默认预算/覆盖拒绝 + fixture | 失败/超时/部分完成分开；ZIP no-overwrite/nofollow/权限/大小预算；不等于 device-only |
| watch 配对关系 | 已实现 | 专用环境空集合真实 + fixture | 不证明物理 Watch 配对或输入；保留旧 sim pair/unpair |
| watch Crown / Action | 实验性 runner 保留；产物已编译，输入未验收 | 原生 build-for-testing；历史 runtime 下载网络失败 | 仅具体真实项目需求触发独立验收；Action 无可验证后置断言不发送；侧键仍 unsupported，不自动排期 |
| tvOS 焦点 / 选择 / 返回 | 实验性 runner 保留；产物已编译，输入未验收 | 原生 build-for-testing；历史 runtime 下载网络失败 | 仅具体真实项目需求触发独立网格/详情 UI-test 的真实后置验收，不主动下载 runtime 续跑 |
| visionOS 2D UI | 历史研究归档；取消本 space 实施排期 | 公共方向已核实，未接入 | 实际需求重新定范围，不把研究方向称已支持 |
| visionOS 空间 / gaze / 6DoF | 未支持 | 无稳定 headless 后端 | 保持 unsupported，不自动排期；不以 GUI、pinch 或 capability 名称冒充实现 |
| macOS Xcode workflow / Device Hub 控制 | Xcode workflow 已实现；Device Hub 控制 unsupported | 既有 Xcode 兼容测试 | 维护已有 build/test；Device Hub 控制不自动排期 |
| 非 iOS physical 发现/选择 | 部分实现 | iPhone metadata 真实 + 非 iOS fixture | 只接受 SDK identity/platform/hardware 字段；未知保持 unknown |
| SDK 新旧布局 | 已实现兼容层 | 新旧 fixture + 当前 SDK 回归 | 未安装旧 SDK 只能称 fixture 兼容 |
| 旧 Xcode 命令与参数 | 已保留 | CLI/schema 回归 | 新参数 opt-in；不删除旧入口或改变旧副作用 |
| CLI/HTTP/DTO/schema 一致性 | 已实现 | schema 与 public snapshot 回归 | 新增能力必须从事实 schema 生成或同步，禁止二次包装错误 envelope |
| 安全预算与审计 | 已实现边界 | 目录替换、symlink、权限、大小 fixture | 不声称消除同用户并发 TOCTOU；不读取业务文件内容 |

## BDD 收口门槛

1. **实现门槛**：CLI parser、runtime、DTO、schema、failure taxonomy 和 public command snapshot 一致；至少有失败 fixture 覆盖身份、预算、权限、替换和未知布局。
2. **真实验收门槛**：必须在授权专用 Simulator/目标上保存可脱敏证据，且动作、后置状态和目标身份三者都可追溯；fixture 不升级为真实验收。
3. **重新立项门槛**：存在具体真实项目需求，并明确平台、目标、输入/输出契约和独立验收后，才为实验项或历史研究建立后续范围；后端或 runner 的存在本身不产生实施排期。
4. **未支持门槛**：没有稳定可验证后端，或只能依赖 GUI；统一返回 `unsupported`/`unverified`，不伪造成功。
5. **兼容门槛**：旧命令和参数继续可解析，新 SDK 字段可扩展，缺失关键身份拒绝；本机未安装的 SDK/Xcode 版本只记 fixture。
6. **安全门槛**：副作用操作显式确认与审计；审计/归档拒绝覆盖和符号链接，目录替换返回 uncertain/partial；不读取业务内容。

## 2026-10-24 归档判定与交接

本 space 已按缩减后的范围归档，已交付代码、命令与分项证据保持；不声明完整 Device Hub 接入。watch/tvOS 与 Temporary 未验收状态保留，visionOS/macOS 控制的 unsupported 边界也保留。未来只有实际项目需求才重新立项，不因历史计划或平台目录自动继续扩张。

历史记录显示 2026-10-12 原 iPhone 13 Pro Max 配对恢复未完成，iPhone 16 Pro 配对及 fixture 保留；本次没有找到后续处置证据，**两项当前状态均 unknown**。关闭产品扩张队列不抹去操作遗留，也不授权自动恢复、unpair 或卸载。下次对同一目标有实际需求时，结合用户保留意图核实并记为“已恢复 / 按用户意图保留 / 待原目标重连并交接”。历史部分完成诊断不因后续另一设备成功改写为成功。

分发结果以[发版记录的发布结果](20261012-release-preparation.md#发布结果)为准：`v0.2.24` 已发布。Simulator HID、Resize 录制分别跟随 [SP-218](../../SP-218-issue-222-device-hub-input/README.md)、[SP-219](../../SP-219-simulator-resizable-routing/README.md)，本次不替代其独立真实验收。

## 历史完成判定与增量（2026-10-11～12）

以下保留当时快照；“未执行”“仍待”等不表示今日设备状态。当前能力等级见上表，当前队列决策见上一节。

四批可以称为“文档与契约收口”，但不能称为完整 Device Hub 接入，除非 watch/tvOS runner、visionOS 2D（如要支持）和对应专用目标真实验收均完成。当前仍有明确计划和未支持项，且未执行真机写入、真实诊断采集、Temporary 真实创建或未授权挂载。

2026-10-12 真机增量：[只读验收](20261012-real-device-verification.md)。仍不升级 pair/unpair/diagnose、Temporary 创建或 watch/tvOS 输入的证据等级。

后续用户明确授权真机写入：[管理与App执行](20261012-real-device-execution.md)。pair/unpair后置通过，诊断已采集但超发布预算；恢复配对和App启动仍待解锁重连。本文此前未授权/未执行描述为历史快照。

诊断成功路径增量：[16 Pro私有归档发布通过](20261012-diagnostic-closeout.md)，显式512MiB接受预算；原13ProMax的默认256MiB超限结果保留。
