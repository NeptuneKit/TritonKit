# SP-181 Device Hub 范式与 TritonKit 机会研究

- 日期：2026-10-08（Asia/Shanghai）
- 状态：研究已归档／实现待定；不代表实现立项或发布承诺
- 用户请求：深度调研 Xcode 27 Device Hub，把它作为产品机会与范式分析，而非仅处理兼容性。
- 基线：本地主线 `0231d883`，开始时工作区干净、领先远端 1 个提交；不提交、不推送、不处理无关 worktree。
- 工作区：本轮当天 docs-only 调研在主工作区完成；两个 subagent 仅只读研究外部资料，不拥有仓库写入面。后续实现或多日研究另建独立 worktree。

## 影响层与边界

涉及 shared core / CLI / HTTP 的未来架构评估，以及 Web / 桌面展示层定位；本轮只新增研究文档。覆盖 Apple 官方产品/CLI、开源展示与协议实现、TritonKit 当前源码与历史证据。真机协议只研究，不扩大当前设备控制能力承诺。

非目标：产品代码修改、设备启动/输入/安装/配对、服务启停、Xcode defaults 修改、安装依赖、公开 issue/PR/提交/推送、重新开放 Web 写控制面、可靠性或性能实测。

## BDD 与调研验收

1. Given 官方 UI 能力，When 分析自动化机会，Then 明确 UI、官方 CLI、私有接口三条证据边界，不把远控演示等同于公开 automation API。
2. Given 开源项目宣传，When 评价借鉴价值，Then 用关键源码/测试与固定 revision 核查，分开项目声明、源码事实、实测未知。
3. Given TritonKit 当前实现，When 设计范式，Then 明确已有 CLI/embedded/host/evidence/lease 能力和缺口，不把历史 prototype 或未跑真实设备测试当产品 SLA。
4. Given 机会判断，When 提出路线，Then 给出最小价值闭环、可证伪假设、拒绝项、阶段验收和停止条件；后续实现不由研究自动授权。
5. Given 本轮 docs-only 改动，When 交付，Then 同步索引与 memory，运行 docs gate 与 whitespace 检查，保留无法实测的风险。

## 交付物

- [技术与产品研究报告](../../dev/20261008-device-hub-paradigm-research.md)：范式、竞争面、源码映射、机会与不做。
- [来源台账](../../dev/20261008-device-hub-sources.md)：8组官方资料、两个固定开源revision、具体源码和前轮纠错。
- [分阶段验证路线](plans/20261008-validation-roadmap.md)：P0可信目标/几何/verify，P1跨平台case，P2官方agent backend，P3真机协议立项门槛。

## 研究裁决与证据

- 机会不是Apple无agent工具：Xcode27已有boot/install/launch/touch/screenshot与MCP扩展，以及无需workspace的server预览。定位候选为“移动应用开发的可验证执行层”，统一开发会话的身份、环境、控制、观察与证据，而非另造Simulator窗口。
- 官方devicectl覆盖真机/已启动模拟器；simctl仍负责启动。DeviceFS按domain限权；UI能力不等于公开CLI。JSON v5 details旧字段弃用，现有list parser需fixtures确认，不能把未知ready视为真。
- OpenDeviceHub固定 `e50f07f1`：公共simctl生命周期、私有XPC输入、纯坐标转换；tap没有业务verify。
- device-hub-ios固定 `1fcdfb0a`：attempt/session/generation、输入撤权与cleanup、媒体帧归属、Swift/Rust分层；私有协议不进入默认依赖。
- 主控已读当前Triton源码：embedded语义/跨平台观察/evidence/opt-in lease可复用；Framebuffer旧路径不被baguette子进程修复覆盖；SP-180 host命中仍不冒称完成。
- 两个只读subagent提供中间线索但最终失败，没有把其未完成报告算交付；主控直接复核关键官方/源码，未复核性能线索不列结论。

## 验证与未测

- 已通过（exit 0）：`docs-linhay/scripts/verify.sh --ci-docs`、`docs-linhay/scripts/check-docs.sh`、`git diff --check`；181 spaces登记一致。5份新文档的36个本地链接与行锚核查通过；最终来源台账另复制到可追踪dev目录（references目录被仓库忽略），随后复验。
- 资料副本保存在忽略的references目录，交付/可追踪事实源是上面的dev来源台账；没有修改ignore规则或强制stage。
- 本轮不运行产品tests或设备回归：只有docs变更、没有设备动作授权；官方MCP schema/权限、Xcode27 JSON fixture、真实host几何/业务verify、跨平台采用价值和私有协议稳定性留待分阶段验收。
- 没有Git提交/推送、产品代码改动、用户设备/设置/凭据写入。后续实现需新space与独立worktree。
