# 2026-10-24 Simulator / runtime 参考日检

实际产品主线 `24e7d0f21017c8ca7104b6f8e3912fc2c44be892`。10仓官方查询完成，7完整/3旧partial，2仓HEAD变化；最新非draft Release（含prerelease）、固定HEAD许可全文hash均未变。成功点/import与20261023观察独立比较，未推进任何共享检查点。既有追踪WIP保留。

| 仓库 | 固定HEAD | Release | 覆盖 | 判断 |
| --- | --- | --- | --- | --- |
| tddworks/baguette | [458044cc](https://github.com/tddworks/baguette/commit/458044cceadd25a1366619b3747311ad7d959f94) | [v0.2.10](https://github.com/tddworks/baguette/releases/tag/v0.2.10) | partial | v0.2.10 Duo/3D stage属于上游UI；无当前本机CLI缺口证据，二进制来源与增量审阅仍partial。 |
| EvanBacon/serve-sim | [0193e65c](https://github.com/EvanBacon/serve-sim/commit/0193e65c481fc9b64a62427f32fcf143dbc3d2c0) | 无非draft Release | 完整 | 新增原生CFR录制、限时/持有/流式落盘及React Native Metro reload/浏览器held-key恢复；Triton现有sim record为simctl外部录制，已做样本时长与Resizable目标绑定，无同一自有编码队列或浏览器键盘/Metro入口；无实际缺口，不引入Web写控制面。 |
| lycorp-jp/sim-use | [c02295ed](https://github.com/lycorp-jp/sim-use/commit/c02295edfd2f442249b869096dda3dc7bfcd308d) | [v0.16.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0) | partial | v0.16.0保护notarized Homebrew签名；Triton无该签名前提及post_install覆盖，未证实同类缺陷；SP-214/219已交付，不重复排期。 |
| MobAI-App/simslim | [6518ba7e](https://github.com/MobAI-App/simslim/commit/6518ba7eab1123d7e1d7797b0e05f51043b42a5b) | [v0.12.2](https://github.com/MobAI-App/simslim/releases/tag/v0.12.2) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| Mastersam07/OpenDeviceHub | [e50f07f1](https://github.com/Mastersam07/OpenDeviceHub/commit/e50f07f1f4480cb14d57f192df7bf598ca26e708) | [v0.2.0](https://github.com/Mastersam07/OpenDeviceHub/releases/tag/v0.2.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| JaviSoto/device-hub-ios | [3779e12a](https://github.com/JaviSoto/device-hub-ios/commit/3779e12aa00c08bb34805fef8ffe375838cbe815) | 无非draft Release | partial | Rust DeviceHubFFI重构与CI前置条件不对应Triton当前入口；省略历史patch保持partial。 |
| heoblitz/Loupe | [ff135124](https://github.com/heoblitz/Loupe/commit/ff1351242e6dbaba4a0b4de40d10350a668f03b8) | [v0.5.1](https://github.com/heoblitz/Loupe/releases/tag/v0.5.1) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| jfarcand/mirroir-mcp | [502c5e46](https://github.com/jfarcand/mirroir-mcp/commit/502c5e466da4d82df8f65ffa9a598c01e152b56b) | [v0.40.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.40.1) | 完整 | 新增游戏技能/AI agent路由、OCR优先轮询、settle/blank双重确认、截图crop/scale与token统计。当前Triton VLM为显式artifact grounding且已有坐标契约/远端opt-in；不自动运行视觉探索，不能用近均匀帧静默抑制用户明确请求。观察性能机制，无本地失败或现有需求证据。 |
| RockxyApp/Rockxy | [de791b63](https://github.com/RockxyApp/Rockxy/commit/de791b63e7f9b5df49f127524a5c9320e675eb23) | [v0.41.0](https://github.com/RockxyApp/Rockxy/releases/tag/v0.41.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |
| ProxymanApp/atlantis | [cc059013](https://github.com/ProxymanApp/atlantis/commit/cc059013de8778072b4fea6453b45e964e4202fe) | [2.0.0](https://github.com/ProxymanApp/atlantis/releases/tag/2.0.0) | 完整 | HEAD/Release/许可hash与上次一致，复用已保存固定源码评估，无新增采用项。 |

## 新增源码与采用判断

serve-sim [3提交完整增量](https://github.com/EvanBacon/serve-sim/compare/a30d70a55e05654d974c86803b68d4f675be77e3...0193e65c481fc9b64a62427f32fcf143dbc3d2c0)共36文件，全部固定HEAD文本已保存。原生录制使用捕获单调时钟、CFR补帧、12帧pending上限、编码等待250ms、30分钟录制上限、5分钟持有和流式落盘清理。尺寸变化时丢弃新尺寸帧并重复旧帧是其明确限制，不能据此承诺动态尺寸录制。Triton目前以simctl录制且验证视频样本时长，Resizable为会话前显示身份绑定，未拥有同类CFR编码队列；缺少同类缺陷证据，不移植新编码器。Metro针对bundle/device/name消歧、confirmed=false与浏览器Cmd+R键恢复针对RN浏览器控制面，当前Triton无此入口，保持观察。

mirroir-mcp [完整提交](https://github.com/jfarcand/mirroir-mcp/commit/502c5e466da4d82df8f65ffa9a598c01e152b56b)共92文件，固定HEAD文本全部保存。游戏kind/playable元数据、Anthropic模型/effort/超时、embedded/http agent routing、prompt覆盖与工作流规则属于上游产品/配置，不执行其中脚本或指令。OCR用于启动/前景/轮询，视觉请求仅在客户端明确需要时调用；blank判定联合近均匀像素与同帧本地OCR，解码失败不等于空帧；截图region按window-point到pixel变换再scale。当前main的alias freshness、budget、settle、OCR已有SP-192底座；CLIVLMRuntime使用显式输入artifact、坐标契约与远端opt-in，没有该自动探索/按次付费描述循环，不能据此静默省略用户ground请求。性能数据未本地实测；暂无新增BDD候选，父主控可复核该适用性判断。

## 本地主线与真实验收证据

本轮保存`main-coverage.json`的真实main blob/hash，并复核SP-192/196/200/214/219已有机制。昨日之后新增`c0ce0cc2`纠正devicectl displays真实响应、精确匹配命令目标/参数、active primary integrated拓扑；新增resource replay在runtime I/O前拒绝及录制契约同步。`e2b1d959`/`24e7d0f2`为v0.2.33发布准备/验收，不重复规划已交付项。

[SP-218真实验收](../../SP-218-issue-222-device-hub-input/plans/20261024-live-acceptance-closeout.md)已证明Xcode27.1/iOS27.0专用Simulator上Release Demo build/install/launch、普通host-HID tap/swipe业务后置、Hub占用拒绝/退出恢复、候选fresh displays screenshot通过。[SP-219真实录制](../../SP-219-simulator-resizable-routing/plans/20261024-live-recording-validation.md)已证明普通/Resize/恢复三段可解码且有实际样本时长；5秒录制截短正确拒绝。以上是已有交付证据，本次未重跑。Resize AX/HID仍unsupported；unknown/伪造/跨目标display为离线覆盖，不宣称真实注入；其他Xcode/OS、全面AX、多击/长按、用户项目仍未验收。

## 完整性与安全边界

每仓保存官方repository/default-branch HEAD、全部Release分页、固定HEAD license API与全文/hash。Release按published_at取最新非draft，含prerelease；无资产下载。NOASSERTION仍为API原值，不能抹掉固定许可全文识别。新变更只读取经语义用途和文本白名单审核的source/test/docs/config/prompt/workflow文本，共128份；第三方脚本只作文本，不执行。未请求二进制、无扩展名helper、identity/密钥/证书材料；旧Baguette来源缺口保持partial。sim-use CHANGELOG省略patch与device-hub-ios protocol.rs省略patch未恢复，不用无变化冒充恢复。

本轮无TLS/连接失败，无需重试；无build/test/device/第三方执行、安装、Git操作、远端写入或会话分派。经验检查完成，无新治理经验；继续遵守现有取证安全与检查点完整性规则。
