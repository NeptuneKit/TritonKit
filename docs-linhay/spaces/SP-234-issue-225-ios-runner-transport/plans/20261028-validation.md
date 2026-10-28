# 2026-10-28 验证与交接

- 基线 a0d187ac，SP-234 独立 worktree。此前未提交分类补丁已复核并扩展；没有 commit/push/设备动作。
- 测试先补：启动异常阶段、提前DTX分类、health成功但probe失败、私有日志不泄露；原专用代理残留测试语法已修正。
- 首次 `swift test --package-path CLI --no-parallel --jobs 2 --filter IOSRunnerLifecycleTests` 在依赖构建期间被主控要求停止：宿主负载过高，默认 SwiftBuild backend 未按预期限制并行。精确终止自身swift-test及子进程，无测试结果。不能声称RED失败或GREEN通过。
- 停止后完成最小实现、新增native-exit和bounded-tail/symlink/FIFO fixtures；`swiftc -parse` 和 `git diff --check` 通过（语法检查非编译/执行证明）。
- 主控需以 `swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter IOSRunnerLifecycleTests` 在联合候选执行；最好隔离恢复旧runtime验证新增行为负例。
- Native log最多读各128KiB尾部，固定特征需同一行，O_NOFOLLOW/O_NONBLOCK + owner/regular验证。原始输出不进入公共envelope；仅有界日志分类，不证明完整日志采集或特定工具链根因。
- 设备/XCTest handshake、真实授权/签名兼容性、全CLI/root/local门禁未执行，留主控统一验收。
- 文档门禁按当前worktree登记会因其他并行SP号缺失而失败，需主控集中登记后复跑，不能补虚构space掩盖缺号。
