# Xcode failed-build bounded diagnostic contract

影响层：CLI Xcode build/test/archive/run 最终诊断，shared Codable诊断元数据；不改编译选项、缓存或项目。

BDD：
- Given stdout 超过1MiB且fatal位于尾部，When 最终summary提取诊断，Then 使用本次artifact的有界扫描给出fatal sample、覆盖范围，保留exit65和xcodebuild_failed。
- Given 构建失败但无匹配诊断，Then xcodeDiagnostics包含明确diagnostics-unavailable，原提示不再指向不存在对象。
- Given artifact不可读、扫描预算耗尽或行/样本截断，Then coverage明确不完整，不声称日志没有错误。
- Given 成功无诊断，Then 不新增失败对象；现有专用分类优先级和敏感命令值脱敏保留。

验收：合成日志与受控进程/CLI夹具独立执行，不重跑私有工程、不删缓存、不声称原编译故障已修复。先使用 `XcodeBoundedDiagnosticsTests` 现有函数行为断言取RED；不以缺符号编译失败代替行为失败。Swift构建等待主控串行槽。

## 有界扫描设计

inline未截断时仅扫描inline；已截断时优先读取该HostProcessResult引用的本次常规日志文件。每个stream最多64MiB、每行保留8192字节，chunk边界保留行前缀和UTF-8字节。artifact通过lstat、O_NOFOLLOW/O_NONBLOCK打开、FD fstat以及读取后的路径/FD复核绑定device/inode/size/mtime/ctime；缺失、变化、非普通文件或读取失败均明确不完整。打开前失败可回退inline；已开始artifact读取则保留已有部分并标记unavailable，不混入任意旧日志补证据。每类只保留5个样本；保留匹配计数并区分样本截断与扫描不完整。

coverage以结构字段报告sources、bytesScanned、observedBytes、scanLimitBytesPerStream、complete、truncated、linesTruncated、samplesTruncated、unavailableStreams。complete仅表示受支持分类器扫描覆盖，不代表解析器理解所有编译器错误。默认最多覆盖两个stream各64MiB；超限保留partial和原日志路径，不声称完整。

新增generic compiler-fatal-error只描述已观察compiler失败，保留xcodebuild_failed；不自动建议缓存清理、重复构建或改项目。没有可提取诊断且exit非零时，diagnostics-unavailable明确说明无命中，并指导保留raw artifact；不让note推荐缺失字段。

## 审阅补充边界

- 按行提取前对所有敏感命令值的非空换行片段保守脱敏，避免完整argv跨行而精确替换失效；截断行仍不输出原sample。
- CR、CRLF及Unicode换行按逻辑行处理，样本上限与matchCount一致；不将多个CR诊断压成一个未标记样本。
- 文件变化测试覆盖同长度原位改写与atomic replacement；读取后的身份/时间检查能证明此次观察期间未检测到变化，不构成文件系统事务快照保证。
