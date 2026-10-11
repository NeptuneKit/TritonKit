# SP-183 能力矩阵收口（1–4 批）

本矩阵用于收口四批实际能力。每项同时记录实现状态与证据等级；“实现”不自动等于“真实验收”。

| 能力组 | 当前状态 | 证据等级 | 下一步 / 明确边界 |
| --- | --- | --- | --- |
| App 容器 bundle → 原生容器 | 已实现 | 真实浅 metadata + fixture | 仅接受 SDK bundle identity 与精确目标绑定；不从目录名推断，不读业务内容 |
| App Group group ID → 原生容器 | 已实现 | 真实浅 metadata + 错配 fixture | membership 与 path 双校验；不从 App 名称或目录名推断 |
| 原生 DeviceFS 容器/受限子目录 | 已实现 | 真实既有路径 + mount/目录替换 fixture | 可能隐式挂载，必须显式策略与审计；`mountCreated=unknown`；保留 view、child 和预算 |
| Crash 文件日志域 | 已实现 | 既有真实证据 + 回归 | 与 DeviceFS `DiagnosticReports` 目录、整机诊断 ZIP 分离；不复制内容 |
| Crash DeviceFS 目录 | 已实现 | fixture；当前专用 Simulator 缺目录 | 固定目录和 `directory_unavailable`；不猜 root、不降级为其他域 |
| Temporary 查询域 | 已实现执行边界 | fixture + 无策略早拒绝 | 可能创建临时域；必须显式策略、intent/completion 审计；真实创建未授权 |
| pair / unpair | 已实现执行后端 | fixture；未做真机写入 | `execute-runner + confirm + audit-record`；file JSON 身份绑定；后置 paired/unpaired 独立确认 |
| diagnose | 已实现执行与安全发布 | fixture；未做真实采集 | 失败/超时/部分完成分开；ZIP no-overwrite/nofollow/权限/大小预算；不等于 device-only |
| watch 配对关系 | 已实现 | 专用环境空集合真实 + fixture | 不证明物理 Watch 配对或输入；保留旧 sim pair/unpair |
| watch Crown / Action | 未接入 | 公共 XCTest API 已核实，未实测 | 计划独立 watch runner；硬件缺失返回 unsupported；普通侧键无稳定公开 API |
| tvOS 焦点 / 选择 / 返回 | 未接入 | `XCUIRemote`/`hasFocus` API 已核实，未实测 | 计划独立 tvOS runner；菜单返回需后置状态断言 |
| visionOS 2D UI | 计划 | 公共方向已核实，未接入 | 单独验证 Designed for iPad 2D 元素路径 |
| visionOS 空间 / gaze / 6DoF | 未支持 | 无稳定 headless 后端 | 不以 GUI、pinch 或 capability 名称冒充实现 |
| macOS Xcode workflow | 已实现 | 既有兼容测试 | 不扩展为 Device Hub 观察/控制 |
| 非 iOS physical 发现/选择 | 部分实现 | iPhone metadata 真实 + 非 iOS fixture | 只接受 SDK identity/platform/hardware 字段；未知保持 unknown |
| SDK 新旧布局 | 已实现兼容层 | 新旧 fixture + 当前 SDK 回归 | 未安装旧 SDK 只能称 fixture 兼容 |
| 旧 Xcode 命令与参数 | 已保留 | CLI/schema 回归 | 新参数 opt-in；不删除旧入口或改变旧副作用 |
| CLI/HTTP/DTO/schema 一致性 | 已实现 | schema 与 public snapshot 回归 | 新增能力必须从事实 schema 生成或同步，禁止二次包装错误 envelope |
| 安全预算与审计 | 已实现边界 | 目录替换、symlink、权限、大小 fixture | 不声称消除同用户并发 TOCTOU；不读取业务文件内容 |

## BDD 收口门槛

1. **实现门槛**：CLI parser、runtime、DTO、schema、failure taxonomy 和 public command snapshot 一致；至少有失败 fixture 覆盖身份、预算、权限、替换和未知布局。
2. **真实验收门槛**：必须在授权专用 Simulator/目标上保存可脱敏证据，且动作、后置状态和目标身份三者都可追溯；fixture 不升级为真实验收。
3. **计划门槛**：已确认可编程后端、输入/输出契约和隔离 runner，但代码入口或专用目标尚未完成，状态保持“计划”。
4. **未支持门槛**：没有稳定可验证后端，或只能依赖 GUI；统一返回 `unsupported`/`unverified`，不伪造成功。
5. **兼容门槛**：旧命令和参数继续可解析，新 SDK 字段可扩展，缺失关键身份拒绝；本机未安装的 SDK/Xcode 版本只记 fixture。
6. **安全门槛**：副作用操作显式确认与审计；审计/归档拒绝覆盖和符号链接，目录替换返回 uncertain/partial；不读取业务内容。

## 本批完成判定

四批可以称为“文档与契约收口”，但不能称为完整 Device Hub 接入，除非 watch/tvOS runner、visionOS 2D（如要支持）和对应专用目标真实验收均完成。当前仍有明确计划和未支持项，且未执行真机写入、真实诊断采集、Temporary 真实创建或未授权挂载。
