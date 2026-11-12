# serve-sim：2026-11-12 增量与历史 partial 恢复

结论：`observe`，`complete_review=true`，`historical_partial_recovered=true`。从成功检查点起的旧 22 提交和今日 7 提交，全部变化 hunks、直接相关完整核心与测试、许可证及 Release 列表已完成审阅。没有新建采用切片；读取完成不表示实现、运行验证或交付完成。

## 固定范围与证据

- 成功基线：`ede4c21ee3021a36fbee1fec106b388a50a5ce4e`。
- 前次仅观测且 partial：`5f6dee52834351ae2d765dfda02e540248a9b663`。
- 今日 HEAD：`cea9a7df9b73fb04f4f257640d10c7af3770950f`。
- 本地比较 main：`0ec972e6151eb27372b3bdf5aa940940c56c30b0`。只用提交源码，不把 SP-281 WIP 或主控随后提交混入此版本的结论。
- [完整固定比较](https://github.com/EvanBacon/serve-sim/compare/ede4c21ee3021a36fbee1fec106b388a50a5ce4e...cea9a7df9b73fb04f4f257640d10c7af3770950f)。[今日补充比较](https://github.com/EvanBacon/serve-sim/compare/5f6dee52834351ae2d765dfda02e540248a9b663...cea9a7df9b73fb04f4f257640d10c7af3770950f)。

两段采集为 22/7 提交、140/59 路径、284/105 段内文本版本、26,922/10,229 行归档 diff；合并去重为 **29 提交、173 路径、359 blob**，共有 **292 项 parent/path change**。已重核所有原始文本 SHA256 与 Git blob SHA，23/8 个 tree 响应均无截断；分页找到固定 base，每 parent 的整树比较没有遗漏路径，无排除项。严格 TLS 官方 API 采集，路径用途白名单及身份/密钥/二进制排除先于 blob 获取；没有执行下载内容。

`review-coverage.json` 对每项 change 记录 commit、parent、path、版本、diff hash 和领域负责人。`core-review.json` 登记核心范围 49 个全文或完整新增文本版本（10,997 行，控制进程测试由独立审阅者读）；`recording-review.json` 登记 27 个旧全文版本（6,659 行）及桥接范围；`camera-ui-review.json` 登记补读的 11 个全文版本及新增模块；`native-followup-review.json` 登记两个提交全部 19 项 changes 与 8 个核心/测试全文版本（1,403 行）。这些清单有交集，不能相加声称独立文件数。共享大型文件读取完整相关变化和必要上下文，不把全部采集的历史全文冒充逐字审阅。最初工具截断内容已按路径/行分块补读，撤回的 scrub 三个旧测试也完整补读，当前无剩余语义审阅项。

本日闭合旧 `semantic_review_incomplete_26922_diff_lines_22_commits`，只在今日声明恢复；冻结的 11/11 review/source 未修改。更早被移除 raw 的来源仍未知，不声称本轮恢复了那些旧原件。

## 与当前 main 的评估

| 机制 | 处置 | 实际依据与边界 |
|---|---|---|
| AX refs、settle、discovery | 观察 | 当前有 fresh host AX/wait/query；没有相同跨快照短 ref 协议。上游 1,394 行 refs 测试明确暴露 value-only 行、ID 复用、相同树不可区分等边界；渲染计数不证明身份。所谓 hard timeout 仍等待 read，不能当取消保证。软叶/跳格会以完整性换速度，性能未本地验证。 |
| HID ACK / Device Hub | 本地安全要求已覆盖 | main 对附件 unknown 拒绝，派发与业务验证分离，禁止自动重放；DTUHID 已合，不重排。上游首次 shadow unknown 放行、ACK 4 秒超时 exit0、旧 addon undefined 算成功，反而弱于本地要求。覆盖不代表拥有其所有按钮或 WS 协议。 |
| Home 路由、超时 | 观察 | 上游持久 Node/direct SpringBoard/toolbar 专属。弃置不可取消 direct 后 fallback 不能作为未知派发重放依据；runToExit 的完成也不证明 guest Home 结果。今日 flick 只在已确认 chrome、portrait、shadow 安全时尝试，未知走 launch。 |
| Unicode pasteboard | 已覆盖基础要求，观察新增实现 | main device clipboard 有 64KiB、退出/截断拒绝、前后读回和 verified，明确 staging 非输入完成。上游 devicectl 字节读回与自动 Cmd+V 不是已证明的本地修复；本地 Swift String 比较不被描述为逐字节一致。 |
| 键盘 toggle / 顺序与释放 | 观察 | 上游持久 handle 排序、超时释放、迟到 down 清理有参考价值；无同样本地回归。AX 键盘可见与 boot mtime 保存状态是启发式。 |
| 录制 index / 离线 frame-diff | 观察候选 | main 已有录制时长及 session/目标/owner 约束。离线诊断是潜在收益，尚无当前承诺回归；上游 footer 存在就 complete、可选 index 失败仍 MP4 成功、时钟固定偏移等不能直接作为证据完整性。BDD/文件面见 recording 报告。 |
| rolling buffer | 观察 | 连续采集须独立预算/隐私/生命周期契约。上游最新帧可超字节预算并无限保留陈旧样本；不能照搬为严格 cap 或新鲜证据。 |
| camera uniqueID | 已覆盖 | main hook 已按 front/back uniqueID 返回 fake device，未知 ID 交回原实现。 |
| camera movie/显式 connection | 观察候选 | 当前验证的 sample-buffer/preview 范围不承诺 MovieFileOutput；缺少具体目标 app 与兼容验收设计。caller-address swizzle、output 所有权和 writer 生命周期需独立契约；不因上游测试存在就采用。 |
| custom device-set | 观察候选 | 当前只有 clone 目的集选项，无完整活动 namespace 选择契约。应先定义 list/selection/action/native/helper/state 一致身份，不静默回默认集。 |
| scrub / frame-rotation / toast | 撤回历史及观察 | 昨日 scrub 在今日 `4d9498f` 删除 3 源/3 测试，并回退 hooks 接线；旧三测试全文补读，不能排已不存在的 UI。其他正式 Web/Finder 交互不扩展当前 CLI 产品面。 |
| Node 常驻 control | 观察 | 四核心、bin/build、53 项测试源及 fixtures 已读。accepted/go 防重、单用预热 worker、私有 socket 有参考价值；收益专属 Node bundle，未证实 Swift CLI瓶颈。环境标记不等于 kernel sandbox，mtime不等于制品身份；性能数字未本地验证。 |
| helper重签 / Duo hinge | 既有观察 | helper为上游签名架构修复，不引入自动去 hardened/ad-hoc 重签。Duo 同20261017已登记需求去重；main iOS fold明确unsupported。上游 reader死亡后保留stale角度、每秒无限重试和缓存缺少内容再验不能照搬。 |
| Metro / async probes / MJPEG / SSE | 观察 | Node事件循环、双流viewer等专属机制无同源本地回归。Metro按role ios广播可能影响未出现于inspector的真机；SSE目的固定loopback但转发viewer认证上下文，不据此新增远端shell控制面。 |

SP-283 Homebrew公开资产门禁和 SP-284 Simulator诊断依赖已读固定 main README，均已交付，不重复采用。本轮没有发现可直接分派、具备明确当前产品缺口与验收闭环的新项；AX、离线录制、camera movie、custom set 的条件 BDD、潜在文件面和收益已记录在 JSON/领域报告，状态是观察候选。

## 许可、Release 与运行边界

[固定 LICENSE](https://github.com/EvanBacon/serve-sim/blob/cea9a7df9b73fb04f4f257640d10c7af3770950f/LICENSE) 全文已读，Apache-2.0，SHA256 `9024cdf56dfe7e66523698a9f63d3a0061eb15f43bd5ea8e3833a56017ae37fd`。本轮不复制源码；后续复制应保留许可/适用归属及 NOTICE、标注修改。官方 releases 首页为空、分页完整，没有 Release notes 可审；不从提交标题推断发布。

本轮验证仅为源码语义审阅与完整性/hash核对。未运行上游测试/依赖、Simulator或设备、签名、第三方程序、真实发布下载或发布；所有上游性能和运行兼容性说法未经本地复现。没有修改仓内产品、共享登记/检查点、冻结 archive、本日 metadata/result，也没有 Git mutation。docs-only仓内门禁由有文档变更的主控负责，本子任务只有仓外证据。
