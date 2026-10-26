# 2026-10-23 iCTRL检查与恢复

初次gh metadata和系统curl证书校验失败，网页读取连接失败。确认其他组官方API正常后仅一次安全重试成功；完整metadata、HEAD、全部非draft Release分页、固定HEAD许可全文/hash读取闭合。[HEAD874f528](https://github.com/OpenMinis/iCTRL/tree/874f528759b1b977971a06cc4a3594d169eb77b9)、[v1.98.12](https://github.com/OpenMinis/iCTRL/releases/tag/v1.98.12)、Apache-2.0均未变。

复用10月20日完整增量源码及SP-192/203～205交付，不新增采用。未关闭TLS验证，原因未知；首次失败保留在`.build/reference-monitor/20261023/ictrl/first-attempt-failures.json`（按实际tool输出重建记录，非原始响应文件）。本日摘要保存后推进独立成功时间，SP-207不复制成功点。无产品/设备/上游运行验证。
