# SP259 local validation

## RED

- `swift test --package-path CLI --scratch-path .build/sp259-cli --build-system native --jobs 2 --no-parallel --filter XcodeBoundedDiagnosticsTests`：编译成功，4项测试、4个行为断言失败，exit1。日志 `.triton/sp259-validation/red.log`。失败是现有helper返回nil，不是缺符号或编译失败。
- 实际旧CLI对自有fake xcodebuild执行generic iOS Simulator build：fake只输出合成文本且exit65，没有调用Xcode或设备。输出3,300,141字节，CLI exit1，final保留xcodebuild_failed/exitCode65，却无xcodeDiagnostics，note指向缺失字段。证据 `.triton/sp259-validation/cli-red.jsonl`、`cli-red-check.json`；原stdout/stderr artifact路径随该final保存。

## 候选与验收范围

测试覆盖超1MiB尾部fatal、无诊断、artifact不可读、行/样本上限、扫描预算、跨64KiB UTF-8边界/无尾换行、截断敏感值、专用与generic分类并存、旧DTO缺coverage解码。执行Xcode相关suites和实际CLI fakebuild；结果待追加。

这证明诊断提取机制，不证明历史私有项目已恢复。没有修改或清理DerivedData，没有启动设备，没有提交/推送/合并/发布。全局索引与memory由主控整合。

## 经验写回建议

只增加fatal正则不能修复大日志诊断缺失；最终helper若只读内存前缀，必须另有有界artifact或流式来源，并显式报告coverage。截断可能发生在敏感argv值中间，精确字符串替换不能保证此类前缀安全，因此截断行不输出原始sample。后续主控将本条回写原Xcode skill与经验索引；本Space保留可审计证据。

## 初候选阶段验证与审阅补漏

- 首次GREEN执行期间负责人补写schema nested字段，Swift以input modified during build拒绝编译；`.triton/sp259-validation/green.log`保留该执行错误，不作为产品测试证据。源码冻结后以显式`TRITON_CLI_PATH`重跑，`green-final.log`为94tests/4suites通过（初候选，非最终交付）。
- 独立审阅发现：跨行敏感argv逐行精确替换可能泄露片段；CR连接多条诊断只保留首样本却未标截断；artifact只检查open前路径未绑定FD前后身份/时间。这些阻塞项已由后述修订与回归覆盖。
- 先加仅供测试的读取观察hook（nil默认不改变生产行为），再加跨行secret实际JSON字节、CR/CRLF六条诊断、同长改写与atomic replacement反例。review-red结果与修订后的GREEN见下文。

## 审阅修订 RED

- `XcodeBoundedDiagnosticsTests/(multilineSensitiveArgumentNeverLeaksInEncodedDiagnosticBytes|carriageReturnDiagnosticsPreserveSamplesAndTruncation|artifactMutationOrReplacementCannotClaimCompleteCoverage)`：3项测试、7个真实断言失败，exit1，`review-red.log`。跨行secret按编码后的JSON字节检查；文件变化分别使用同长改写和原子替换。
- 修正仅涉及bounded scanner私有实现。第一次修订GREEN因guard第二项缺少try而编译失败（`review-green.log`），修正后冻结源码并重跑`review-green-final.log`；此编译失败不计作行为RED。

## 最终本地验收

- 冻结源代码后执行 `TRITON_CLI_PATH="$PWD/.build/sp259-cli/debug/triton" swift test --package-path CLI --scratch-path .build/sp259-cli --build-system native --jobs 2 --no-parallel --filter 'XcodeBoundedDiagnosticsTests|XcodeDiagnosticsTests|XcodeProgressTests|XcodeCommandTests'`：97 tests / 4 suites 全部通过，exit0。日志 `review-green-final.log`。专属12项测试包含上述3项审阅反例。
- 同一新binary、进程私有PATH注入自有fake xcodebuild：3,300,141字节日志的尾部fatal提取成功；JSONL仅一个最终summary，原stdout artifact完整，coverage为stdout:artifact、bytesScanned=observedBytes=3300141、complete=true。证据 `cli-green-tail-fatal.stdout`、`cli-green-tail-fatal-check.json`。
- 无匹配诊断（19字节合成失败日志）：`--json`单对象包含diagnostics-unavailable、matchCount=0、complete=true，note不再指向缺失字段。证据 `cli-green-no-diagnostic.stdout`、`cli-green-no-diagnostic-check.json`。
- 默认64MiB真实CLI预算反证：70,400,062字节日志扫描67,108,864字节；保留prefix fatal，不提取预算外tail fatal；coverage.complete=false、truncated=true、linesTruncated=true。证据 `cli-green-limit.stdout`、`cli-green-limit-check.json`。原raw artifact保留。
- 三案均保持CLI exit1、exitCode65、xcodebuild_failed与ok=false；没有把诊断成功当作构建成功。脚本及binary SHA256随check文件保存；`candidate-sha256.json`绑定本地候选。
- 实际`schema --command xcode.build --json`含coverage全部9个嵌套字段，保存`schema-xcode-build.json`。
- `git diff --check`通过。`check-docs.sh`与`verify.sh --ci-docs`均在SP259缺全局space索引条目处失败；全局索引归主控整合，不在本子任务越权改写。整合后必须重跑这两项，当前不宣称完整门禁通过。

以上日志位于本worktree的`.triton/sp259-validation/`，保留原失败与成功结果。未执行完整`verify.sh --local`、远端CI、提交/合并/发布；这些由主控绑定整合head完成。受控backend用于验证CLI数据链路，不证明原私有工程编译恢复，不关闭issue。

## 审阅经验

按行扫描替代整段解析时，敏感argv跨行值必须按非空片段保护；截断行不能依赖完整值替换。文件路径不是稳定artifact身份，读取前后同时复核FD与路径的device/inode/size/mtime/ctime，任何变化标partial。逻辑换行与样本计数须一致，CR-only不应虚报样本完整。这些具体反例已转为回归测试；主控整合时回写原Xcode skill及经验索引。
