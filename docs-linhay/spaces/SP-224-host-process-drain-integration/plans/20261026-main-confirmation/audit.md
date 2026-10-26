# 主线收口只读审计（2026-10-26）

## Requested

核对当前main与10份SP-221/SP-222资料整理差异，确认旧独有证据保留、当前与历史边界；核对SP-223/SP-224合并及完整CLI/fake四场景/local证据。不修改正式文件，不执行Swift、设备、网络、依赖或Git写操作。

## Observed

当前main@5c892e2e，ahead origin/main 36；9份tracked文档修改加1份untracked审计历史，无产品WIP。SP-221/222 README已收敛当前状态；旧阶段报告增加历史说明及最终验收跳转，新增审计历史保留substring、来源绑定、fixture、索引及patch问题及旧hash；原全文仍可由8fcd856f和归档复查。无独有证据丢失迹象。

SP-221/222已合本地main，真实恢复等限制被明确保留；不能将真实运行未验推断为未合并。SP-223/224同样已完成离线合并验收。

## Evidence

- a0eebff0、9fbda1d5、eb9539f4、95a1dc8f、1c735787逐一执行merge-base --is-ancestor main，均exit0。
- SP-224 manifest的3个生产/测试文件hash与当前工作树均一致。
- postmerge-log-manifest.json中的postmerge-cli.log、postmerge-local-offline.log及被停止的postmerge-local.log，raw均存在且SHA256逐一匹配。
- raw完整CLI记录XCTest91零失败与SwiftTesting1527/154 suites通过；postmerge-cli.json绑定9fbda1d5、exit0、138.989s。离线local JSON绑定相同候选、exit0、154.995s；raw含根包108/20、293/41通过。
- postmerge-cli-cases.json保存complete/nonzero/incomplete/incomplete7四个实际CLI argv结果，单一JSON；未EOF约0.299/0.322秒失败，incomplete7包含底层exitCode7，未连接设备。
- SP221/222归档MANIFEST40项逐文件大小/SHA256全匹配。SP223/224归档MANIFEST当前394项逐文件大小/SHA256全匹配。
- INDEX、spaces/README、MEMORY顶部已记录SP221/222与SP223/224本地合并；历史阶段保留候选/原始hash和未执行范围，未把旧exit130/中止local算通过。

## Gaps

1. 文档轻微陈旧口径：SP222 README“证据归档与清理”行写“只剩干净主工作区”，未明确这是先前清理阶段；本次工作区实际10份原docs WIP。建议改为“当时清理完成时仅余干净主工作区；本轮整理差异另记”，避免读作当前clean。该问题不否认历史clean或产品合并。
2. SP224主线收口文档写“360份…已归档”，当前归档MANIFEST为394项且全部hash通过。若360为初次清理快照，应明确初始/最终数量及补充来源；否则更新为394。是数量口径，不是证据缺失。

其余所审内容No issue；未见未完成产品实现被写成已验证，亦未见真实设备/同步文件IO硬截止被声称通过。

## Remaining risk

本次仅只读复核证据与文档；未重跑产品或文档门禁。真实Simulator恢复、跨Xcode/竞态、TSan、实际磁盘故障、同步文件IO硬截止、安装接替和发布仍按原记录未验。当前dirty文档尚未提交，远端状态只以本地origin/main引用读取，未网络查询。主控负责本轮最终门禁和交付判断。
