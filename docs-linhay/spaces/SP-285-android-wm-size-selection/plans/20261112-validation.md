# SP-285 2026-11-12 验收

基线 main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`；产品仅修改 Shared 的 `TKAndroidWMSizeParser` 与 CLI `SingleDeviceWebPageTests`。独立审查已通过，固定差异和两个文件 SHA 保存于仓外 `TritonKit-archives/reference-monitor/20261112/mobile-next__mobile-mcp/final-review.txt`。

- TDD：旧实现下4项目标测试失败14 issues；增加3个测试后整套页面/geometry33项通过。正常 Physical→Override、原逆序、噪音、CRLF、非法/溢出/尾垃圾及相同/不同重复均覆盖。
- 完整CLI：XCTest167 + Swift Testing1861 / 204 suites通过；根包XCTest7 + Swift Testing130 / 26 suites与313 / 45 suites通过。数量分开记录，不把重复运行累加。
- 首次local的root、release build、CLI smoke、Harmony host fixture及iOS runtime fixture通过；到docs阶段发现路线总览没有完整Space标签，另发现经验索引不允许anchor，已修正两处链接并同步285/285编号；ci-docs修正后通过。未修改产品规避门禁；提交后重跑适用local全程。
- 当前测试工作区包含既有SP281 WIP，因此完整门禁代表该现场组合；提交只含本切片文件/共享文档中的本切片段落，不纳入SP281或SP279差异。
- 真实Android/ADB、旋转截图、坐标动作、Xcode Simulator构建、签名/DDI、远端发布均未执行；local显式 `TRITON_VERIFY_XCODE=0`。未安装依赖或执行上游代码。

证据根：仓库同级 `TritonKit-archives/reference-monitor/20261112`，包括sp285-red-final、focused、full-cli、root、local及提交后日志。提交后结果将按实际SHA写回本页。

## 提交后验收

main `c4c5f014150f80ce848ee43bd7a2932857fb704b`，精确提交8文件（2产品/测试、6文档）；完整CLI XCTest167 + SwiftTesting1861/204再次通过。`TRITON_VERIFY_XCODE=0 verify.sh --local` 全程通过，包括根包XCTest7与SwiftTesting130/313、release构建、CLI/Harmony/iOS fixture smoke、285 spaces文档与diff检查。真实Simulator构建按授权边界跳过。没有新branch/worktree/桌面执行聊天；日志直接归档仓外，原有WIP保留。

经验沉淀：正式 `mobile-mcp-reference.md` 与 EXPERIENCE 路由已更新多行优先级、异常拒绝和实际消费者边界。文档门禁发现的标签/anchor格式问题已按现有规范修正，不另建重复治理规则。
