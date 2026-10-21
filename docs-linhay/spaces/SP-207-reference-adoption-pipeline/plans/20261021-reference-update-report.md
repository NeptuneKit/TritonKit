# 2026-10-21 参考项目更新与采用报告

本轮对 33 个登记仓库完成默认分支 HEAD、全部非 draft Release 分页、固定 HEAD LICENSE 查询；**23 完整、10 partial**。相对昨日观察有 4 个新变化：`tddworks/baguette`, `lycorp-jp/sim-use`, `JaviSoto/device-hub-ios`, `RevylAI/revyl-cli`。

评估基线为扫描时实际主线 `e405af0c`；扫描后 SP-219 候选已由当前主控本地合并为 `f9399e5e`。SP-214～SP-218 已在主线有真实实现与离线验收证据，本轮不重复排期。

## 新变化与评估

- **sim-use `42aa9a2`**（[compare](https://github.com/lycorp-jp/sim-use/compare/dc58fe8ea2353cde5cb15944eaee16105ad27b4d...42aa9a244f4e20fdd97ef8dd738fd34bb91cf671)，最新非 draft Release 仍 `v0.15.0`）：新增/完善 Xcode 27 Resize Mode 的 `Resizable` display 发现、前台 app 显示路由、截图/AX/HID/视频边界和 fail-closed advisory。当前 TritonKit 已能查询 appResize，并为 screenshot 选择 display，但触摸、AX 激活和视频仍安全拒绝；这是本机 iOS Simulator 范围内可拆分的采用候选。上游测试/时延数字仅上游自述，未本地验证。
- **device-hub-ios `7cb1104`**（[commit](https://github.com/JaviSoto/device-hub-ios/commit/7cb1104775d9a1e63bb3fe2c0be6d8afbad095f9)）：Duo folded remote controls、触摸账本和快照/契约测试；属于 UIKit Device Hub UI，超出 TritonKit 当前 CLI/HTTP/Wails 桌面壳边界，observe。
- **Baguette `v0.2.9`**（[Release](https://github.com/tddworks/baguette/releases/tag/v0.2.9)）：custom device set 传播和 3D stream 资源释放；TritonKit 当前没有 Baguette custom-set 参数或同一 3D stream，observe。APK/二进制变更无法由 GitHub contents 得到完整关联源码，保持 partial。
- **Revyl CLI `v0.1.179`**（[Release](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.179)）：托管构建/branch identity 与 workflow 同步，产品托管控制面不纳入；固定 HEAD 无 LICENSE，部分 commit patch 仍不完整，partial/observe。
- **iCTRL**：HEAD `874f528`、Release `v1.98.12`、Apache-2.0 固定许可证均无变化；SP-193 单独检查通过，无新增采用。

## 采用安排

- SP-219 `simulator-resizable-display-routing` 已完成：目标仅覆盖本机 iOS Simulator 的 Resize Mode，通过 fresh display identity 将录制路由到 `Resizable`，未知时继续 fail-closed；AX/触摸仍不扩大到未经验证的 transport。候选 `51cd20dd` 经 SP-220 主控审查后本地合并为 `f9399e5e`，不引入真机、远端、设备云或 Duo 全量控制。创建执行/主控会话时显式使用 `model="gpt-6.1-sol"`；桌面接口持续拒绝时保留真实失败记录，不回退模型。

## 完整性与失败

- Baguette 的 APK/证书等二进制关联源码、eyes-on-my-phone 与 Revyl 系列仓库许可证正文缺失；Revyl 增量仍有部分 commit patch 不可得；sim-use 有大文件/merge commit patch 省略。所有 partial 均不推进 checkpoint，旧成功点保留。
- 扫描阶段未运行第三方代码、未安装依赖、未操作设备、未签名/DDI、未推送/发布；扫描后仅执行本地候选合并与 CLI 测试，未进行远端写入。

## 逐仓结果

|仓库|HEAD|相对昨日|完整性|Release|裁决|
|---|---|---|---|---|---|
| `tddworks/baguette` | `70ea82c395d2` | 是 | partial | v0.2.9 | observe |
| `EvanBacon/serve-sim` | `a30d70a55e05` | 否 | 完整 | — | observe |
| `lycorp-jp/sim-use` | `42aa9a244f4e` | 是 | partial | v0.15.0 | adopt |
| `MobAI-App/simslim` | `6518ba7eab11` | 否 | 完整 | v0.12.2 | observe |
| `Mastersam07/OpenDeviceHub` | `e50f07f1f448` | 否 | 完整 | v0.2.0 | observe |
| `JaviSoto/device-hub-ios` | `7cb1104775d9` | 是 | 完整 | — | observe |
| `heoblitz/Loupe` | `ff1351242e6d` | 否 | 完整 | v0.5.1 | observe |
| `jfarcand/mirroir-mcp` | `845a981163aa` | 否 | 完整 | v0.40.1 | observe |
| `RockxyApp/Rockxy` | `de791b63e7f9` | 否 | 完整 | v0.41.0 | observe |
| `ProxymanApp/atlantis` | `cc059013de87` | 否 | 完整 | 2.0.0 | observe |
| `OpenMinis/iCTRL` | `874f528759b1` | 否 | 完整 | v1.98.12 | observe |
| `getsentry/MobileBuildMCP` | `d13ff0c707b0` | 否 | 完整 | v2.7.1 | observe |
| `awizemann/harness` | `3f58c077ded1` | 否 | 完整 | v0.8.4 | observe |
| `dongxinsuperman/ai-phone` | `d339057bc64a` | 否 | 完整 | v0.8.0 | observe |
| `karminski/eyes-on-my-phone` | `eef71926e613` | 否 | partial | — | observe |
| `RevylAI/revyl-cli` | `5db4b2cc1aac` | 是 | partial | v0.1.179 | observe |
| `RevylAI/app-explorer` | `b3edc443dbfb` | 否 | partial | — | observe |
| `RevylAI/greenlight` | `fcb36e395bd4` | 否 | 完整 | v0.2.0 | observe |
| `RevylAI/mobile-devtools` | `efc1dae5da08` | 否 | partial | — | observe |
| `RevylAI/mobile-pr-reviewer` | `ba1250c72f56` | 否 | partial | — | observe |
| `RevylAI/visual-regression` | `2758e8a88f4e` | 否 | partial | — | observe |
| `RevylAI/figma-design-checker` | `8b4e5cea045d` | 否 | partial | — | observe |
| `RevylAI/CogniSim` | `3d8902e01198` | 否 | 完整 | — | observe |
| `hughkli/Lookin` | `95e30fdcc815` | 否 | 完整 | 1.0.7 | observe |
| `OSU-NLP-Group/UGround` | `8974f95b0685` | 否 | 完整 | — | observe |
| `bytedance/UI-TARS` | `582f3a7ea5d2` | 否 | 完整 | — | observe |
| `OpenBMB/AgentCPM-GUI` | `2168ae21b1be` | 否 | 完整 | — | observe |
| `X-PLUG/MobileAgent` | `11cea575561f` | 否 | 完整 | — | observe |
| `njucckevin/SeeClick` | `0ef37ac4d7aa` | 否 | 完整 | — | observe |
| `google-research/android_world` | `f8e78c0ab0bb` | 否 | 完整 | — | observe |
| `mobile-dev-inc/Maestro` | `028c18b9ce74` | 否 | 完整 | cli-2.11.0 | observe |
| `linhay/SKProcessRunner` | `24e036604b9e` | 否 | partial | 0.0.17 | observe |
| `mobile-next/mobile-mcp` | `c659f8ee3487` | 否 | 完整 | 1.0.12 | observe |

证据：`docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261021-observations.json`；逐仓原始 API、Release、许可证、compare、固定 HEAD source 位于 `.build/reference-monitor/20261021/`。
