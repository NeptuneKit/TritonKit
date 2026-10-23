# 四批能力证据矩阵

> 历史批次快照（2026-10-10）。后续真机执行、发布与 2026-10-24 缩范围归档已更新至[当前能力矩阵](20261011-capability-matrix-closeout.md)。以下“未集成”“未真机动作”“未提交”等仅描述当时状态；实验项按真实项目需求重开，unsupported 不自动排期，原始证据不升级或删除。

本轮继续既有 SP-183，隔离 worktree `SP-183-device-hub-capability-batches`。实现与验收是两列，不以一组测试通过称完整 Device Hub 接入。

| 能力 | 实现状态 | 当前验收等级 | 边界 / 未完成 |
| --- | --- | --- | --- |
| App bundle → 原生容器 | 已实现 `device containers --bundle-id --list` | 专用 Simulator 真实浅metadata 5项；fixture身份/旧布局/路径/预算 | SDK显式元数据为依据，DeviceFS目录绑定仍false；不读业务内容 |
| App Group ID → 原生容器 | 已实现 `--group-id`：membership + path双校验 | 专用 Simulator 真实浅metadata 2项；group错配fixture | 不用App名或目录名猜group ID；real只metadata |
| 原生DeviceFS容器/子目录 | 原有实现保留；mountpoint/fs list 现在显式声明可能隐式挂载并要求策略/审计 | 原有真实证据 + mount 策略/目录替换 fixture | 固定view、受限native child及relative目录；mountCreated unknown；不自动映射SDK路径 |
| Crash 文件域 | 原有 `systemCrashLogs` metadata 保留 | 既有真实证据；本轮回归 | 不复制内容；不等同DiagnosticReports或诊断ZIP |
| Crash DeviceFS目录 | 已实现 `--view diagnostic-reports` | 正常/缺失/权限fixture；专用Simulator实际目录不可用 | 固定`DiagnosticReports`；不猜root，不错误降级；缺失报directory_unavailable |
| Temporary | 已实现显式可能创建策略与intent/completion审计 | 仅fixture + 实际未授权调用拒绝 | 未真实查询；实际created unknown；原生命令risk=automation；无策略不能执行 |
| device pair / unpair | 已实现执行后端；保留plan-only | 仅fixture；实际缺策略调用拒绝 | 未真机动作；strict fileJSON＋独立paired/unpaired后置；trusted不等价pair；未知布局partial |
| device diagnose | 已实现执行后端及ZIP安全发布 | 仅fixture；实际缺策略调用拒绝 | 未真实采集；可能含host CoreDevice日志；archive上限为本地接纳，非采集磁盘峰值 |
| watch Simulator配对关系 | 已实现 `sim pairs` | 实际空集合成功；非空关系仅fixture | 不证明物理watch配对/连接/输入；旧sim pair/unpair保留 |
| watch Crown/侧键/Action | Crown/Action 有公共 XCTest 后端，Triton 尚未接入；普通侧键无精确公开 API | 公共后端已核实，未集成/未实测 | 需独立 watch UI-test runner；Action 先硬件探测；GUI 不等于 CLI |
| tvOS焦点/选择/返回 | `XCUIRemote` 方向/select/menu + `hasFocus` 公共后端，Triton 尚未接入 | 公共后端已核实，未集成/未实测 | 需独立 tvOS UI-test runner 与焦点 fixture；menu 的返回效果需后置断言 |
| visionOS视角/场景/输入 | Designed for iPad 的 2D UI automation 与部分元素 API 有公共方向；原生空间视角/场景无稳定 headless API | 公共方向已核实，未集成/未实测 | 2D、原生空间、gaze/6DoF 分开 runner 验收；不能用 pinch 或 GUI 菜单冒充 |
| macOS | 既有Xcode build/test workflow | 原有兼容测试 | Device Hub观察/控制仍未支持，非CoreSimulator或ios-real路由 |
| 非iOS Apple physical发现与选择 | 已实现独立`device platforms --include-real-devices --device` | watch/tv/vision/mac仅fixture；本机实际3个iPhone metadata及单项选择 | SDK显式physical/硬件字段来源，未知保持unknown，旧iOS动作router不扩大 |
| SDK26/27命令兼容 | 旧入口/通用参数保持 | 旧/新布局fixture与完整回归；本机27.1真实 | 未安装旧SDK，不称SDK26真实验收 |

## 安全验收边界

- 无业务文件内容读取；App与Group输出不含bundle/group/native paths及entry names，artifact 0700/0600。
- 管理动作必须明确execute-runner+confirm+audit-record。审计先行，single native invocation，无超时重试；诊断no-finder、no-host-sysdiagnose仍不等于device-only。
- ZIP发布拒绝覆盖/符号链接，私有目录、0600、有界复制、central/local/data descriptor关联检查；不解压、不验证CRC内容或采集完整性。
- 外部devicectl仅接收路径，前后workspace inode检查不能消除同用户并发替换全部TOCTOU；不声称绝对无竞态。
- 首轮增量编译与修改交错让新增trust/空白audit反例命中旧实现；修正后停止子agent写入并重跑集中验证。空白audit的反例最初遗漏native runner注入，触发对固定不存在标识的失败尝试，未使用真实设备标识；已补全runner/probe/workspace隔离，相关本地intent保留审计，不计作真实管理验收。

## 自动化与本机证据

最终CLI 1135 Swift Testing /101 suites +14 XCTest通过；根包313 Swift Testing /44 suites +7 XCTest通过。public skill递归命令快照与真实schema匹配；文档门禁183 spaces、ci-docs、diff check通过。详见[脱敏验证ledger](./20261010-capability-batches-verification.json)。`--local`首轮通过，最后同源码Release复验通过；通用Xcode Simulator build显式跳过，不计通过。

本轮未提交、合并、推送或发布；新代码保留独立worktree。主仓已由其他工作推进，后续集成需以当时HEAD重做冲突及门禁复核。原生DeviceFS→SDK容器映射、非iOS设备实际验收与专门输入后端仍是明确缺口。
