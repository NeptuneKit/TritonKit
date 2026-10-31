# 2026-10-31 原始证据保管缺口

昨日manifest的716份原始文件（45,364,312字节）当前原路径0/716存在；有界检查仓外archives及相关docs/memory未发现对应整批归档。缺失时间、原因与责任来源未知。正式观察、5份评估、日报、检查点、manifest均仍在；历史“当时读取与hash通过”保留，但不再声称原始文件现在可复核。

没有把保管缺口伪装为上游读取失败或回滚成功SHA，也没有将今天metadata冒充昨日原始响应。今日日检直接采集到`../TritonKit-worktrees/archives/reference-monitor/20261031/`，正式manifest登记路径/size/hash；保存位置脱离可清理的Swift scratch。若日后按固定SHA重取源码，必须另标恢复副本，不能声称恢复了昨日API响应和执行日志。本轮尚未恢复昨日原始批次。

经验写回正式采用流程和ops skill：长期追踪原始证据不能只存.build；checkpoint推进前复核持久归档，历史读取成功与当前可用性分开。机器记录见[保管状态](20261031-evidence-custody.json)。
