# 2026-11-01 参考项目日检

固定实际 main `4b4b6a841446243c3fb76af800483cda65bbc738`；33仓 24 完整 / 9 partial，2 仓相对10月31日变化，0 仓未知。HEAD、完整非draft Release分页与固定SHA许可分别重新查询。

## 增量判断

- [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/b2509022e965dd2dc1060f58c8a9faa5cae068e4)：新增逐步活屏对compiled基线漂移与阈值层fail-closed；本地testrec已有候选页面匹配与阻塞，但local-device replay仍明确not-wired、不执行动作，不能称逐步活屏已覆盖，也无当前真实回放误报通过的同源缺口。iPhone Mirroring卡片/外部skills阈值不直接映射本机Simulator入口，保留观察。 [审阅](20261101-jfarcand-mirroir-mcp-review.md)。
- [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/13462d32e2ff87ee7ee1feff418fdcb7e18c2f57)：4提交/24路径、19允许文本与43固定blob完成。新增云报告action/video timeline下载与ffmpeg切片依赖上游已对齐的首帧offset；main本机recording/testrec未提供该同步来源，不能把墙钟伪装视频时间或引入云报告依赖。其余org-runtime身份、iframe登录及computer admission文档属托管边界，无本轮直接采用。 [审阅](20261101-RevylAI-revyl-cli-review.md)。

## 采用及证据

17项采用均为local_merged，实际合并SHA全部为main祖先；12个真实执行/批次聊天登记已归档，长期主控保持开放。本轮不重开已交付项；无新采用缺口则不创建实现空间。

昨日SP207的884份和SP253的84份manifest条目逐一验证可用且hash一致；10月30日716份raw缺失仍是已知历史缺口，未声称恢复。本日证据保存仓外archives并生成新manifest。

9个旧许可/来源缺口保留；只有本次完整仓推进成功点，iCTRL继续使用SP193独立状态。未运行上游代码、设备、安装依赖、签名/DDI、push/tag/release；仅资料变化，产品测试不适用。经验回写现有采用流程：review必须绑定仓库/base/head/main，跨状态发布保留before/after恢复记录；历史缺口只按明确恢复证据退休。

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `94b78d3603ac` | v0.2.12 | partial |
| EvanBacon/serve-sim | `ede4c21ee302` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `ff1351242e6d` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `b2509022e965` | v0.42.0 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `13462d32e2ff` | v0.1.204 | partial |
| RevylAI/app-explorer | `b3edc443dbfb` | — | partial |
| RevylAI/greenlight | `fcb36e395bd4` | v0.2.0 | 完整 |
| RevylAI/mobile-devtools | `efc1dae5da08` | — | partial |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56` | — | partial |
| RevylAI/visual-regression | `2758e8a88f4e` | — | partial |
| RevylAI/figma-design-checker | `8b4e5cea045d` | — | partial |
| RevylAI/CogniSim | `3d8902e01198` | — | 完整 |
| hughkli/Lookin | `95e30fdcc815` | 1.0.7 | 完整 |
| OSU-NLP-Group/UGround | `8974f95b0685` | — | 完整 |
| bytedance/UI-TARS | `582f3a7ea5d2` | — | 完整 |
| OpenBMB/AgentCPM-GUI | `2168ae21b1be` | — | 完整 |
| X-PLUG/MobileAgent | `81fa28b564ef` | — | 完整 |
| njucckevin/SeeClick | `0ef37ac4d7aa` | — | 完整 |
| google-research/android_world | `55ddaf5edc6f` | — | 完整 |
| mobile-dev-inc/Maestro | `5ca5313b4c65` | cli-2.12.0 | 完整 |
| linhay/SKProcessRunner | `24e036604b9e` | 0.0.17 | partial |
| mobile-next/mobile-mcp | `1025dd070fc9` | 1.0.15 | 完整 |

## 收口验证

`verify.sh --ci-docs`、独立`check-docs.sh`（253 spaces）、`git diff --check`均通过；428份证据size/hash全匹配，9 partial检查点逐项保持，iCTRL未复制至SP207，17个采用merge均为main祖先。恢复入口在全部state已经after时实跑幂等通过；未模拟真实进程崩溃。日志在仓外`archives/reference-monitor/20261101-validation/`。

汇总器在发布前经独立只读审查：现强校验review来源四元组，先保存before/after publication与manifest再原子写各状态；未知状态恢复拒绝。本次采集器未遇来源恢复，后续复用须排除无条件历史error继承，不能让旧partial永久锁死。原规则已在正式采用流程补充，无新增skill或重复经验文件。

本轮没有需要用户处理的新采用、故障或交付变化；两仓静态增量保留观察，按通知规则静默。
