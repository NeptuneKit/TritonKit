# 2026-10-23 参考项目更新与采用报告

官方逐仓查询33仓：22完整、11 partial，其中0仓读取受阻；相对昨日确认3仓变化、0仓变化未知。实际主线与原目录均为`409670ef1435aec5950f7e1b30fea8e0b2ecc705`，保留10月22日已有18份跟踪文档改动。

## 变化与读取故障

iCTRL初次metadata因TLS未知签发机构失败，系统curl同样证书失败，网页读取连接失败；在其他组官方读取成功后仅做一次有界安全重试，完整恢复，HEAD874f528、v1.98.12和Apache-2.0/hash不变。初次错误独立保留，不把重试成功覆盖为“从未失败”。未关闭TLS校验或安装/修改证书。

Simulator/runtime10仓查询成功，7完整/3旧partial，相对昨日无变化。Baguette二进制来源、sim-use旧CHANGELOG patch、device-hub-ios旧protocol patch限制仍保留，未宣称恢复。agents/Revyl与研究组逐仓最终结果及失败/有界重试见分组报告，不将某组成功或失败外推到全部仓库。

Maestro [6468ea39](https://github.com/mobile-dev-inc/Maestro/commit/6468ea39a9930f3ceda2581470f6ea7af8dfe81e)新增1提交/7文件，修复持锁数据库handle生命周期与比较stream关闭；本地稳定目录/独立.lock fd及defer close已有对应安全边界，未发现同类缺陷，observe，详见[研究组报告](./20261023-research.md)。

MobileBuildMCP [2998ac77](https://github.com/getsentry/MobileBuildMCP/commit/2998ac77ebbca59544e88a27f34bfb830db9d924)的2提交/1workflow更新Go MCP publisher工具链，Triton Swift发布链没有同入口，不采用。Revyl CLI [v0.1.185](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.185) / HEAD [c61af5e0](https://github.com/RevylAI/revyl-cli/commit/c61af5e0d3cdf193c46524fac4d86bc0db9a9166)新增3提交/12路径：Go版本、源码版本0.1.186、analytics flush等待250ms→1s；当前Triton无同类云遥测出口。未把HEAD源码版本当作已发布tag；许可404和历史语义/pyc来源缺口继续partial。

## 本地采用、合并与边界

已核对SP-192五机制、SP-196/200与后续交付；13条既有采用记录均为local_merged，全部local merge SHA在main祖先链中。没有未合并实现候选，不新建space/branch/thread，不为探测模型创建会话。开发验证完成须继续合main的规则保持有效；失败查询不构成开发/验证完成。

无产品代码改动，未执行产品测试、设备、签名/DDI、安装依赖、第三方代码或push/tag/release；文档门禁结果见当日memory。许可与源码缺口沿用原边界，上游性能数字未经本地验证。

## 逐仓最终状态

|仓库|HEAD|Release|相对昨日|完整性|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `458044cceadd` | v0.2.10 | 无变化 | partial | observe |
| `EvanBacon/serve-sim` | `a30d70a55e05` | — | 无变化 | 完整 | observe |
| `lycorp-jp/sim-use` | `c02295edfd2f` | v0.16.0 | 无变化 | partial | observe |
| `MobAI-App/simslim` | `6518ba7eab11` | v0.12.2 | 无变化 | 完整 | observe |
| `Mastersam07/OpenDeviceHub` | `e50f07f1f448` | v0.2.0 | 无变化 | 完整 | observe |
| `JaviSoto/device-hub-ios` | `3779e12aa00c` | — | 无变化 | partial | observe |
| `heoblitz/Loupe` | `ff1351242e6d` | v0.5.1 | 无变化 | 完整 | observe |
| `jfarcand/mirroir-mcp` | `845a981163aa` | v0.40.1 | 无变化 | 完整 | observe |
| `RockxyApp/Rockxy` | `de791b63e7f9` | v0.41.0 | 无变化 | 完整 | observe |
| `ProxymanApp/atlantis` | `cc059013de87` | 2.0.0 | 无变化 | 完整 | observe |
| `OpenMinis/iCTRL` | `874f528759b1` | v1.98.12 | 无变化 | 完整 | observe |
| `getsentry/MobileBuildMCP` | `2998ac77ebbc` | v2.7.1 | 有变化 | 完整 | no_new_adoption |
| `awizemann/harness` | `3f58c077ded1` | v0.8.4 | 无变化 | 完整 | no_new_adoption |
| `dongxinsuperman/ai-phone` | `d339057bc64a` | v0.8.0 | 无变化 | 完整 | no_new_adoption |
| `karminski/eyes-on-my-phone` | `eef71926e613` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/revyl-cli` | `c61af5e0d3cd` | v0.1.185 | 有变化 | partial | defer |
| `RevylAI/app-explorer` | `b3edc443dbfb` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/greenlight` | `fcb36e395bd4` | v0.2.0 | 无变化 | 完整 | no_new_adoption |
| `RevylAI/mobile-devtools` | `efc1dae5da08` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/mobile-pr-reviewer` | `ba1250c72f56` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/visual-regression` | `2758e8a88f4e` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/figma-design-checker` | `8b4e5cea045d` | — | 无变化 | partial | no_new_adoption |
| `RevylAI/CogniSim` | `3d8902e01198` | — | 无变化 | 完整 | no_new_adoption |
| `hughkli/Lookin` | `95e30fdcc815` | 1.0.7 | 无变化 | 完整 | observe |
| `OSU-NLP-Group/UGround` | `8974f95b0685` | — | 无变化 | 完整 | observe |
| `bytedance/UI-TARS` | `582f3a7ea5d2` | — | 无变化 | 完整 | observe |
| `OpenBMB/AgentCPM-GUI` | `2168ae21b1be` | — | 无变化 | 完整 | observe |
| `X-PLUG/MobileAgent` | `11cea575561f` | — | 无变化 | 完整 | observe |
| `njucckevin/SeeClick` | `0ef37ac4d7aa` | — | 无变化 | 完整 | observe |
| `google-research/android_world` | `f8e78c0ab0bb` | — | 无变化 | 完整 | observe |
| `mobile-dev-inc/Maestro` | `6468ea39a993` | cli-2.11.0 | 有变化 | 完整 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 0.0.17 | 无变化 | partial | observe |
| `mobile-next/mobile-mcp` | `c659f8ee3487` | 1.0.12 | 无变化 | 完整 | observe |

证据：[观察记录](./20261023-observations.json)、[失败记录](./20261023-read-failures.json)、[Simulator/runtime](./20261023-sim-runtime.md)、[agents/Revyl](./20261023-agents-revyl.md)、[研究组](./20261023-research.md)。原始API响应保留`.build/reference-monitor/20261023/`。完整查询与摘要先保存，再按仓原子推进；未完成仓旧checkpoint逐对象保留。

经验回看复用既有独立检查点、故障去重、未知语义与有界恢复规则；证书故障原因未知，不将其固化为新配置规则。本轮跟踪文档未提交。
