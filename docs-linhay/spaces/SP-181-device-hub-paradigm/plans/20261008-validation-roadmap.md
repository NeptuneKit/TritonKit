# Device Hub 机会：分阶段验证路线

> 本文是实施候选，不是当前CLI schema，也不自动授权设备操作/设置写入。研究裁决见 [研究报告](../../../dev/20261008-device-hub-paradigm-research.md)，证据见 [来源台账](../../../dev/20261008-device-hub-sources.md)。本轮不新增实现space；获选阶段开始实现时另建全局递增SP、独立worktree与BDD/TDD。

## 0. 优先级与投入边界

1. **P0：可信目标与输入验证**——先封口已暴露的Xcode27几何/host验证问题，建立session聚合所需的底座。
2. **P1：一个跨平台可复现case**——复用observe/act/verify/plan/evidence，不搭全新调度中台。
3. **P2：官方agent backend契约与环境扩展**——读schema/权限，按事实决定是否集成；不能因历史“不依赖IDE”就拒绝调查新官方服务。
4. **P3：真机私有协议**——先证明需求与官方缺口，再单独立项。

不要同时承担窗口产品、Rust远控栈、MCP业务面与多平台重构。各阶段预算由实施时真实规模决定，本报告不伪造人日估算或市场ROI。

## 1. P0-A：官方JSON与目标身份兼容

### 影响层

shared model、CLI device discovery、capabilities/doctor与target resolver。Web DTO只消费结果，不参与kind判断。旧工具版本继续可用，不仅按Xcode major做分支。

### 先失败测试

- Given旧devicectl list/details fixture，Then兼容现有字段和readiness语义。
- GivenJSON v5 new-only properties/混合deprecation fixture，Then显式读取/映射；未探测的readiness标为unknown，不默认为ready。
- Given官方details弃用记录但list样本尚缺，Then不能把details fixture当list真实格式；各action保留独立parser契约。
- Givensimctl和devicectl同时返回同一simulator，Then按明确kind与identity映射去重；没有映射的对象保持候选，不用名称合并。
- GivenUUID/UDID/CoreDevice ID多个标识、多个booted目标，Then解析唯一或返回ambiguous，不选最后窗口/列表第一项。
- Given工具输出含warning/deprecation，Then对外stdout仍单一合法envelope，工具artifact与终端log不混入JSON。

### 真实验收（执行前必须Triton-first）

先保存 `triton status/doctor/capabilities/schema/plan` 的JSON事实；仅对Triton未覆盖项读取官方help或工具JSON，记录fallback原因。需要的fixture从获授权设备获取、脱敏私有identity，不上传真实配对/项目数据。

完成条件：old/new fixture通过；Xcode26/27可用矩阵有实际样本或明确skip；simulator与real不误分类；“已发现”与“服务可操作”分开。没有真机样本不得宣称全真机兼容。

## 2. P0-B：几何、观察与动作receipt

### 影响层

shared geometry、host adapter、CLI action与verify、evidence。合并已有目标/observe缓存，不另开Web写接口。

### 建议契约（示意，未实现）

```json
{
  "target": "sim:<redacted-id>",
  "observation": {
    "id": "<observation-id>",
    "generation": "<connection-generation>",
    "geometryRevision": "<geometry-revision>",
    "coordinateSpace": "device-logical-points",
    "source": "embedded-or-host"
  },
  "execution": { "state": "sent", "strategy": "host-hid" },
  "verification": { "state": "uncertain", "required": true },
  "evidence": { "before": "<ref>", "after": "<ref>" }
}
```

generation不是lease；lease控制谁有权写，generation控制旧观察/命令是否还属于当前连接。screenID、orientation、logical bounds、pixel dimensions与bezel必须能区分。视频时间不自动等于guest生成时间；只看到UI变化也不自动等于业务完成。

### 先失败测试

- aspect-fit/letterbox、skin inset、logical point与pixel scale、四方向、resize/multi-screen；空白区不发送输入。
- observation后方向/geometry改变；未重新绑定前拒绝动作，不靠clamp掩盖错位。
- session切换后旧帧、旧命令、旧close到达：不影响新target。
- 网络延迟/animation/AX stale/同文案多目标：不能仅凭ACK返回verified。
- host可用但embedded缺失：明确scope/strategy与missing capability，不假装同等语义。
- input失败或取消：release held状态有界、错误保留，不stopAll或关闭别人启动的device。
- 完全未知frame freshness不能作为授权新输入的“最新帧”。

### 最小真实case

获授权受控Debug App内，选一个确定性按钮导航和一个输入/滚动场景；embedded后置条件与host截图联合验收。至少覆盖portrait/landscape或两种scale。只允许目标明确、能力可用的路径；host失败保留原error/partial，不以embedded成功覆盖host失败。

交付门禁：unit first-red/green记录；focused与完整适用回归；机器可读失败envelope；before/action/after trace；SP-180 host navigation独立结果。加载器恢复、tap返回0与业务成功是三项独立验收。

## 3. P1：可复现的开发会话纵切

### MVP用户任务

“从给定App/构建目标，在指定环境执行一个case，输出可解释结果与可复跑recipe。”

首期两个平台（iOS Simulator + 已有Android或Harmony emulator），每个平台保持自己的能力边界。不要求真机、live video、resize/foldable、MCP、桌面写控制、设备云或任意App全系统语义。

流程：选择target/build/app → 环境read/capture → 显式apply → read-back → observe/act/verify → evidence → restore本人改动或报告manual restore → 输出plan与diff。

### BDD

- Given同一个case意图，When换平台，Then输出共同execution/verification/unsupported语义，而不是只统一命令名字。
- Given环境字段不支持apply/read-back/restore，Then逐字段能力与unsupported可见；不把record-only宣称恢复。
- Givencase失败，Thenplan在失败步骤停止、evidence包含before/after与skipped/errors，不能仅看少量artifact存在。
- Given两个agent且显式lease，Then写冲突稳定返回；不带lease的旧行为与外部Apple UI不被误称“已排他”。
- Given只读Web，Then显示target binding、环境差异、策略与验证证据，不成为另一调度/写入口。
- GivenDebug embedded，ThenRelease继续可编译、no-connect/no-collect/no-control。

### 价值实验与比较基线

固定App版本、OS、机器、case和同等授权；比较：现有Triton手工命令串、候选session recipe、官方Xcode agent能覆盖的Apple子集。保留所有失败/重试，不选一次最好结果。建议至少10次受控重复/条件，每个结果先判verified/uncertain/failed，再统计。

记录人工准备步骤、目标选择错误、假成功、故障定位往返、首次准备耗时、可复跑成功比例、backend维护时间。这里次数是实验设计，不是本轮已跑结果；验收阈值在实现前根据baseline登记，不能事后调阈值。

继续条件：明显减少准备/定位工作且不增加假成功；跨平台确实被用户使用。停止条件：同语义无法比较，退回平台特化trace；没有采用价值，不继续扩大session抽象。

## 4. P2：官方agent backend与环境能力探索

独立只读契约调查：官方服务发现、tool schema、授权、code signing、workspace/IDE依赖、target支持、screenshots/freshness、错误格式、headless限制。release notes预览不是稳定SLA。

后续PoC只实现一个目标绑定+截图+一个动作，wrapped behind Triton strategy；不外露Apple tool name，不让MCP成为业务事实层。旧私有adapter必须可单独关闭，不双发动作。

采用条件：真实降低private framework维护且目标/授权/输出可绑定；拒绝条件：不可控全局权限、不能精确target、只能靠窗口焦点或不可用headless时作为默认。保留可选backend，不因“官方”自动替换全部已有策略。

环境扩展候选：字号/外观/locale、既有location、按domain限定App数据/crash log。DeviceFS默认只读取allowlisted小文件并脱敏；禁止整盘归档/配对记录/任意私有用户文件。不可恢复的配置必须提前machine-readable告知，不静默重置。

## 5. P3：真机与私有协议立项门槛

先回答：哪些真实回归必须真机？官方Device Hub/CLI/MCP是否已满足？embedded增强需要哪些接入？用户是否接受Developer Mode、DDI、配对与私有接口版本风险？

只有明确缺口才建立独立space与隔离helper。真机transport研究至少覆盖认证失败、身份持久化、锁定/DDI readiness、会话竞争、generation、HEVC丢包、新鲜帧门禁、输入release、teardown、本地密钥保护。不要为证明demo把stopAll作为恢复手段。

暂停条件：授权/安全边界无法满足、版本成本超过价值、官方路径已覆盖需求。性能、协议兼容、设备型号覆盖必须真实实验，不引用README作为本产品支持矩阵。

## 6. 本轮DoD

- [x] 官方、开源与本地证据分级。
- [x] 非目标/产品边界与未实测项明确。
- [x] 机会有反证，路线有BDD与停止条件。
- [x] research space、索引、来源与memory已归档。
- [x] 文档门禁通过并在space与memory记录结果；这里只表示docs-only验证，不填产品测试通过。
