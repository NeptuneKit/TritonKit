# 2026-10-31 参考日检与安全采用

以实际main `1139db7712d485c0927282a4415ac45765567332`核对33仓：24完整 / 9 partial，5仓相对10月30日有变化，0仓变化未知。主目录main比已获取origin/main落后2提交；只使用实际main固定blob，未fetch/pull或替换其他worktree。16条既有采用合并均为main祖先；新增SP252安全候选与SP253主控分阶段记录。

## 更新与判断

- [EvanBacon/serve-sim](https://github.com/EvanBacon/serve-sim/commit/ede4c21ee3021a36fbee1fec106b388a50a5ce4e)：上游修复伪造AVCaptureConnection的dealloc；Triton相机hook不创建或关联fake AVCaptureConnection，无同源释放路径。弱引用验证真实释放的测试模式可供未来连接图支持参考，当前不以进程期保留集合替换本地生命周期。 [固定增量审阅](20261031-EvanBacon-serve-sim-review.md)。
- [jfarcand/mirroir-mcp](https://github.com/jfarcand/mirroir-mcp/commit/485416f3641dfb83b2e2a894fc0bb288ff706a28)：上游强化compiled缓存回放与iPhone Mirroring/Universal Clipboard、Swift emitter→Rust runner链；Triton现有live解析/显式wait/版本拒绝契约无同构新缺陷，保留观察，不引入上游跨surface编译器。 [固定增量审阅](20261031-jfarcand-mirroir-mcp-review.md)。
- [RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/commit/34a9587752f06cdc41cfce7acd46d408c8f799e8)：8提交/43路径，38允许文本与84固定安全blob审阅。accepted/ready修正与本机显式readiness/unknown契约已有覆盖；云端test批量sync、1GiB Web打包/上传、模型与计费schema及dev-loop技能整理无新增可直接采用本机缺口。 [固定增量审阅](20261031-RevylAI-revyl-cli-review.md)。
- [mobile-dev-inc/Maestro](https://github.com/mobile-dev-inc/Maestro/commit/5ca5313b4c6516bb66ff2537cdeb8edc01d61228)：1提交/3文本路径修复YAML模板appId未求值即传入tap/openLink；Triton没有该flow appId与隐式settle路由，typed replay在命令预生成/实际请求中严格替换变量并拒绝缺失值，无同构新缺口。 [固定增量审阅](20261031-mobile-dev-inc-Maestro-review.md)。
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp/commit/1025dd070fc934986dec9ea25458b0ab03bc54c7)：主控复核后仅采用host detached日志独占创建安全候选：prepare→createFile→reopen竞态先红测证实，再原子0600+O_EXCL/O_NOFOLLOW/O_CLOEXEC并覆盖stderr失败释放stdout FD。clear-data列observe，新增破坏性reset范围、默认/多用户、精确目标/真机拒绝与机器确认契约须先设计，能力名空缺不当现有缺陷。 [固定增量审阅](20261031-mobile-next-mobile-mcp-review.md)。

## 采用与完整性边界

Mobile MCP的最终输出文件独占/原子策略提示本机detached日志预检后重开窗口，已完成[SP252](../../SP-252-detached-log-exclusive-create/README.md)两轮red/green后修复并验收合main56ef7719；[SP253](../../SP-253-detached-log-integration/README.md)已完成独立审查、合后CLI/local与清理关闭，见[收口](../../SP-253-detached-log-integration/plans/20261031-main-closeout.md)。clear-app-data保留观察：数据范围、默认/多用户、目标拒绝与机器确认契约尚需设计，不直接把能力名空缺等同现有缺陷。

iCTRL HEAD c1e4268859ba/v1.98.16/Apache-2.0全文hash未变，SP193独立保存检查时间；9个旧许可/二进制/hosted来源缺口保留，不因本轮文本增量完整而推进旧partial成功点。serve-sim匿名curl失败经已有gh认证恢复，记录了真实恢复路径；不关闭TLS。

昨日716份原始证据原路径已缺失，原因未知；报告/检查点仍在，历史读取成功和当前可用性分开，见[保管记录](20261031-evidence-custody.md)。本日原始响应与安全文本直接保存仓外archives；未重构昨日原始响应。

仅官方只读查询、固定源码/测试文本审阅；上游代码、设备/签名/DDI、依赖安装或升级、远端push/tag/release均未执行。开发和门禁另在SP252/253记录。

| 仓库 | HEAD | Release | 完整性 |
| --- | --- | --- | --- |
| tddworks/baguette | `94b78d3603ac` | v0.2.12 | partial |
| EvanBacon/serve-sim | `ede4c21ee302` | — | 完整 |
| lycorp-jp/sim-use | `c02295edfd2f` | v0.16.0 | 完整 |
| MobAI-App/simslim | `d594c230fe9e` | v0.13.0 | 完整 |
| Mastersam07/OpenDeviceHub | `e50f07f1f448` | v0.2.0 | 完整 |
| JaviSoto/device-hub-ios | `3779e12aa00c` | — | 完整 |
| heoblitz/Loupe | `ff1351242e6d` | v0.5.1 | 完整 |
| jfarcand/mirroir-mcp | `485416f3641d` | v0.42.0 | 完整 |
| RockxyApp/Rockxy | `de791b63e7f9` | v0.41.0 | 完整 |
| ProxymanApp/atlantis | `cc059013de87` | 2.0.0 | 完整 |
| OpenMinis/iCTRL | `c1e4268859ba` | v1.98.16 | 完整 |
| getsentry/MobileBuildMCP | `2998ac77ebbc` | v2.7.1 | 完整 |
| awizemann/harness | `3f58c077ded1` | v0.8.4 | 完整 |
| dongxinsuperman/ai-phone | `d339057bc64a` | v0.8.0 | 完整 |
| karminski/eyes-on-my-phone | `eef71926e613` | — | partial |
| RevylAI/revyl-cli | `34a9587752f0` | v0.1.204 | partial |
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

## 交付结果

SP252/253已验收合本地main56ef7719；合后完整CLI162 XCTest+1665 Swift Testing及适用local通过，3 CLI环境skip与1根包Bonjour skip明确保留。执行工作区/分支已正常清理，执行聊天已归档；当前长期主控继续。17条采用合并均可达main。今日884份上游证据与本批开发/主控证据均在scratch外核验，昨日raw缺失仍未恢复。未push/tag/release或执行设备。
