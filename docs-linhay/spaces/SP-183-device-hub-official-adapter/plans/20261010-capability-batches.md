# 四批实际能力补齐

影响层：CLI / host adapter / shared core / schema；不新增 Web 控制面。
工作区：`../TritonKit-worktrees/SP-183-device-hub-capability-batches/`，分支 `feat/SP-183-device-hub-capability-batches`。由已集成 SP-183 的 HEAD 21e6c1db 继续，主工作区三个既有冲突不触碰。

## BDD 与验收边界

1. App / Group 绑定必须来自显式 SDK metadata + 精确目标身份 + 受限原生容器路径；无证据拒绝语义映射，保留原生选择器、相对子目录和预算，不读取业务内容。Crash 文件域、DeviceFS 目录、诊断包分别建模。Temporary 不确定创建语义时阻止 readonly；执行必须显式策略/审计。
2. pair/unpair/diagnose 执行须具备完整显式策略，先持久审计再执行一次；file JSON 必须身份绑定，区分 failed/timed-out/partial/succeeded，失败不自动重发；配对结果要求独立后置状态。诊断 ZIP 私有、无覆盖、nofollow、有大小验收上限，明确不是传输或峰值硬限额。
3. 专门平台控制只接已核实后端；watch 配对关系、tv 导航、vision 控制、macOS Xcode 与 Device Hub 分界及非 iOS physical metadata 分开。未知/GUI-only 不冒充实现。旧 iOS namespace/argv 保留。
4. schema/fixture/全量 CLI/root/文档门禁与可授权的专用 Simulator 验收分层；无 SDK26 实机不声称真实旧版验收。

本次允许源码、隔离测试和已有授权专用 Simulator 范围；不真机写入，不真实诊断采集，不提交/合并/推送/发布。不存在可确认 ownership 的专用 Simulator 时，不以业务实例代替。

## 证据

- 当前 triton status/device doctor/capabilities/schema 与 plan help 全 exit0，原始输出在 ignored docs-linhay/references/device-hub-batches 私有目录。
- Triton 未提供细分 apps metadata/help 检索，fallback 仅执行 xcrun devicectl help（apps/files/manage pair/manage unpair/diagnose）及 simctl help；没有设备动作。apps 帮助明确 include-app-group-identifiers/include-container-paths/require-container-access/bundle-id。Temporary 是否创建仍不明，不能判 readonly。

## 当前结果入口

[逐能力证据矩阵](./20261010-capability-batches-matrix.md)记录已实现、专用Simulator实测、仅fixture、仅计划和GUI/缺后端。App5项、Group2项实际浅metadata与privacy/0700-0600/JSON及entry预算拒绝过；Crash目录当前Simulator不可用，明确directory_unavailable且无猜映射；配对关系空集合真实过；独立physical inventory本机3个iPhone及exact选择过，非iOS硬件仍fixture。新建专用Simulator最终Shutdown，既有实例names/state逐项不变。管理与Temporary实际只有缺授权早拒绝，无真实目标动作/诊断采集。

## 回归过程与边界修正

- 37个CLI focused/8 suites和shared10/4通过；完整CLI先1133+14通过。随后增加递归子命令schema检查暴露旧设备子命令未登记与public skill快照遗漏，补真实参数/输出selector及快照，不放宽测试。
- Crash实际目录不可用起初归为unsafe_root，改为明确directory_unavailable并补fixture；fixture曾使用macOS temporaryDirectory中的symlink祖先，按严格nofollow正确拒绝，改用真实/private/tmp普通目录后通过，未放宽生产检查。
- Temporary从shared原生命令到DTO统一automation风险，添加实际runtime隔离fixture，审计记录query artifacts、失败返回audit token，完整成功receipt必须绑定全部argv；旧只读域宽容布局保持兼容。
- 新建实例只有create/boot/read-only metadata/shutdown；原有实例names/state均保持。当前主仓已被其它工作推进到6e086247且冲突已清理，未由本任务修改；本worktree仍基线21e6c1db，本轮不自行合并。
- `--local`根包313 Swift Testing+7 XCTest、Release build、smoke、docs等已通过；通用Xcode Simulator build显式TRITON_VERIFY_XCODE=0跳过，替代证据是本任务专用Simulator只读验收，不声称通用构建已跑。最后schema/Temporary测试补强后的全量与local复验均通过。

## 继续推进：容器导航与有副作用查询的执行边界

本批影响 CLI / host adapter / schema，延续同一 worktree，不提交或集成。BDD 先补失败 fixture：

- 已由 SDK 精确绑定的 App/Group 容器可显式选择受限相对子目录，仅浅 metadata；无 `--list`、越界、空段、符号链接、所有权错误和预算超限均拒绝；省略参数保持原 token，子目录范围使用独立 token，不输出原选择内容。
- 原生 mountpoint help 明确查询可能自动挂载。mountpoint 与 fs list 必须先完整允许可能挂载的策略，再进行发现/执行；持久 intent 先于一次 native query，完成与不确定失败有审计关联。保留原生容器、子目录、错误类别与安全预算。实际是否新挂载保持 unknown，风险 automation。
- Temporary 的审计目录在 intent 后被 rename/recreate，或诊断输出父目录被替换，不能错误返回成功，也不能将完成记录写入替代目录。以独立本地文件 fixture 验证，不执行真机动作或诊断采集。
- 专门平台继续核实公共可编程接口；XCTest API 存在与已集成 CLI、专用 Simulator 实测分开记录，不将有公共接口的能力笼统归为 GUI-only。

验收由主控串行执行；各 agent 先提交失败测试并停止实现，统一 RED 后实现，停止写入后再统一回归。

## 本轮继续结果

- `devicectl device info mountpoint --help` 说明查询可能隐式挂载。`device mountpoint` 与 `device fs list` 因此要求 `--allow-mount --confirm --execute-runner --audit-record`，native command 风险为 automation，intent/completion 通过原始目录 FD、device/inode 校验；输出 `mountCreated=unknown`，不再标称纯只读。完整 file-JSON 的 commandType、outcome、error、result 和 argv 均强绑定。
- Temporary 审计与诊断归档新增目录替换 fixture：rename/recreate 后只允许 uncertain/partial 结论，完成记录锚定原始目录，不向替代路径报告成功；未执行真实 Temporary 查询或诊断采集。
- 平台研究确认 watch Crown/Action 与 tvOS XCUIRemote 有公共 XCTest 后端，但尚未集成 Triton runner；visionOS 兼容 2D、原生空间、gaze/6DoF 分开，不能把 GUI 或 SDK 可见性称为已实现。
