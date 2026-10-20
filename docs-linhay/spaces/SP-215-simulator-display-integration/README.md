# SP-215 — Simulator 显示器安全主控

## 边界与状态

2026-10-20 新批次主控，仅负责 [SP-214](../SP-214-simulator-display-safety/README.md)。旧 SP-206/211/213 已交付，不扩张其历史范围。本 space 已完成离线主控验收，候选随 SP-214 一并合入本地 `main`。

branch `feat/SP-215-simulator-display-integration`；worktree `../TritonKit-worktrees/SP-215-simulator-display-integration/`；产品基线 `main@f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`。模型必须显式 `gpt-6.1-sol`，不可用则保存真实失败、不回退。

## 主控验收（2026-10-21 完成）

- Requested：仅确证主屏安全或拒绝未知/非主屏，不新增 Duo 控制产品。
- Observed/Evidence：复核候选 `bee3d609` 的实际 diff；`943f46c3` 接入 fresh `devicectl displayTopology`，`bee3d609` 补齐命令回显、target 绑定、错误 JSON、超时和非零结果处理。生产 screenshot/AX activation 默认经过 display probe，测试保留注入 seam。
- Acceptance：`SimulatorDisplaySafetyTests` 4 tests、`SimulatorResizeCaptureRoutingTests` 3 tests 通过；unknown/非主屏路径在 native action、输出文件和流字节之前拒绝，合法单屏与既有 Resize 语义保留。
- Gaps：未执行真实 Xcode/Simulator display topology；因此仅确认离线契约与 CLI 接线，不宣称设备效果。禁止安装依赖、上游代码执行、设备/签名/DDI、push/tag/release。
- Result：SP-214/SP-215 联合验收通过，允许本地合入 `main`；主控工作区保留至本地合并后清理。

允许与本批次 SP-214 执行会话协调、处理冲突、跑独立联合门禁，必要本地提交并合入本地 main。共享副作用串行，不 stash、不混其他 WIP；合并前核对实际 main 与所有 worktree。同步 SP-214/SP-215、索引、正式契约、memory 和 SP-207 采用登记；记录实际 SHA/命令/数量及通过、失败、未执行阶段。

只有真实创建成功才登记 thread ID；部分失败仅补缺角色，不重复建 space/worktree。不向外部发消息。后续确需新建本项目执行/主控会话也必须显式 `model="gpt-6.1-sol"`，并沿用以上边界。

## 2026-10-20 分派结果（历史）

必要创建请求显式 `model="gpt-6.1-sol"` 后被桌面接口以 `could not validate model` 拒绝，无真实 thread ID；该失败仅记录分派历史，后续由本地执行流程完成实现与验收，记录见 [分派证据](../SP-207-reference-adoption-pipeline/plans/20261020-dispatch.json)。
