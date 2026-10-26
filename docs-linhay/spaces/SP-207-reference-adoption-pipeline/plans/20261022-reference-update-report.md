# 2026-10-22 全部参考项目更新与采用报告

实际工作区为原 TritonKit 目录，`main@409670ef1435aec5950f7e1b30fea8e0b2ecc705`；官方只读查询33仓，**22完整、11 partial**。相对昨日4仓变化，3个新Release；11个partial均保留原成功点，iCTRL独立成功点在摘要保存后推进至本日。

## 新变化与裁决

- [Baguette v0.2.10](https://github.com/tddworks/baguette/releases/tag/v0.2.10)，HEAD `458044cceadd`：Duo fold/input/panel gesture、3D stage焦点和domain文档。上游界面/私有HingeControl不是当前Triton的实现面；二进制来源及全量增量未闭合，observe/partial。
- [sim-use v0.16.0](https://github.com/lycorp-jp/sim-use/releases/tag/v0.16.0)，HEAD `c02295edfd2f`：Homebrew安装保留已公证签名，不再post_install做ad-hoc codesign，并验证安装字节/身份/notary。Triton公式无post_install/codesign，release无Developer ID/notary前提；未发现同类缺陷，observe。通用安装后字节核验留作观察，未建立开发切片。SP-214安全拓扑与SP-219录制display路由已交付；AX/HID和真实运行仍未验收。省略历史CHANGELOG patch及语义审阅限制继续partial。
- [device-hub-ios `3779e12a`](https://github.com/JaviSoto/device-hub-ios/commit/3779e12aa00c08bb34805fef8ffe375838cbe815)：Rust模块重构和CI prerequisites fail-fast；不对应Triton入口，observe。历史protocol patch省略未完整审完，首次转partial，原成功点不变。
- [Revyl CLI v0.1.182](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.182)，HEAD `66086f78f2fe`：托管会话owner/多会话stop、错误surface、遥测和timeout报告；相对旧成功点21提交/267路径，commit文件分页完整，重点18个固定源码/测试已读。缺许可及generated/hosted/pyc全量语义审阅未闭合，defer/partial，不扩大云产品面。
- [iCTRL v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)，HEAD `874f528759b1`与许可hash不变，SP-193独立成功。研究组10仓无新增变化，SKProcessRunner许可404不视为恢复。

## 本地采用与验收边界

对照SP-192五项机制（身份新鲜度、采集预算、视觉稳定、OCR candidateOnly、健康/熔断unknown）、SP-196/200、SP-203～205及SP-210/212/214～220实际交付。采用登记13条均已有主线祖先证据；本轮无待推进实现、无新采用项，不新建space/branch/thread，也不为探测模型创建会话。桌面create_thread的历史模型失败不重新标记为已完成项阻塞。

签名安装、真实Simulator/HDC/设备、跨进程竞态、双架构构建与发布均未执行；未运行第三方代码或安装依赖。上游性能/测试声明未经本地验证。没有新增产品diff，故不执行产品测试；本轮运行docs-only三门禁，结果见当日memory。

## 许可纠正与取证复盘

SP-219原“MIT”记录不实：其固定源42aa9a2与当前c02295ed的LICENSE全文hash同为`8c0fe2892344358b49aa07d9a184bd8d0891832baf642f19161f271acc075d32`，全文Apache-2.0（API NOASSERTION）。更正SP-219原权威文档，保留上游API分类及人工识别，不把它称为上游许可变更。未复制上游代码。

本轮取证过滤遗漏曾读取Baguette二进制与identity目录内容；发现后终止相关读取，移除3份JSON的content并只留脱敏元数据，原脚本已禁用，未打印或执行内容。主控复核匹配路径无content残留。改进写入正式流程：请求前按路径用途/文本白名单排除二进制、密钥/证书/身份材料；扩展名黑名单不充分。该处理不恢复源码审阅完整性。

## 逐仓结果

|仓库|HEAD|Release|相对昨日变化|完整性|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `458044cceadd` | v0.2.10 | 有 | partial | observe |
| `EvanBacon/serve-sim` | `a30d70a55e05` | — | 无 | 完整 | observe |
| `lycorp-jp/sim-use` | `c02295edfd2f` | v0.16.0 | 有 | partial | observe |
| `MobAI-App/simslim` | `6518ba7eab11` | v0.12.2 | 无 | 完整 | observe |
| `Mastersam07/OpenDeviceHub` | `e50f07f1f448` | v0.2.0 | 无 | 完整 | observe |
| `JaviSoto/device-hub-ios` | `3779e12aa00c` | — | 有 | partial | observe |
| `heoblitz/Loupe` | `ff1351242e6d` | v0.5.1 | 无 | 完整 | observe |
| `jfarcand/mirroir-mcp` | `845a981163aa` | v0.40.1 | 无 | 完整 | observe |
| `RockxyApp/Rockxy` | `de791b63e7f9` | v0.41.0 | 无 | 完整 | observe |
| `ProxymanApp/atlantis` | `cc059013de87` | 2.0.0 | 无 | 完整 | observe |
| `OpenMinis/iCTRL` | `874f528759b1` | v1.98.12 | 无 | 完整 | already_covered |
| `getsentry/MobileBuildMCP` | `d13ff0c707b0` | v2.7.1 | 无 | 完整 | no_new_adoption |
| `awizemann/harness` | `3f58c077ded1` | v0.8.4 | 无 | 完整 | no_new_adoption |
| `dongxinsuperman/ai-phone` | `d339057bc64a` | v0.8.0 | 无 | 完整 | no_new_adoption |
| `karminski/eyes-on-my-phone` | `eef71926e613` | — | 无 | partial | no_new_adoption |
| `RevylAI/revyl-cli` | `66086f78f2fe` | v0.1.182 | 有 | partial | defer |
| `RevylAI/app-explorer` | `b3edc443dbfb` | — | 无 | partial | no_new_adoption |
| `RevylAI/greenlight` | `fcb36e395bd4` | v0.2.0 | 无 | 完整 | no_new_adoption |
| `RevylAI/mobile-devtools` | `efc1dae5da08` | — | 无 | partial | no_new_adoption |
| `RevylAI/mobile-pr-reviewer` | `ba1250c72f56` | — | 无 | partial | no_new_adoption |
| `RevylAI/visual-regression` | `2758e8a88f4e` | — | 无 | partial | no_new_adoption |
| `RevylAI/figma-design-checker` | `8b4e5cea045d` | — | 无 | partial | no_new_adoption |
| `RevylAI/CogniSim` | `3d8902e01198` | — | 无 | 完整 | no_new_adoption |
| `hughkli/Lookin` | `95e30fdcc815` | 1.0.7 | 无 | 完整 | observe |
| `OSU-NLP-Group/UGround` | `8974f95b0685` | — | 无 | 完整 | observe |
| `bytedance/UI-TARS` | `582f3a7ea5d2` | — | 无 | 完整 | observe |
| `OpenBMB/AgentCPM-GUI` | `2168ae21b1be` | — | 无 | 完整 | observe |
| `X-PLUG/MobileAgent` | `11cea575561f` | — | 无 | 完整 | observe |
| `njucckevin/SeeClick` | `0ef37ac4d7aa` | — | 无 | 完整 | observe |
| `google-research/android_world` | `f8e78c0ab0bb` | — | 无 | 完整 | observe |
| `mobile-dev-inc/Maestro` | `028c18b9ce74` | cli-2.11.0 | 无 | 完整 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 0.0.17 | 无 | partial | observe |
| `mobile-next/mobile-mcp` | `c659f8ee3487` | 1.0.12 | 无 | 完整 | observe |

逐仓失败/覆盖/完整Release正文与许可hash见[观察记录](./20261022-observations.json)；详见[Simulator/runtime](./20261022-sim-runtime.md)、[agents/Revyl](./20261022-agents-revyl.md)、[研究组](./20261022-research.md)。原始只读证据保留在`.build/reference-monitor/20261022/`，摘要先保存，再原子推进完整仓检查点。

经验复盘命中既有参考采用流程；已纠正原许可证事实并补充取证过滤规则，不新增重复经验文档。当前跟踪文档未提交、未推送、未发版。
