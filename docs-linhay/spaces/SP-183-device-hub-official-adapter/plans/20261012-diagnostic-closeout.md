# 真机诊断归档成功路径收口

用户继续推进，既有授权包含诊断采集并已切换iPhone16Pro。复核唯一已绑定16Pro，执行独立采集，显式采用512MiB接受预算；保留默认256MiB及此前13ProMax的超限证据，不将旧partial改写为成功。原13ProMax仍未被发现，恢复配对继续为未完成。

BDD：独立诊断只接受原生目标/argv绑定file JSON、有效ZIP、安全新目标与私有权限；不解包或读诊断正文。当前输出硬编码实现阶段“未做真机验收”已与实际冲突，修正为稳定证据协议名，实际成败继续由各verified标志与status表达，不能把方法名当成功证据。先补失败断言再改输出文案。

## 原生成功与拒绝结果

iPhone16Pro diagnose exit0、status=succeeded，nativeResultVerified/diagnosticArchiveVerified与intent/completion均true；发布324630005字节ZIP（约310MiB），低于显式512MiB预算。文件0600、父目录0700，原生暂存归档与发布归档SHA-256一致。只验证ZIP结构和字节一致，不解包、不读取诊断正文、不声称日志内容完整。

同一已存在目标的负向调用在发布前返回exit1/device_administration_unsafe_artifact；未创建新audit目录、未重采、未覆盖归档，hash不变。13ProMax旧超限记录与未恢复配对状态保持。默认256MiB没有改动，512MiB仅本次调用参数，不自动递增。

执行输出移除硬编码实现阶段“未做真机验收”，方法名保持native-file-json-and-independent-postcondition，仍以status及verified字段区分结果。RED实证24项断言后修复，完整CLI与local门禁见最终记录。

[脱敏结果](20261012-diagnostic-closeout.json)，归档在保留worktree私有目录，不提交或上传。

最新完整CLI回归：1154 Swift Testing/104 suites + 26 XCTest通过。通用iOS Simulator构建非本轮范围，local以TRITON_VERIFY_XCODE=0运行，不能称Simulator验收。

本地local、ci-docs、check-docs及diff检查通过；采集前后设备连接状态一致。代码与脱敏证据依此前测试后合并授权本地集成，不推送发布。
