# SP-196 上游优化开发与验证报告

日期：2026-10-14。状态：**实现与本地验证完成，独立工作区待集成**。源码在 `../TritonKit-worktrees/SP-196-upstream-optimization-delivery/`，branch `feat/SP-196-upstream-optimization-delivery`，起点 `306dc42b`。没有提交、合入、推送或发布。

[需求与BDD](../README.md)、[更新报告](../../../dev/20261014-reference-project-updates.md)、[接入裁决](../../SP-194-reference-project-updates/plans/20261014-adoption-decision.md)、[工程交付说明](../../../dev/20261014-upstream-optimization-delivery.md)、[机器可读验收摘要](20261014-validation-summary.json)。上游数据不作为本工程的测试或性能数字。

## 已交付优化

| 优化 | 实际行为 | 验证边界 |
| --- | --- | --- |
| simslim 资源规则 | 保护 assistantd/gamed/sharingd；widgets 保留 navd；plan/apply/verify 同源；receipt 只撤销仍匹配的受管改动，保留用户后续覆盖 | 专用模拟器 photos-only plan→apply→verify→restore 全过，恢复前后 disabledLabels 完全相同；未测内存收益 |
| Resize Mode | 每次完整 gesture 新鲜查询并绑定目标；active/unknown 触摸、视频拒绝；active 截图绑定当前 display UUID；观察提供 advisory | fixture、schema、真实 inactive 查询与截图通过；未生成真实 active Resize session，query→dispatch 仍有竞态 |
| Framebuffer/helper | selected Xcode SharedFrameworks/legacy 路径与 context 一致；工具链 pin；成功启动才加引用；helper 有界读取、取消并只清理自有资源 | 11 个 helper 测试通过；实际 private ABI 捕获 JPEG、双订阅、最后停止不再返回帧的独立 live test 通过 |
| 前景动作 | 仅 active scene；高层窗口和 presented subtree；后台/遮挡 OID 拒绝；六个 WebView 写入口复用规则 | 真实 detached/high nonkey/modal/dismiss/WebView/keyboard 五项通过；精确识别本机 UIKit 文本浮层，其它未知窗口保持保守 |
| WebView 受控输入 | native prototype setter、input/change/blur、50ms 后读回；原生拒值/异步回滚不报成功；不输出输入文本 | 真 WebKit 五项全过：tracker、date/number/select/textarea、secure rollback、拒值、contenteditable；业务提交与客户 React 页不在本轮证明范围 |
| Prepared tests | build-for-testing manifest→身份校验→test-without-building；源码/工具链/配置/目标/产物绑定；每次 fresh xcresult；零结果或全跳过不通过 | 77 项专项通过；真实 macOS fixture 一次编译两次复用各执行1项，结果路径不同；源码漂移在执行前返回 identity_mismatch |
| Typed prefs | present 区分 missing/false/0/empty；JSON/plist 整包校验与显式 key 白名单；可选 relaunch；磁盘与App消费分开 | 专用 App 实测 false/0/empty 存在、未选键缺省；launch 后 import/relaunch 成功；未运行App的 terminate失败单一receipt仍保留diskWriteVerified:true |
| Workspace config | 固定配置安全读写；完整旧字节备份、私有权限、原子替换；坏旧模型、未来版本及用户链接拒绝 | 完整 CLI 回归通过；不新增迁移 ledger 或自动备份清理 |
| 网络证据 | 已知 NDJSON schema 完整验证、共享导出统计、截断标记、URL 凭据/query/fragment 清理；保持 headers names-only | 完整回归及 Evidence/Replay 真实parser夹具通过；未扩展body/TLS采集或运行客户网络代理 |
| AppMap/执行证据 | stable ID 分页；总数/返回数/截断/下一页；empty suite副作用前拒绝；零成功primitive不能通过；finished failure回溯 | 完整回归通过；只限制返回量，不声明全图读取有界或跨页快照 |
| 安全 skill 更新 | checksum/归档预检、hash基线、拒绝本地冲突、整包stage与原子交换、私有旧包备份；legacy有改动拒绝迁移 | Swift5项、Python13项、打包门禁通过；覆盖staging后修改与备份改名失败，不自动合并或清理备份 |

## 最终验证

| 验证 | 最终结果 | 本地证据 |
| --- | --- | --- |
| 完整 CLI | XCTest 41项、0失败；Swift Testing报告1323项/128组、0失败，其中1项live默认禁用 | `.build/sp196-validation/cli-final-2.log`；live另行显式启用验收 |
| 根包 | SDK XCTest2 + Swift Testing77；shared XCTest5 + Swift Testing274，全部通过 | `.build/sp196-validation/local-final.log`，两模块统计分别保留 |
| 真实 iOS | 56项/8组，56通过、0失败、0跳过，xcresult Passed | sibling `.sp196-validation-host/ios-hosted-6.xcresult`，私有摘要 `.triton/sp196-validation/ios-hosted-final-summary.json` |
| Private framebuffer | 1项显式live通过；真实JPEG宽高合法；双订阅/最后释放验证 | `.build/sp196-validation/framebuffer-live.log` |
| 真实 resource/prefs/prepared | 上表场景全部完成；prefs不声称业务消费，prepared源码漂移非零且没有开始执行 | `.triton/sp196-validation/` 与 `.triton/sp196-prepared-smoke/Source/.triton/`，不公开原始身份与路径 |
| Local gate | 依赖边界、Debug隔离、根包、release CLI、CLI smoke、fake Harmony、runtime observe、docs、diff通过 | `TRITON_VERIFY_XCODE=0 verify.sh --local`；省略按设备名称选择的重复build，改用显式owned Debug测试与Release SDK构建 |
| 文档/安装门禁 | 最终文档回写后`verify.sh --ci-docs`、独立`check-docs.sh`、`git diff --check`通过 | `.build/sp196-validation/docs-final.log`，196个space与Python13项通过 |

真实 UIKit Swift Testing执行12.332秒，xcresult总持续32.021秒，口径不混用。没有把不同测试层的统计相加为一次全量结果。

## 失败记录与修复

首轮完整CLI失败：Swift Testing1318项/127组/44 issues、XCTest38项/1 failure。第二轮1318项仅剩6个schema issues，补参数作用域、父错误覆盖和恢复分类后通过。后续新增真实回归后最终为上表数量。

发现并修复：macOS `/var`路径与枚举相对名差异；资源fixture物理路径及真实launchctl末行缩进；旧network样本缺完整schema/换行；prepared系统路径别名及Apple生成包内链接；installer原始traversal/archive symlink；新增schema/recovery声明；真实键盘输入窗口抢占业务窗口。

UIKit第一次hostless前置失败，hosted1/3有诊断代码编译错误，hosted2/4暴露键盘问题（4随后取消，结果未完整），hosted5在Resolve Package Graph超时。均未计为通过。将宿主与构建/结果移到包外独立目录后，hosted6实际执行并解析56项全过；不以结果目录存在替代通过。

## 剩余边界与下一步

- 实现已完成本地验证；主线后来增加SP-195 Runner与SP-197高亮，尚未与本分支集成。集成时保留这些既有改动并再跑总门禁。
- active Resize 真实路由、跨OS私有框架/键盘窗口身份、长流期间Resize切换、客户React/业务提交仍需专项验收。现有未知状态拒绝规则保留。
- 资源节省数字未实测；没有以upstream估算或简单相减宣称性能收益。
- prefs磁盘成功与relaunch成功不代表运行App消费；App Group、suite、LegacyInspection属性patch不在本轮。
- AppMap返回分页不是全读取预算；非协作写者竞态、备份保留策略与URL路径敏感性仍存在。
- 未复制Rockxy AGPL代码、未引入swizzling/云设备/SSH/远端控制、未新增Web业务写面。

## 轨道记录

[Resource](resource-delivery.md) · [Resize](resize-delivery.md) · [Framebuffer](framebuffer-delivery.md) · [Foreground](foreground-delivery.md) · [WebView](webview-delivery.md) · [Prepared](prepared-tests-delivery.md) · [Prefs](preferences-delivery.md) · [Config](config-storage-delivery.md) · [Network](network-delivery.md) · [AppMap](appmap-completeness-delivery.md) · [Schema](schema-delivery.md) · [Installer tests](installation-tests-delivery.md)。
