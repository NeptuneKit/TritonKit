# MobileAgent 固定增量审查 · 2026-11-11

结论：`observe`，完整读取并完成评估。JSON 优先机制已有本地实现；GUI-Owl 格式和自主重试 loop 当前未接入，未建立直接开发所需的真实本地缺口。

- 仓库：X-PLUG/MobileAgent，仍为研究候选。
- base：`81fa28b564ef7a695521500bc15a0e1324b2b394`；head：`c4cd0a8f9ddedad24dd8a3daf3a56ca69343849f`。
- 5 commits / 1 commits 页 / 7 parent edges / 7 完整 trees；parent 差异16路径，实际 base→head 仅8路径；28个完整文本版本，418127字节。
- Release 列表1页完整、无 Release；MIT LICENSE 未变，SHA256 `961819a89dacd1f4f161e1d2ebf616b538bf095a2eecfa3ef40b7ccec633fac4`。

## 机制裁决

1. [合法 JSON 中 URL/hash 保真](https://github.com/X-PLUG/MobileAgent/commit/1d54cac967907607c7e73a0b59119dd03d2d5e42)：MobileAgentE `extract_json_object` 先对原文 json.loads，仅失败才走原有 naive comment strip；6个新测试方法覆盖 URL、`# ` 文本、plain action、尾注释、fence、list、失败。它只修复整体合法 JSON；带 fence/尾注释又含 URL 的输入仍会进入旧 stripping 分支，不能称为任意格式保真。当前 main `CLIActionProviderRuntime.swift` 的 AgentCPM-GUI 路径已直接 JSONSerialization，再验证 action；TYPE text 原样进 DTO/commandPreview。`ActionProviderParserTests` 有TYPE无执行与unsupported稳定错误码测试，但没有专门 URL/# fixture，因此只判实现机制已具备，未声称该特例本地已测。`CLIVLMRuntime.swift` 的点解析同样 JSON 优先，之后才 tuple fallback；它是点协议，不是任意 agent action JSON。
2. [GUI-Owl parse_action/retry](https://github.com/X-PLUG/MobileAgent/commit/0b5c25aa8c4126aa59566f059c48f21735951791)：由脆弱字符串 split 改为 tool_call block + JSONDecoder.raw_decode；容忍 tag周围空白、缺closing tag、JSON后尾文；要求arguments对象及action字段。12个新parser测试方法覆盖结构与错误。新增 max_parse_retries 默认3，即最多4次predict调用；重复同一截图并加format hint，全部解析失败时break，动作执行发生于解析成功后。仅结构解析测试，未见retry预算/调用数/失败停止的测试；也没有动作名/坐标/text完整schema验证。直接照搬宽容输出可能掩盖多块/尾部输出，重试会增加调用成本并继续消费旧截图，不适合未经需求与预算契约直接移植。
3. 本地 `TKActionProviderOption` 只有ui-tars、agentcpm-gui，解析命令输出preview，不发模型请求或执行设备动作；`CLIVLMRuntime.swift` 支持点定位，远端 provider 要显式批准，非法响应有稳定失败。当前没有 MobileAgent/GUI-Owl tool_call输出契约、自主模型action loop或对应split故障；不能把不支持该格式自动当作bug。因此observe，无新增provider/模型重试开发切片。
4. README news和UI-S1日期修正仅研究资料；论文录用、训练数据、模型性能均为上游表述，本次未验证性能，不触发采用。

## Merge去重与历史边界

5个待审commit包含2个merge；逐parent完整审查额外看到8个路径的MiniMax API/protocol/pricing/thinking、PNG data URI及input_text聚焦修复。所有8路径在实际base和head的blob完全相同，见 `review-base-head-paths.json` 与 `review.json.merge_parent_only_paths_identical_at_base_and_head`，它们是第二parent历史差异，不能算本次新变更或重复排期。已阅读额外差异及测试源码，未调用API、未引用其价格为当前事实。PNG链本地主线已有`data:image/png;base64,...`，但该观察仅辅助历史归类。

## 本地主线与BDD边界

固定 main 证据保存在 `review-local-main/`：ActionProviderRuntime/Commands及ParserTests、CLIVLMRuntime、VLMGroundingTests。VLM测试源码覆盖localhost chat completion、remote approval、JSON point、越界/非法契约和unsupported；本次未执行这些测试，无测试绿色声明。

无真实 adoption candidate，无新增BDD/实现文件面。若未来明确接入GUI-Owl，最小独立需求必须先定义：tool_call数量/结构/未知动作拒绝，合法URL/hash保真，解析失败无动作、每次重试记账且总预算有界、超过预算稳定失败；重试期间截图身份/新鲜度不可被默认继承。应在既有ActionProvider解析及测试面定义离线契约，再另行审定模型loop，不能通过fixture宣称设备运行验收。

## 范围与证据边界

本次只读审查固定官方 SHA 增量，对照实际 main `607410fb3d44bfe02274c13822170c3015c63a99`。base 同时核对 `before-reference-state.json` 的成功 checkpoint 与 SP-207 `20261102-observations.json` 的 complete=true；历史导入不作为基线。完整 commits 页已读到 base，逐 commit 的每个 parent 通过完整非截断递归 tree 求差，再对安全文本路径取完整 blob。`review-manifest.json` 保存 SHA256/字节数，全部 blob 另核对 Git object SHA1。没有依赖 GitHub compare/patch 的截断响应。

`review-base-head-diff.txt` 是实际 base→head 差异；`review-diff.txt` 保留每条 parent edge 差异。安全筛选在取 blob 前执行；本批排除 0 个路径，未取二进制/身份材料。完整 LICENSE 与全页非 draft Release 元数据已读。未下载或运行发布资产、上游代码，未安装依赖、调用付费模型、操作设备或修改 Git。所有本地产品证据均为固定 main 的 `git show` blob，见 `review-local-main-manifest.json`，不使用当前 dirty WIP 判定。测试源码审阅不等于测试通过，本次未执行任何产品或上游测试。

本次只交付外部 archive review；未改 `result.json`、checkpoint、采用登记或仓内文件。由主控独立复核后更新状态。新取固定 SHA 的证据是本次采集，不冒充历史 raw archive 恢复。

经验核对：本轮沿用固定main、完整parent树、阅读/评估/采用独立状态与研究候选边界；没有新增可复用产品经验，正式SP-207/memory由主控统一回写，避免并发写共享资料。
