# 2026-10-25 Simulator / runtime 参考日检

实际 main `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`，与昨日一致。10仓官方默认分支 HEAD、全部 Release 分页（最新非 draft 含 prerelease 的完整正文）、固定 HEAD 许可证全文及 SHA-256 均完成读取；相对 20261024 无 HEAD、tag、Release 正文或许可 hash 变化。7完整、3原有 partial，无新增采用或通知事项。

|仓库|HEAD|Release|覆盖|
|---|---|---|---|
|tddworks/baguette|458044cceadd25a1366619b3747311ad7d959f94|v0.2.10|partial|
|EvanBacon/serve-sim|0193e65c481fc9b64a62427f32fcf143dbc3d2c0|无|完整|
|lycorp-jp/sim-use|c02295edfd2f442249b869096dda3dc7bfcd308d|v0.16.0|partial|
|MobAI-App/simslim|6518ba7eab1123d7e1d7797b0e05f51043b42a5b|v0.12.2|完整|
|Mastersam07/OpenDeviceHub|e50f07f1f4480cb14d57f192df7bf598ca26e708|v0.2.0|完整|
|JaviSoto/device-hub-ios|3779e12aa00c08bb34805fef8ffe375838cbe815|无|partial|
|heoblitz/Loupe|ff1351242e6dbaba4a0b4de40d10350a668f03b8|v0.5.1|完整|
|jfarcand/mirroir-mcp|502c5e466da4d82df8f65ffa9a598c01e152b56b|v0.40.1|完整|
|RockxyApp/Rockxy|de791b63e7f9b5df49f127524a5c9320e675eb23|v0.41.0|完整|
|ProxymanApp/atlantis|cc059013de8778072b4fea6453b45e964e4202fe|2.0.0|完整|

成功检查点/import 与昨日观察分别比较；results.json 保留两个变化字段。Baguette 的旧二进制来源缺口、sim-use 的省略 CHANGELOG patch、device-hub-ios 的省略 protocol.rs patch 未闭合，继续 partial，不能因今日无变化推进其成功点。复用昨日固定 SHA 安全文本及语义评估，未再次请求二进制、helper、身份、证书或密钥内容；仅抓取官方元数据、Release 与许可证文本。

已按实际 main blob 保存 main-coverage.json，核对 SP-192/196/200/214/218/219；主线与昨日相同，现有 AX geometry、display fail-closed、Resizable 录制路由、native HID 归属机制无需重复排期。SP-218/219 已有 Xcode27.1/iOS27.0 专用 Simulator 普通 HID、Hub占用拒绝恢复与普通→Resize→普通录制证据，v0.2.33 已独立发布；本轮只复核已有报告，不执行设备或构建。Resize AX/HID 仍 unsupported，不能外推其他工具链/用户工程。

未运行第三方源码、安装、build/test、设备、Git 写入、远端写入或会话分派；无共享资料/state修改。全部请求成功，无 TLS 首次失败或重试。固定源码无变化且现有缺口判断未改变，无新增 BDD 或可行采用项。经验检查完成，无新增模式，沿用现有取证安全和 partial 检查点规则。
