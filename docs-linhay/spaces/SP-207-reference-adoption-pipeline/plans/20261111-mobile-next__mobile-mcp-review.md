# mobile-mcp 2026-11-11 增量审阅

固定base `1851dfaca835d644adb409acad8b173120804bbc` → head `3b51952bcd83955f3a743f731f5a9beaebecdab7`，对照actual main `607410fb3d44bfe02274c13822170c3015c63a99`。[上游增量](https://github.com/mobile-next/mobile-mcp/compare/1851dfaca835d644adb409acad8b173120804bbc...3b51952bcd83955f3a743f731f5a9beaebecdab7)。5提交/5 parent边、6棵无截断树、8路径、17文本版本全部读取并验证Git blob hash，无排除。review-increment.diff和review-source保存全文；LICENSE固定SHA全文Apache-2.0及SHA256均确认。

判observe，无新增开发项。raw hierarchy及Android rawData字符串先JSON.parse的修复只作用mobilecli协议；Triton debug hierarchy直接读取iOS原始JSON，Android observe保存原始layout artifact，prettyJSON先解码JSONObject再编码，没有同源二次字符串化。daily telemetry quota只作用PostHog，Triton未使用该发送链。

新增#454用截图横纵比交换reported screen尺寸，以使tap提示匹配横屏。它仍是尺寸方向推断，不能从截图证明几何来源/secondary display身份。Triton CLIHostRuntime已有raw-framebuffer orientationPolicy、pixelWidth/pixelHeight及“未旋转iPad screenshot”显式限制，CLIHostNativeHIDRuntime严格唯一主屏portrait守卫，不采用交换尺寸猜测来扩大输入能力。未证明当前实际main有同源错误；保留方向校准需求观察。

[1.0.16 Release notes](https://github.com/mobile-next/mobile-mcp/releases/tag/1.0.16)完整读取，仍有Flutter Offset.zero、iOS snapshot性能与Android x86_64的mobilecli传递依赖声明；这不是本仓本轮新实现，不下载执行依赖，不外推为Triton缺口或本地性能。main固定blob对照在local-main。未改产品/检查点或运行上游/设备/测试。当前证据是本日固定SHA新采集，不冒充历史raw恢复。
