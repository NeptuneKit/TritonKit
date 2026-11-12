# mirroir-mcp 2026-11-12 固定增量与端口有界性复核

结论：**整体 partial，complete_review=false，检查点不前移。bounded_local_port_probe 保持 revise-first，未创建 adopt。** 新增的 3 提交已静态审阅；自有 loopback 实验没有复现端口探测挂起。

- base：`1166ac1517263d773703c08ceae762a20432d3a2`，本次核对 SP-207 `reference-state.json` 的成功 checkpoint 仍为 11/02。
- previous observation：`5a3f93d86fdd40aad7d1a6267223146e110870dd`。
- head：`982c8718d2abbad9c3921749525a0c74832635e3`，来自今日 `result.json`。
- actual main：`0ec972e6151eb27372b3bdf5aa940940c56c30b0`。`git show main` 保存 WebRuntime 与 WebCommands 固定源码；不取其他任务 WIP。
- license：Apache-2.0，全文 SHA256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`，未变。

## 端口探测：静态事实与实验边界

当前 `CLIWebRuntime.swift:225–228` 先同步执行 `isTCPPortListening`，然后才执行 HTTP probe。`:599–628` 的 `getaddrinfo` 和 `connect` 均无显式总 deadline 或取消处理，所有 resolution/socket/connect 错误归为 false。`:644` 的 HTTP `timeoutInterval=1.0` 不约束先前调用。`:593–597` 的启动可用性检查也复用该 Bool。WebCommands 的 status/doctor `--host` 是 String，默认127.0.0.1；已读命令源码未见名称解析时限契约。

这些源码足以证明“函数自身没有明确的时限保证”，并支持一个窄范围健壮性提案；**不等于证明当前默认本机用例必然挂起**。本轮未找到并验证一个既有强制响应 SLA，不能用新发明的时限判现有运行失败。继续 revise-first：先明确支持的 host 范围、解析是否计入预算、unknown 语义及兼容，再决定实现，不直接把静态观察写成已复现 bug。

实验为自有源码：`probe-fixture.swift` 直接摘录固定 main 的 `isTCPPortListening`，仅加计时与输出；使用本机 swiftc 编译，编译退出0。`run-probe-fixture.py` 自建127.0.0.1随机端口 listener，`listen(1)`，不 accept，保留填充 socket，再执行摘录函数；每个子进程外置3秒 watchdog。只用自己拥有的 listener/进程，不调用真实产品服务、设备、公共端口，不修改系统 TCP/DNS 设置。

|试次|有 listener 基线|压力 probe|关闭 listener 对照|watchdog|
|---|---|---|---|---|
|0|true|true，0.387041 ms|false|未触发|
|1|true|true，0.344875 ms|false|未触发|
|2|true|true，0.271375 ms|false|未触发|

填充连接交替被接受或 ConnectionResetError；未证明队列已稳定饱和。结论是**该实验未复现挂起**，不是“已证明无问题”，也不是“饱和必挂”。没有执行 DNS 阻塞、Swift Task cancellation、packet filtering、真实 CLI 启动或实际 TCP 绝对上界测试。`probe-fixture-results.json` 保存 stdout、耗时、fill 结果和退出状态，负结果原样保留。

后续 BDD（仅候选，不是本轮交付通过项）：

- Given resolve/connect provider 保持 pending，When status/doctor 检查，Then 所有阶段共同受一个 monotonic budget，取消与关闭归属明确，输出 unknown/error。
- Given 一个地址 pending 而另一个 listening，Then 总预算内找出 listening，不逐地址叠加预算。
- Given timeout/cancellation/DNS/socket failure，When start 检查，Then 单一稳定 JSON failure、未知 fail-closed，不把 failure 当 free。
- Given 自有 loopback 明确 refused，Then 保持既有 idle/available 行为并测试旧 Bool 消费兼容。

拟文件面：CLIWebRuntime、CLIWebCommands、WebCommandTests，以及契约裁决后实际所属 schema/docs。先补可控失败测试，再最小实现；本轮没有产品写入、space、branch、worktree 或采用分派。

## 今日新增量

[固定新增量](https://github.com/jfarcand/mirroir-mcp/compare/5a3f93d86fdd40aad7d1a6267223146e110870dd...982c8718d2abbad9c3921749525a0c74832635e3) 共3提交：`c20800a` 升0.46.0、[`2d4adf8` npm启动修复](https://github.com/jfarcand/mirroir-mcp/commit/2d4adf8bd845d6e29225bfcd6e616bc89f257e60)、`982c871` 升0.46.1。全部3 parent edges用4个无截断 tree比对；10个不同改动路径、28个path+blob文本版本；Git blob SHA1及SHA256校验。完整阅读10个路径的当前全文、wrapper旧全文和3条完整diff；旧version-only全文与已读版本仅版本值差异。清单在 `review-new-manifest.json`。

实际路径：`Sources/mirroir-mcp/Version.swift`、`mcpb/manifest.json`、`npm/install.js`、`npm/package.json`、`plugins/hermes/mcp.json`、`plugins/hermes/plugin.json`、`plugins/mirroir/.claude-plugin/plugin.json`、`server.json`、`.github/workflows/installers.yml`、`npm/bin/mirroir-mcp`。

npm launcher在native binary缺失时运行同包installer，stdout/stderr均定向stderr，之后用inherit运行native服务，避免安装日志污染MCP stdout。新增CI用自有stand-in installer和已构建binary断言stdout仅一个MCP响应。install.js原有固定版本、checksum校验、解压/rename路径已全文读；未执行下载/安装，也未把其实现认证为通用安全方案。Triton当前没有该npm native wrapper，自动首次下载不是本轮新需求，**observe，不分派**；机器可读stdout单一输出原则本项目已有，不需重复建采用。

已读[Release v0.46.0](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.46.0)与[v0.46.1](https://github.com/jfarcand/mirroir-mcp/releases/tag/v0.46.1)正文。v0.46.0描述的scroll语义/compiled v6及serve等大部分来自旧未全审52提交，Release摘要不能补足源码覆盖；版本差异不当作本日重新新增实现。真实输入/截图/签名/安装主张未在本机验证。

请求走严格TLS官方GitHub API/raw，只取事前白名单文本。扩展名为空的 `npm/bin/mirroir-mcp` 最初跳过，读取commit patch确认JavaScript launcher、检查tree size<10KiB后精确放行；全文shebang/UTF8/hash确认。没有下载上游binary、identity/凭据/密钥，未执行上游脚本、依赖、设备或签名。

## 整体仍未覆盖

相对成功checkpoint现在共55提交、56 parent edges。今日新增3提交完成独立静态审阅，**旧52提交仍为11/11原partial**：旧53edges中仅4完整采集，49未完整采集，旧14个head文件语义复核，338已采文本版本尚未语义复核，更多未取文本数量未知。未强抓数千文件，未将新片段完整冒充全量完整。11/11冻结档案未改；其报告、hash和本次新证据分别保存。

验证仅包含自有Swift摘录编译/3轮loopback实验、固定SHA/树/文本/license校验；未执行上游或项目完整测试。经验检查无新增规则，补充了重要的负复现与静态保证区别；主控负责SP-207/memory/索引，archive-only子任务不运行共享docs门禁。
