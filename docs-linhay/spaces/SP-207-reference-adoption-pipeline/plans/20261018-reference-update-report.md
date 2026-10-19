# 2026-10-18 参考项目更新、采用与分派报告

## 结论与阶段

33 个登记仓库均发起官方默认分支 HEAD、最新非 draft Release（含 prerelease）和许可证查询。由于 agent/Revyl 分组的 GitHub API 返回 403，14 个仓库本轮完整性不足；本轮可完整收口 19 个、partial 14 个，观察到 HEAD/Release 变化 5 个。完整结果和分组报告已保存后，只有 complete 仓库推进各自检查点；partial 仓库保留旧点，不报告无变化。iCTRL 仍由 SP-193 独立管理。

本轮不产生新的 adopt。已登记的 SP-210/SP-211 仍等待显式 `gpt-6.1-sol` 会话创建；重复创建尝试再次被桌面接口以模型校验拒绝，没有伪造 thread，也没有改用其他模型，证据见 [分派记录](20261018-dispatch.json)。没有运行上游代码、安装依赖、设备/签名/DDI、push、tag 或 release。

## 有价值变化与采用边界

- [serve-sim 三个提交](https://github.com/EvanBacon/serve-sim/compare/c47a468b600362d14960504bfb4f222101ead634...a30d70a55e05654d974c86803b68d4f675be77e3)继续观察：上游增加 Duo pose 按钮收敛、H.264 最大码率配置、像素消费者触发私有帧复制和 snapshot 编码隔离，并扩展相关测试/文档。TritonKit 当前没有同等 Duo Web 控制面；采集预算/快照隔离可作为未来本地 host capture 评估输入，不能直接复制上游 UI 或把上游性能声明当本地验证。
- [Atlantis 2.0.0](https://github.com/ProxymanApp/atlantis/releases/tag/2.0.0)仍为 iOS 26/27 API 兼容性声明，HEAD 未变；保持观察，不能替代 TritonKit 本机兼容性证据。
- [Baguette v0.2.7](https://github.com/tddworks/baguette/releases/tag/v0.2.7)仍因固定 APK 与构建源码/manifest provenance 未闭合而 partial；不推进检查点，不运行二进制。
- [ai-phone](https://github.com/dongxinsuperman/ai-phone/commits/main) 与 [revyl-cli](https://github.com/RevylAI/revyl-cli/commits/main) 的 HEAD 变化无法完成 Release 分页和完整增量读取（GitHub API 403），保留 observe 和旧检查点；不是无变化。
- [SKProcessRunner](https://github.com/linhay/SKProcessRunner) HEAD/Release 未变，但许可端点 404 且固定树没有 LICENSE/COPYING/NOTICE。本轮修正此前过强的“完整”标签，保留 SHA/tag 历史点但不再把它作为当前完整检查点，也不采用其代码。
- iCTRL [SP-193](https://github.com/OpenMinis/iCTRL) 本轮仍为 `main@d88bbf0`、`v1.98.12`、Apache-2.0，全文许可 hash 不变；不重复通知、不新建采用项。

所有上游性能、测试数量和兼容性数字，若未在 TritonKit 本地验证，均只作为上游自述。评估绑定真实 main `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`，并核对 SP-192/196/200 与 SP-203–211；本轮无产品代码变更。

## 逐仓库观察

| 仓库 | HEAD（短） | 变化 | 完整 | 最新非 draft Release | 裁决 |
| --- | --- | --- | --- | --- | --- |
| tddworks/baguette | `14b39834fef6` | 是 | partial | v0.2.7 | observe |
| EvanBacon/serve-sim | `a30d70a55e05` | 是 | 是 | 未知 | observe |
| lycorp-jp/sim-use | `81c3089331aa` | 否 | 是 | v0.15.0 | observe |
| MobAI-App/simslim | `6518ba7eab11` | 否 | 是 | v0.12.2 | observe |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | 否 | 是 | v0.2.0 | observe |
| JaviSoto/device-hub-ios | `b5994ff72d8c` | 否 | 是 | 未知 | observe |
| heoblitz/Loupe | `ff1351242e6d` | 否 | 是 | v0.5.1 | observe |
| jfarcand/mirroir-mcp | `845a981163aa` | 否 | 是 | v0.40.1 | observe |
| RockxyApp/Rockxy | `de791b63e7f9` | 否 | 是 | v0.41.0 | observe |
| ProxymanApp/atlantis | `cc059013de87` | 是 | 是 | 2.0.0 | observe |
| OpenMinis/iCTRL | `d88bbf0b3a5a` | 否 | 是 | v1.98.12 | observe |
| getsentry/MobileBuildMCP | `d13ff0c707b0` | 否 | partial | 未知 | covered |
| awizemann/harness | `3f58c077ded1` | 否 | partial | 未知 | covered |
| dongxinsuperman/ai-phone | `4cac05b50b6a` | 是 | partial | 未知 | observe |
| karminski/eyes-on-my-phone | `eef71926e613` | 否 | partial | 未知 | covered |
| RevylAI/revyl-cli | `787d90e77113` | 是 | partial | 未知 | observe |
| RevylAI/app-explorer | `b3edc443dbfb` | 否 | partial | 未知 | reject |
| RevylAI/greenlight | `fcb36e395bd4` | 否 | partial | 未知 | reject |
| RevylAI/mobile-devtools | `efc1dae5da08` | 否 | partial | 未知 | reject |
| RevylAI/mobile-pr-reviewer | `ba1250c72f56` | 否 | partial | 未知 | reject |
| RevylAI/visual-regression | `2758e8a88f4e` | 否 | partial | 未知 | reject |
| RevylAI/figma-design-checker | `8b4e5cea045d` | 否 | partial | 未知 | reject |
| RevylAI/CogniSim | `3d8902e01198` | 否 | partial | 未知 | reject |
| hughkli/Lookin | `95e30fdcc815` | 否 | 是 | 1.0.7 | observe |
| OSU-NLP-Group/UGround | `8974f95b0685` | 否 | 是 | 未知 | observe |
| bytedance/UI-TARS | `582f3a7ea5d2` | 否 | 是 | 未知 | observe |
| OpenBMB/AgentCPM-GUI | `2168ae21b1be` | 否 | 是 | 未知 | observe |
| X-PLUG/MobileAgent | `11cea575561f` | 否 | 是 | 未知 | observe |
| njucckevin/SeeClick | `0ef37ac4d7aa` | 否 | 是 | 未知 | observe |
| google-research/android_world | `30583e22b9fb` | 否 | 是 | 未知 | reject |
| mobile-dev-inc/Maestro | `028c18b9ce74` | 否 | 是 | cli-2.11.0 | covered |
| linhay/SKProcessRunner | `24e036604b9e` | 否 | partial | 0.0.17 | reject |
| mobile-next/mobile-mcp | `d4a83fa45b9c` | 否 | 是 | 1.0.11 | observe |

## 不完整项与恢复条件

- `tddworks/baguette`：固定 APK 的关联构建源码/manifest provenance 仍未建立；保持旧点。
- agent/Revyl 组 12 仓：GitHub API 403 使 Release 分页及完整增量/相关源码审阅未闭合；保持旧点，待 API 恢复或获得完整官方响应后补读。
- `linhay/SKProcessRunner`：许可证状态未清；历史检查点标签已在本轮更正为待复核，不把许可缺失误标为成功。

## 证据与验证

机器观察见 [20261018-observations.json](20261018-observations.json)，分组报告见 [20261018-sim-runtime.md](20261018-sim-runtime.md)、[20261018-agents-revyl.md](20261018-agents-revyl.md)、[20261018-research.md](20261018-research.md)，iCTRL 专项见 [SP-193 检查摘要](../../SP-193-ictrl-reference-tracking/plans/20261018-check-summary.json)，分派重试见 [20261018-dispatch.json](20261018-dispatch.json)。原始 API、Release、许可证全文和源码证据在 `.build/reference-monitor/20261018/`，不会作为上游运行或设备验收声明。

本轮仅修改追踪资料与检查点；产品测试不适用。收口前运行 docs-only 门禁并记录实际结果。
