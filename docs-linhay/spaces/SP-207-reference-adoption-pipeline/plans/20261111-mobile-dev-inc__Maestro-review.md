# Maestro 固定增量审查 · 2026-11-11

结论：`observe`，完整读取并完成评估，未发现当前产品范围内需要直接开发的缺口。

- 仓库：mobile-dev-inc/Maestro，仍为研究候选。
- base：`5ca5313b4c6516bb66ff2537cdeb8edc01d61228`；head：`aaa248d7fd4ca4924444dc027af9c7a62a9be348`。
- 3 commits / 1 commits 页 / 3 parent edges / 4 完整 trees；13 个 base→head 路径，25 个完整文本版本，461746 字节；Release 2 页完整。
- 最新非 draft Release：CLI 2.12.1。Apache-2.0 LICENSE 未变，SHA256 `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`。

## 机制裁决

1. [Cloud upload warnings](https://github.com/mobile-dev-inc/Maestro/commit/aaa248d7fd4ca4924444dc027af9c7a62a9be348)：ApiClient 从响应 `warnings` 过滤字符串，缺失默认空；CloudInteractor 将 warnings 渲染在设备信息后；RunOnCloudTool 非空时透传 JSON 数组，同时维持 PENDING 状态；新增测试验证有/无 warnings。完整相关 Kotlin 文本已保存。收益是避免 agent 和人错过云端非致命警告。当前 CLI manifest 和源代码搜索未发现 Maestro Cloud 上传链、`run_on_cloud` 或 PostHog/OkHttp。Triton 本地 action/HTTP 的警告并不证明这条云链已覆盖，也不存在可复现的丢警告本地调用点。因此不为采用此机制增加设备云/MCP 上传控制面。
2. [PostHog logged-out identity 与生命周期](https://github.com/mobile-dev-inc/Maestro/commit/b80bd24a42892eb75440bb8e9d8bee24f1292cc0)：dispatch 调用时读 token，防异步 logout 后 token 丢失；无 token 设置 `$process_person_profile=false`，不附 stale company group；先等待 dispatcher executor 再 flush/close PostHog。7 个 EventDispatcher 测试方法覆盖 token 快照、identify 嵌套分发、退出、空/不可读 token、禁用和发送错误；E2E/单测设置 `MAESTRO_CLI_NO_ANALYTICS`。当前 main 没有对应遥测队列和登录身份链，不能把设备 target freshness 当同一缺口；不新增遥测。
3. [Release 2.12.1](https://github.com/mobile-dev-inc/Maestro/releases/tag/cli-2.12.1)：Release 正文仅指向 CHANGELOG，已阅读固定 head 的全文。新增 notes 提及 `${...}` appId 插值修复和 OkHttp 4.12.1 CA 拒绝列表，但本增量树差异中没有对应 driver 插值或 OkHttp dependency 代码变化，不能把 release 文案重复当成本次新增实现。当前 Swift CLI 不依赖 OkHttp；不把上游安全/性能描述当成本地测得事实。版本字段同步属于发布维护。

## 本地主线与验收

固定 main 的 `CLI/Package.swift` 提供真实依赖边界；`review-local-search.jsonl` 记录限定产品源/manifest/test面的搜索及返回码。`AGENTS.md` 提供本机平台边界；没有凭功能名宣布等价覆盖。无真实 adoption candidate、无需新 BDD/space/文件面；未来若另立云上传/遥测需求，至少需 BDD：服务端 nonfatal warnings 既能给 CLI 人读，也能在机器契约保留且不改成功状态；遥测禁用不发网络，退出事件身份绑定触发时刻且 shutdown 有界。该未来场景不代表已排期或授权扩展。

## 范围与证据边界

本次只读审查固定官方 SHA 增量，对照实际 main `607410fb3d44bfe02274c13822170c3015c63a99`。base 同时核对 `before-reference-state.json` 的成功 checkpoint 与 SP-207 `20261102-observations.json` 的 complete=true；历史导入不作为基线。完整 commits 页已读到 base，逐 commit 的每个 parent 通过完整非截断递归 tree 求差，再对安全文本路径取完整 blob。`review-manifest.json` 保存 SHA256/字节数，全部 blob 另核对 Git object SHA1。没有依赖 GitHub compare/patch 的截断响应。

`review-base-head-diff.txt` 是实际 base→head 差异；`review-diff.txt` 保留每条 parent edge 差异。安全筛选在取 blob 前执行；本批排除 0 个路径，未取二进制/身份材料。完整 LICENSE 与全页非 draft Release 元数据已读。未下载或运行发布资产、上游代码，未安装依赖、调用付费模型、操作设备或修改 Git。所有本地产品证据均为固定 main 的 `git show` blob，见 `review-local-main-manifest.json`，不使用当前 dirty WIP 判定。测试源码审阅不等于测试通过，本次未执行任何产品或上游测试。

本次只交付外部 archive review；未改 `result.json`、checkpoint、采用登记或仓内文件。由主控独立复核后更新状态。新取固定 SHA 的证据是本次采集，不冒充历史 raw archive 恢复。

经验核对：本轮沿用固定main、完整parent树、阅读/评估/采用独立状态与研究候选边界；没有新增可复用产品经验，正式SP-207/memory由主控统一回写，避免并发写共享资料。
