# 2026-10-27 参考项目检查与采用评估

33仓官方metadata、默认分支HEAD、全部Release分页、固定HEAD许可查询完成：24完整 / 9 partial，6仓HEAD和Release变化，0仓变化未知。当前main `cfda992467fc1ed19ef0c577577c313d79314069`；9个已完成执行/主控聊天已归档，15条既有采用合并SHA再次确认是main祖先。

## 更新与判断

- [tddworks/baguette v0.2.11](https://github.com/tddworks/baguette/releases/tag/v0.2.11)：Software keyboard toggle is a concrete optional host-input gap, but upstream private legacy HID button 1008 is not validated under Triton isolated helper/ownership contract. Keep as bounded candidate; do not treat SP-218 tap/swipe or SP-219 recording as keyboard proof, and do not import Baguette binary. 详见[固定来源评估](20261027-tddworks-baguette-review.md)。
- [MobAI-App/simslim v0.13.0](https://github.com/MobAI-App/simslim/releases/tag/v0.13.0)：files-recents/searchd is a concrete gap in existing resource doctor catalog and search downside; disk-cleanup bundle preservation has no equivalent local traversal, observe. SP-221 bounded read retry is already delivered; do not re-dispatch. 详见[固定来源评估](20261027-MobAI-App-simslim-review.md)。
- [OpenMinis/iCTRL v1.98.16](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.16)：确认连续单指路径接口缺口，但现有HID只验证直线tap/swipe；多点拐角/停留及时间语义缺少Triton真实触点证明，本轮无设备动作授权，先观察/可行性与验证前置，不直接进入已可交付采用。 详见[固定来源评估](20261027-OpenMinis-iCTRL-review.md)。
- [RevylAI/revyl-cli v0.1.192](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.192)：今日9 commits/30路径的允许文本与生成schema增量已审阅，无可确认本机产品gap，不新增采用；4 pyc禁止获取且无法语义证明，许可证404与历史generated/hosted来源缺口保留，仓库不完整且不得推进checkpoint。 详见[固定来源评估](20261027-RevylAI-revyl-cli-review.md)。
- [mobile-dev-inc/Maestro cli-2.12.0](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.12.0)：2提交/4文件仅准备2.12.0发布、版本号及simulatorServer 24e44046→37010dc7指针。2.12.0 changelog汇总既有修复，不代表今日重复新增实现。Windows Android镜像冻结修复位于外部分发Simulator Server，本仓无实现内容；Triton为macOS本机CLI，SP-200镜像消费自有CLI/HTTP，无此依赖，不制造同类缺口。boot/host等待已有超时及SP-223 drain deadline；旧目录、ADB、AX等采用不重复派发。 详见[固定来源评估](20261027-mobile-dev-inc-Maestro-review.md)。
- [mobile-next/mobile-mcp 1.0.14](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.14)：2提交/8文件：install命令通过add-mcp检测全局MCP客户端并upsert配置；TTY交互选择，--yes或非TTY默认全部，懒加载ESM；新增依赖与node16模块配置及文档。SP-200明确排除标准MCP接入，Triton CLI采用Swift/ArgumentParser+Hummingbird而非MCP server，不存在此安装入口需求；不得为追平上游扩张到自动修改用户客户端配置。SP-212前台activity/shell字面量机制已在main，不重复采用。 详见[固定来源评估](20261027-mobile-next-mobile-mcp-review.md)。

## 完整性和交付边界

无网络错误不代表历史缺口恢复；9个旧partial许可/二进制来源/历史源码覆盖问题保持独立，未推进对应成功点。若当日新增缺口也按逐仓记录保留。上游性能与测试数字未经本地验证。只审阅官方文本，不执行上游、安装依赖、操作设备、签名/DDI或push/tag/release。iCTRL独立SP-193检查点，不复制到SP-207。

用户2026-10-27的主控全流程责任与会话关闭规则已经补入原自动任务ictrl，保持ACTIVE、北京时间10:00及原thread；保存后读取确认，不新增重叠任务。现有治理技能与取证规则继续适用，无新增产品经验不强造经验文件。

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `34097c50d1db` | v0.2.11 | partial |
| EvanBacon/serve-sim | `0193e65c481f` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `ff1351242e6d` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `502c5e466da4` | v0.40.1 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `6e66797f4a5c` | v0.1.192 | partial |
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
| X-PLUG/MobileAgent | `11cea575561f` | — | 完整 |
| njucckevin/SeeClick | `0ef37ac4d7aa` | — | 完整 |
| google-research/android_world | `55ddaf5edc6f` | — | 完整 |
| mobile-dev-inc/Maestro | `0df4cf3c8cad` | cli-2.12.0 | 完整 |
| linhay/SKProcessRunner | `24e036604b9e` | 0.0.17 | partial |
| mobile-next/mobile-mcp | `6c945971b6b1` | 1.0.14 | 完整 |
