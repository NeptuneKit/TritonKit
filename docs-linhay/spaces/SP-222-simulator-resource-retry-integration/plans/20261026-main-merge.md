# SP-221/SP-222 主线验收与清理

## 最终结果与证据链

2026-10-26：执行、独立验收、实际main合后门禁、证据归档及正常清理均完成；本地状态为local_merged。未push/tag/release，未安装替换运行制品。真实设备恢复等未验证边界见下文，不将离线绿色扩大为真实运行验收。

| 对象 | 固定标识 |
| --- | --- |
| 产品基线 | `24e7d0f21017c8ca7104b6f8e3912fc2c44be892` |
| 冻结执行候选 | `eb9539f48df4ea6a0e1cf3de6828b8d8177c8017` |
| 独立联合候选 | `4249bd264ddc0e1745e414187dbfa51e05e0bcf9` / tree `3a1e130ef0f3af4b144ad4072fbeec67f984661c` |
| 主控验收报告 | `95a1dc8f`，详见[独立候选报告](20261026-validation-report.md)与[证据清单](20261026-evidence-manifest.json) |
| 实际main产品合并 | `a0eebff06564dcf68ccf728efc97ec2d4f3d9292` |
| 精确吸收主控资料 | `f3d06523` |
| 历史可达性整合 | `6271d24e`，tree与f3d06523相同，不回灌旧资料或产品 |
| 最终清理记录 | `8fcd856f` |

main合并前工作树干净并运行merge-tree预检；仅SP-221 README出现add/add，人工保留最新边界、真实thread和红绿证据。一生产文件、两测试文件无冲突且与冻结候选逐字节一致。控制资料先按本space精确吸收，再以history-only合并保留提交可达性。

原47份本聊天跟踪文档独立归档于9a8f0cf1，旧untracked空白由19fed414修正，后续边界资料a338bfaa/f0159b48/db44dfb1；产品实现66adfbde及证据修正eb9539f4独立提交，未混入其他产品WIP。开发和审查细节见[历史审查与修正](20261026-audit-history.md)。

## 验收分层

| 阶段/入口 | 实际结果 | 适用边界 |
| --- | --- | --- |
| 执行先红后绿 | 旧实现10项/3失败、exit1；最终focused37/37、exit0 | exit130中断不算红测试，旧28/33项绿色不累加 |
| 独立联合候选focused/full CLI | focused37/37；完整XCTest91零失败，SwiftTesting报告1515项/153 suites通过；exit0 | 3项真实环境skip；focused包含于完整回归 |
| 实际main合后完整CLI | XCTest91零失败，SwiftTesting报告1515项/153 suites通过；exit0 | 同样3项skip：owned Simulator JPEG和两个Real NetService用例 |
| 实际main合后根包 | XCTest5零失败；SwiftTesting108项/20 suites、293项/41 suites通过；exit0 | 真实Bonjour有skip，不称真实服务验收 |
| `TRITON_VERIFY_XCODE=0 verify.sh --local` | exit0；根包、Release CLI构建、CLI smoke、fake Harmony/iOS runtime smoke、docs/diff通过 | 未跑真实Xcode Simulator构建；Release为本地build，未发布或安装接替 |
| `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` | 合后及最终整理均exit0，222 spaces | 结构/脚本门禁不替代真实设备验收 |

只在合后门禁通过后更新local_merged。日志重复suite汇总不重复计数，各阶段回归不累加为新增测试。测试命令、二进制和源码hash详见候选报告/清单及归档原日志。

## 归档与清理

本机归档目录为 `../TritonKit-worktrees/archives/20261026-sp221-sp222/`（相对仓库根），`MANIFEST.json`列出40份空间资料、ignored红/绿/focused/full/docs/root门禁日志及只读摘要，逐文件大小/SHA256已复核。最初16份执行/主控资料为中间归档快照，最终40份为清理时完整清单；不将可重建build依赖缓存当作唯一证据，不归档buildproducts。

日志定位：归档的 `SP-221-simulator-resource-read-retry/docs-linhay/spaces/SP-221-simulator-resource-read-retry/plans/` 为执行日志；对应SP-222路径为独立验收日志；`root-monitor/`保留postmerge-cli/root/local及最终docs日志和退出结果。原路径/hash仍用于历史关联，原worktree已删除。归档原文及MANIFEST保持不变，后续文档整理不重写既有证据。

确认执行/主控停止写入、worktree clean且提交可达后，正常 `git worktree remove` 和 `git branch -d` 清理SP-221/SP-222。最终只保留原主目录main，未使用stash、强制删除、reset或远端写入。

## 保留的真实运行边界与经验

暂态错误样本为上游文本和离线fixture；typed nonZeroExit只证明reader处理生产错误类型，未在本机实际launchd故障中复现，未验证Simulator恢复概率、跨进程竞态或跨Xcode兼容。未知诊断保持fail-closed，扩展需实际捕获与反例。

30秒是配置执行预算，包含退避与各次剩余timeout；host terminate/kill/drain可额外耗时，非硬墙钟上限。Task取消不主动结束同步在途Process，只阻止返回后的再次重放。mutation仍保持single-shot和原恢复语义。无设备动作、签名/DDI、第三方参考代码运行或依赖升级。

复用经验已进入host skill与ops治理：生产typed throw和返回result分别验证；完整诊断及成功/失败来源绑定；fixture修正不放宽guard；冻结声明必须与实际tree/文件/hash一致；当前状态与历史证据分层，不能仅在重复全文后追加完成段。具体修正证据集中于历史审查，不重复登记事件。
