# SP-203 实施与验收计划

基线：dd613a994abe45aa14e072c381662a0e3d868f03。仅本独立 worktree 开发；不提交、推送、合入或发布。

## BDD

1. Given 默认 serve 或显式 LAN bind，When 无 advertise opt-in，Then 不创建发布服务，状态 wanted=false、state=stopped。
2. Given --advertise 或 TRITON_ADVERTISE=true，When 发布流程启动，Then wanted=true，只有 NetService 成功回调才是 advertising；失败保留错误、停止撤销，重试清除旧错误且旧回调不能污染新代。
3. Given 非法 port/host/advertise 配置，When 预检，Then bind/publish 前失败；--no-advertise 能覆盖环境开启。
4. Given HTTP /status 与 CLI status --json，Then 同一只读 discovery 状态可编码/解码，旧服务缺字段保持兼容；advertising 不声明端口就绪或身份认证。
5. Given SDK 默认 bootstrap，Then 不发现/首选 Bonjour；显式 host 优先，opt-in 发现等待有界窗口，仅单个有效候选可选，多候选/未解析/伪造公开 ID 不升级信任。
6. Given Release SDK，Then 默认与显式发现均不产生网络活动，start/connect 仍 no-op；Debug 单独测试。

## 分工与验证

SDK worker 仅写 TritonKit.swift、SDK 发现 helper、TKPlatformFallbackTests/SDK 发现测试；主控写 CLI serve/helper/help/schema、状态 DTO 的兼容字段和 CLI status 透传、测试、接入文档/public skill 与本 space。CLIServerRuntime/Runner 禁止改动。

先失败测试再实现；执行 focused CLI、完整 CLI、根 Debug/Release、verify --local（跳过未经授权设备构建）、docs gate。Bonjour 运行负例使用本机隔离 loopback service 与专用服务类型，清理自身资源；结果不能代替外部设备接入验收。完整门禁与 fake fixtures 不宣称真实 iOS 接入。

共享索引/memory 由主控来源会话整合；本 space 交付记录保留经验和文件清单。可复制缺失未提交 space/index 仅作门禁上下文，不作为交付。
