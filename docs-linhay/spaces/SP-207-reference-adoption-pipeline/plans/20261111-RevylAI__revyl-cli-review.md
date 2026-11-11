# Revyl CLI 2026-11-11 增量审阅

结论：partial/observe；无独立采用项，不推进检查点。

固定 base `a50ee179e5c01a1f25f15cef951a78eddab5fa3e` → head `dcf5f2ab9fdd181a3bbe770410f4ad19dc36fed9`，actual main `607410fb3d44bfe02274c13822170c3015c63a99`。1 compare页83 commits、83 parent edges、84完整树、198路径、628安全文本blob，均解码并校验Git blob SHA。完整增量文本存review-diffs.txt（23,600行/14,443,227 bytes）。重点语义审阅Computer生命周期/report validator、device start/stop、analytics sanitation、Python binary包装及对应测试。大增量未逐行审毕，不能把完整采集当完整语义审查。

本轮已补齐VERSION、.gitattributes、cjs、extensionless shell、ps1，旧extensionless缺口已恢复；仍禁止请求4个pyc。官方license endpoint404，无仓库级许可全文，hosted后端与旧binary provenance没有闭合。latest v0.1.234，Release API两页109项分页完成，v.204后5个非draft Release全文已读，说明主要为安装与Computer独立发行。未执行任何安装、脚本、测试、设备或上游代码。

Computer流程保留request UUID、派生operation UUID，发送一次再查询pending，未知不新建提交；结果、证据健康、资源释放分别表述。report validator核对时间、UUID、执行顺序、exit/status与完整性。云Computer/exec/远端会话不在本地产品范围，不能据此扩张；本地receipt与证据分离已有SP281进行中。

stop测试区分确实无会话与403/上下文不可读/存活但不可达；后者不伪装already_stopped。analytics失败尾部有界与诊断去敏可参考，但当前Triton标准证据不收集原始输出和输入，未确认同源缺陷且无新增遥测授权。Python从首次运行下载变为wheel内置binary，与Triton当前arm64/checksum流程不同，不建立新交付。

经验检查：旧partial只按实际证据逐缺口恢复，许可与二进制缺口维持；读取/评估/实现/运行阶段分开。无新仓内经验改动。
