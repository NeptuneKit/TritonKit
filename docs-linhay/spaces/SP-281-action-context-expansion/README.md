# SP-281 — ActionContext 共享回执与动作证据

## 当前结论（2026-11-12提交收口复核）

**共享回执/证据与parity parser已落地；P2统一执行迁移没有完成。** 前轮“P0–P2全部完成”的声明撤回，不把operation字符串测试、DTO或全量绿色当成真实入口接线证据。

- 两类已接线入口：typed `device tap/double-tap/swipe/press/type` 与 specialized `device platform-control` runner。
- `runSimpleHostCommand` 为明确app mutation的正常返回路径添加shared receipt；只读app命令不能获得mutation admission。
- 当前是本地实现/验证与提交收口，不是推送、发布或用户设备验收。
- 原始业务数据与证据规则以[SP-286](../SP-286-raw-business-data/README.md)为当前权威：默认保留原值，上层决定业务策略。

## 已有生产链路

1. typed device action和specialized runner使用ActionContext、admit与共享receipt。
2. typed device action处理returned/thrown nonzero、timeout、部分double-tap、nested error、stale和lease HTTP冲突；unknown不重放。
3. opt-in evidence在输入前claim新0700根、0600/no-follow FD写入，拒绝旧目录和覆盖。
4. typed receipt/events/meta与原provider响应、已采集host输出分别保存；native attachment是原Data，缺原Data的runner诊断标derived。
5. artifact含bytes/hash/fidelity；prefix或无法获取流有coverage/partial，不冒充完整原件；capture失败不擦除动作事实。
6. parity HTTP生成的完整argv可进入真实root parser。该测试不等于已完成真实HTTP到设备动作验收。

## 未完成，不能再记为已交付

| 路径/机制 | 当前源码事实 | 剩余工作 |
| --- | --- | --- |
| Simulator HID迁移 | SimTap/SimSwipe实际调用runWebHostDeviceInput，不经过host receipt helper；sim.press标签不证明命令存在 | 在真实函数入口接线并测试成功/拒绝/timeout；不能用字符串构造替代 |
| 普通host failure receipt | runHostCommand抛nonzero/timeout后走旧failHostCommand，跳过新增receipt；helper可投影非零result不等于生产catch已接入 | 保留handle贯通统一failure finalization，并覆盖真实throw路径 |
| 常驻统一owner | 默认admission/generation每调用新建，仅显式共享store覆盖进程内 | 统一owner/锁/取消与跨入口执行；不是加字段即可完成 |
| act/app/WebView/管理/workspace/replay | 各自有专用保护，未全部复用统一coordinator/receipt | 分入口迁移，保留resident iOS已有ledger/lock，不削弱旧保护 |
| observation/settle/business | alias、selection、resident iOS、workspace局部已有 | 绑定同一action结果和真正provider前检查；不凭传入ID宣称fresh |
| Stop/resume | 局部Runner stop/lease takeover/workspace状态，不是全局屏障 | 根据上层需求设计统一停止/交回；已送达动作不能声称撤回 |

不把P2范围缩成“app正常输出多了一个receipt”来宣告完成。Pinky式业务敏感识别/默认人工审批已经被用户否定，不是后续默认建设任务；保留技术执行正确性与上层显式控制。

## 记录与验证

- [最初P0/P1合同](./plans/20261111-p0-p1-main-contract.md)与[历史验收](./plans/20261111-validation.md)：历史候选事实，之后raw证据规则已被SP-286更新。
- [P0/P2历史候选与纠正](./plans/20261111-p0-p2-main-validation.md)：绿色测试计数保留，但不证明P2完成。
- [原P0–P6路线](./plans/20261110-action-context-expansion-roadmap.md)：历史方案，不自动扩大当前范围。
- [2026-11-12提交收口](./plans/20261112-session-closeout.md)：精确文件归属、纠正、当前门禁与本地提交边界。

lease HTTP check→provider仍是非原子窗口；size/hash不是签名，subprocess不是OS沙箱；业务后置仍需独立验证。未运行设备、签名/DDI、第三方代码或远端写入。
