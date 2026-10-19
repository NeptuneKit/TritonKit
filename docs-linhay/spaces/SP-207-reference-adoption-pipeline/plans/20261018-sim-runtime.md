# 2026-10-18 simulator/runtime 上游检查

范围为 reference-state indices 0..9（不含 iCTRL），仅查询官方 GitHub API；未运行上游代码、安装、设备或产品测试。旧点按各仓库 checkpoint，tddworks/baguette checkpoint 缺失但存在昨日 partial，因此本轮不将其作为成功点。

| 仓库 | HEAD/Release变化 | 完整 | 提交数 | 最新Release | 裁决 |
|---|---|---|---:|---|---|
| EvanBacon/serve-sim | 是 | 是 | 3 | 无 | observe |
| JaviSoto/device-hub-ios | 否 | 是 | 0 | 无 | observe |
| Mastersam07/OpenDeviceHub | 否 | 是 | 0 | v0.2.0 | observe |
| MobAI-App/simslim | 否 | 是 | 0 | v0.12.2 | observe |
| ProxymanApp/atlantis | 是 | 是 | 0 | 2.0.0 | observe |
| RockxyApp/Rockxy | 否 | 是 | 0 | v0.41.0 | observe |
| heoblitz/Loupe | 否 | 是 | 0 | v0.5.1 | observe |
| jfarcand/mirroir-mcp | 否 | 是 | 0 | v0.40.1 | observe |
| lycorp-jp/sim-use | 否 | 是 | 0 | v0.15.0 | observe |
| tddworks/baguette | 是 | 否 | 9 | v0.2.7 | observe |

## 评估

本轮没有发现可纳入 TritonKit 的新机制。EvanBacon/serve-sim 与 ProxymanApp/atlantis 的更新继续观察；其能力涉及上游自身 Web/RPC 或兼容性声明，不能替代 Triton 既有边界和本地证明。其余仓库无变化。tddworks/baguette 保持 partial：固定 APK 可读，但关联构建源码/manifest provenance 未建立，未作二进制行为断言。所有仓库 decision=observe；不推进共享 reference-state 检查点。

当前真实 main 基线按用户给定为 `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`，见 `main-source-check.json`。原始官方 API、许可证全文与 SHA、提交详情、变更文件源码均保存在各仓库子目录；许可证按固定 HEAD 读取。
