# #237 整合候选 · 2026-10-30

当前基线为远端main dba41b6e及SP248独立候选；原本地30185dc2的日检文档没有纳入。生产/测试源码与首轮root403、JSC/macOS WKWebView通过的候选一致；新增共享错误码的组合由实际PR CI重新验证。

本机loadavg超过250，组合root冷编译只到部分模块阶段。本次仅向已绑定cwd及`.build/integration-root`的自有进程树发送SIGINT，命令exit130；日志`.build/issue237/integration-root.log`保留，标记未完成，不能计为通过。没有停止其他任务进程、没有放宽测试。后续合并必须以精确候选的远端Swift/root、Release CLI及标准CocoaPods检查通过为前置。

真实iOS/private App SDK升级仍未执行；此修复可按生成脚本与真实macOS WebKit机制验收合并，不等于原现场恢复，issue保持开放。发布、tag与关闭issue未授权。
