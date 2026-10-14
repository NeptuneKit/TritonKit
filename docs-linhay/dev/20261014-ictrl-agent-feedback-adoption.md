# iCTRL 机制在 TritonKit 的接入实现与边界

关联 space：[SP-192](../spaces/SP-192-ictrl-adoption-feasibility/README.md)。五项实现及本地总门禁完成，源码已提交并合入本地 main（实现 `e308a2eb`，合并 `da76a708`），未发布。CLI1250项全通过；用户授权继续处理后，iOS 115 项及 Android 完整 Gradle 52 项 / Debug APK 已通过，详见文末验收。

## 已接入位置

沿用 CLI/HTTP 的 observe、node、workspace、hierarchy 和既有输入/证据流程，Web/Wails 仅读取 DTO。五项机制已有源码和测试；独立 iOS XCUITest Runner/DDI 不属于本 space。

| 模块 | 当前实现 | 证据边界 |
| --- | --- | --- |
| Observation identity | alias cache schema 2 / 30 秒 TTL；`node resolve @N` 实时采集，核对平台、实际目标、来源和全树身份指纹，唯一匹配返回当前 frame | 忽略 geometry/focus，保留节点 ID、语义与能力；旧 schema、过期、换页、新 OID、歧义或当前预算截断拒绝。没有 provider lifecycle generation，host 完全相同树的同页重启无法辨别 |
| Collector budget | Simulator 翻译准备/属性读取、embedded hierarchy/AX、Android bridge tree、Android XML / Harmony host parser 增加节点/深度/子节点/deadline 预算，输出 collection / truncation | 完整数组获取、IPC、设备 dump 或解码阶段仍有独立限制；不能把后续解析裁剪当成设备端预算，也不保证 native 硬取消。Swift/JS scene 保留已知 metadata |
| Visual settle | `observe settle` 根据有界 raw-raster 缩略图的 RGB 变化面积和连续稳定窗口给出 settled / timeout / unknown；workspace 显式 `--visual-settle` 接动作后反馈 | `businessVerified=false`，业务断言仍独立；timeout/unknown 停止自动续行，不伪造观察、不自动重放动作 |
| OCR provider | `observe ocr` 使用 macOS Vision，explicit / structure-unavailable policy、置信度、来源、时间来源、freshness、坐标 DTO 和 candidateOnly | 不生成语义 OID或自动点击。原点左上角、raw-raster 像素；已知 scale 才提供 points，不隐式保证方向或输入映射。文件 mtime 不是采集时间，freshness=unknown |
| UI health | admission 和 ping 诊断在 MainActor 外运行；保留占用、timeout unknown、连续超时熔断、真实完成记录与显式恢复提示；Android UI/健康隔离资源 | timeout 释放等待但不会终止 MainActor/native 操作；未知动作保持占用至真正完成，不能重放；旧 ping 没有 uiHealth 时状态 unknown，不宣称 ready |

## 使用入口

```text
triton observe tree --device sim:<udid> --outline --json
triton node resolve @1 --device sim:<udid> --json
triton observe settle --device sim:<udid> --timeout 5 --json
triton observe ocr --image <path> --policy explicit --json
triton observe ocr --device sim:<udid> --policy structure-unavailable --structure-unavailable-reason <reason> --json
triton workspace run <既有参数> --observe-live --execute-actions --visual-settle
```

视觉观察可以使用既有连接 runtime 的 `--target <id>`，或限定 simulator/emulator 的 host selector。host 真机视觉截图不在本期入口范围；直接 embedded HTTP 缺少截图数据路由时返回 unknown，不猜测其他设备。OCR fallback 要显式给出 policy 和结构不可用原因，没有自动启发式 AX/DOM/OCR/VLM 全链调度或低置信度点击。已有 VLM 路径继续保留。

workspace 的视觉选项包括 `--visual-settle-timeout`、`--visual-settle-stable-window`、`--visual-settle-threshold` 和 `--visual-settle-interval`，需要同时启用 live observation 和 action execution。只有 settled 允许后续自动流程继续，不能把视觉稳定转换成业务 verified。

## 各预算的实际覆盖

- Simulator AX：受限遍历先 admission，再翻译准备、属性读取和 children；各调用之间检查 deadline，避免无界整树预处理。一个已进入的 native 查询或完整 children 数组获取仍不能被遍历器硬取消。
- Embedded：UIKit hierarchy 和 AX 采集在节点读取/递归处应用预算，默认节点 800、children 200、deadline 2 秒；AX 默认深度 32，hierarchy 使用既有深度上限。snapshot 用 truncation 表达 AX 限制，scene 保留 collection。
- Android：新版 bridge tree 采集采用预算并返回 metadata；UI/health 请求资源隔离。UIAutomator fallback 的主机 XML 解析有预算，设备 dump 本身属于独立命令过程。旧 bridge 是否收到预算不应仅凭请求参数推断，结果和版本必须核验。
- Harmony：主机 layout 解析/转换和结果融合受节点等预算限制，hdc dump、传输和解码不因此获得设备端可取消保证。

## 平台与安全边界

保留 iOS Debug-only bootstrap / Release no-op 和根 SwiftPM 无 CLI-only 依赖的边界，不将私有 XCTest API 放入业务 App。macOS host Vision 的合成图片探针已证明本机 API 可用，不能替代本次产品 provider、真实截图方向/scale 与设备输入坐标验收。

runtime UI 默认 deadline 30 秒、连续超时阈值 3。超时返回 unknown 仅表示响应未按时完成，不能推断副作用未发生；真实完成后 admission 才释放，连续超时熔断需显式恢复。CLI/HTTP 仍使用单一合法错误 envelope。未知、未启动或健康字段缺失不能升级为成功。

现有弱引用 OID registry 和 WebView pageSessionID 继续复用。transport generation 不是 page generation；本次 alias 指纹不会修复所有 same-URL reload / 完全相同页面生命周期变化。

## 验证与收口

失败场景与最终门禁见 [实施计划](../spaces/SP-192-ictrl-adoption-feasibility/plans/20261014-implementation.md)，研究阶段的机器条件与支持矩阵见 [可行性报告](../spaces/SP-192-ictrl-adoption-feasibility/plans/20261014-feasibility.md)。完整 CLI/root tests、Android/JS fixtures、本地门禁与真实 iOS Simulator runtime tests 已执行；设备未覆盖项按实际边界报告。源码已合入本地 main，独立 worktree 保留审计产物，未发布。

## 2026-10-14 实现验收

五项已在 SP-192 worktree 接入现有 CLI/HTTP/runtime。完整 CLI 1250 项、根包 macOS 274 项、Web hierarchy 12 项和 TypeScript/Vite build 通过。真实只读 Simulator 验证 max-nodes2只访问/返回2个节点、49个outline alias及live resolve、Vision OCR 20个候选、多帧判稳3样本/1.919秒，全部不推断业务成功或OCR坐标输入正确。健康命令连接现有旧SDK时pong正常、uiState=unknown；新SDKUI健康由实际handler路径测试验证，未替换用户App。

iOS包scheme编译成功，xcresult 109 passed/4 failed；四项alert/属性修改既有失败全部在原始main基线98 passed/5 failed中重现，新增预算测试通过。Android全部16个主源码文件直接编译、两套纯JVM7项通过；完整Gradle APK与Android-coupled suite受Google Maven连接超时/metadata及缺缓存依赖阻塞。直接编译不替代APK/设备验收。本地门禁结果见[实施计划](../spaces/SP-192-ictrl-adoption-feasibility/plans/20261014-implementation.md)。

## 用户授权后的限制收口

[限制收口计划](../spaces/SP-192-ictrl-adoption-feasibility/plans/20261014-limitation-resolution.md)记录完整诊断与结果。官方 Google Maven 恢复后，原版本完整 Gradle 构建成功，8 suites / 52 项全通过，Debug APK 5,380,381 bytes。未修改仓库源、版本或 TLS 校验。

iOS runtime tests 的完整 xcresult 为 115 passed / 0 failed / 0 skipped。三个 alert 用例修复真实窗口夹具，并先断言同坐标确有背景 fallback cell 再验证不误选背景；属性用例按 UIView.alpha / backing CALayer.opacity 的实际联动和 view→layer 执行顺序验证，另增加两个独立入口测试。未改变产品安全校验。hostless alert responder 单测不代表正常 App presentation 验收；真实 Android/Harmony 设备与 OCR 输入坐标映射仍未验收。
