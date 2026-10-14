# SP-192 — iCTRL 借鉴机制与本机接入实现

## 状态与范围

- 状态：实现及 Android/iOS 验证限制已收口；已提交并合入本地 main，集成后本地总门禁通过。iOS 115 项、Android 52 项及本地总门禁通过。
- 用户请求：可行性核对后开始实现五项借鉴机制。
- 系统解释：TritonKit 当前架构，以及当前 Mac / 已选 Xcode / 可发现的设备环境；不猜测其他私有业务工程。
- 代码基线：`main@8aaf6c31d308194b489e10ed83362cee91f549d5`；参考 iCTRL `99dbfecdb39836ba26a0b2b0dcfde90f705a6835`。
- 影响层：CLI、HTTP、shared contract、embedded runtime、host observation；Web/Wails 仅消费只读结果。
- 实现分支：`feat/SP-192-ictrl-adoption-feasibility`；worktree：`../TritonKit-worktrees/SP-192-ictrl-adoption-feasibility/`。源码已由实现提交 `e308a2eb` 经合并提交 `da76a708` 进入本地 main；worktree 保留私有验收产物。

## 已实现机制与验收边界

| 机制 | 当前实现 | 保留边界 |
| --- | --- | --- |
| alias 新鲜度 | schema 2、30 秒有效期；`node resolve @N` 重新观察当前 UI，校验平台、真实目标、来源、全树身份指纹与唯一候选，返回当前 frame | 换页、OID 变化、歧义、过期或当前采集截断拒绝；host 完全相同树的同页重启无法辨别，不新增 `tap @N` |
| 采集预算 | Simulator AX、embedded hierarchy/AX、Android bridge、Android XML 与 Harmony 解析增加节点/深度/子节点/deadline 限制；collection / truncation metadata 保留到只读 scene | 解析预算不能取消已经发生的设备 dump 或 native IPC；后端实际覆盖分别验收 |
| 视觉 settle | `triton observe settle` 有界截图采样和连续稳定窗口；workspace 通过 `--visual-settle` 显式启用动作后反馈 | settled 只证明画面稳定，`businessVerified=false`；timeout/unknown 停止自动续行，不替代业务断言 |
| OCR | `triton observe ocr` 使用 host Vision，显式 policy、来源、时间来源、置信度、坐标系和 `candidateOnly` | raw-raster 像素坐标，只有已知 scale 才提供 points；文件 mtime 不是截图时间，freshness 为 unknown；无语义 OID、无自动点击 |
| UI 健康 | 非 MainActor admission / ping 诊断、占用请求、超时 unknown、连续超时熔断、恢复提示 | timeout 不终止正在执行的 UI/native 工作；保持占用直到真正完成，unknown 不自动重放；旧 ping 缺失 uiHealth 时健康为 unknown |

## BDD 与验收

- Given 缓存别名，When resolve，Then 必须重新采集并验证身份；微调布局返回新坐标，失效或多候选拒绝。没有 provider generation 时不能宣称所有重启都能识别。
- Given 宽深树或慢 provider，When 采集，Then 限制遍历和后续调用并输出限制原因；Swift/JS scene 归一化不能丢失 collection metadata。
- Given 连续截图，When 达到稳定窗口，Then 返回 settled；持续变化返回 timeout，截图失败返回 unknown。业务断言失败不能因 settled 变为 verified。
- Given 明确 OCR policy，When 识别图像，Then 返回有来源和置信度的候选；低置信度或坐标不确定不执行动作，不把图片修改时间当作采集时间。
- Given UI 工作超时，When 查询健康或再次申请动作，Then 诊断不等 UI，原请求占用保留，新动作拒绝；不知道副作用是否发生时不能重放。
- Given 原始诊断含身份、路径、App 或设备信息，When 写入公开文档，Then 仅发布脱敏摘要。

## 非目标

- 不复制 iCTRL 的私有 XCTest API 到 embedded SDK；不改变 Debug/Release 与 SwiftPM 依赖边界。
- 不新增远端 HTTP 产品面、Web/SSE 控制面或长期监控任务。
- 不自动挂载 DDI、导入配对材料、签名 Runner 或执行真实输入。
- 当前授权包含本地提交与 main 集成；不推送、发布，也不改动其他 space 的实现。

## 产物

- [可行性报告与实施切片](./plans/20261014-feasibility.md)
- [实施计划与待验收项](./plans/20261014-implementation.md)
- [构建与回归限制收口](./plans/20261014-limitation-resolution.md)
- [整理沉淀与 main 集成](./plans/20261014-integration.md)
- [脱敏环境摘要](./plans/20261014-environment-summary.json)
- [技术接入边界](../../dev/20261014-ictrl-agent-feedback-adoption.md)
- 原始环境输出：`.triton/sp192-audit/`（gitignored；不作为公开证据发布）。
- 截图目录：`screenshots/`；真实只读截图仅用于私有临时 OCR / settle 验收，公开文档只记录数量和状态，原始画面不归档至公开目录。

## 实现验收与环境限制

- 研究阶段的只读 Triton-first 探针已完成：macOS 27.0.1 arm64 / Xcode 27.1 / Triton 0.2.26；合成图片 Vision OCR、坐标边框校验通过，指定既有 Simulator 原生 AX 返回 42 节点，HID 框架兼容探针通过。这些事实不等同本次源码构建已验收。
- 完整 CLI 1250 项、117 suites，根包 macOS 274 项、37 suites 全通过；Web hierarchy 12 项和 TypeScript/Vite build 通过。首轮 unavailable 事件、schema 快照和多帧产物路径失败已补失败测试并修复。
- 真实只读 Simulator：max-nodes2访问/返回2节点且报告限制；49个outline别名、活resolve成功；OCR返回20个candidateOnly候选；视觉判稳3样本、1.919秒，businessVerified=false。现有旧SDK的健康探针pong正常、uiState=unknown，不把旧SDK当新SDKUI健康验收。
- iOS 最终 runtime package suite：115 passed、0 failed、0 skipped；已修复此前三项 alert 路由测试的窗口夹具和一项 alpha/opacity 联动断言，新增两个独立属性入口测试。真实 alert responder/背景 candidate 都先断言，不把 hostless 路由单测当作 App presentation 验收。原始失败对照保留于实施计划。
- Android 官方依赖源恢复后，完整 Gradle testDebugUnitTest / assembleDebug 成功；8 suites、52 项全部通过，Debug APK 已生成并校验 ZIP/manifest/dex。无 Android/Harmony 实时目标，不将本机 APK/fixture 当设备运行证明。
- 本地总门禁已通过，结果见[实施计划](./plans/20261014-implementation.md)。未发送真实触摸输入，OCR raw-raster到输入坐标尚未做校准验收；原始诊断与画面只留gitignored私有目录/临时目录。
- 独立 iOS Runner/DDI 不属于 SP-192，本 space 不宣称已经支持；本次只进行本地提交与集成。

最终验收按 [实施计划](./plans/20261014-implementation.md) 执行。视觉稳定不能替代业务验证，未知动作不能自动重放。
