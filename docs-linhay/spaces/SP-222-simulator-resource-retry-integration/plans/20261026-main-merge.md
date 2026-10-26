# SP-221 actual main整合

冻结执行候选eb9539f48df4ea6a0e1cf3de6828b8d8177c8017，主控联合候选4249bd264ddc0e1745e414187dbfa51e05e0bcf9/tree3a1e130ef0f3af4b144ad4072fbeec67f984661c。主控focused37和完整CLI（XCTest91；SwiftTesting1515/153 suites、3项真实环境skip）退出0。

actualmain合前clean，已运行merge-tree --write-tree预检；仅SP221 README add/add，生产/测试3文件无冲突且与冻结候选字节一致。文档人工保留root最新边界/真实thread/候选+执行红绿证据，未整controller branch回灌。真实合并a0eebff0，合后完整CLI退出0：XCTest91/0fail，SwiftTesting1515/153 suites通过、3个真实环境测试skip；根包单独退出0，XCTest5/0fail，SwiftTesting108/20 suites与293/41 suites通过（真实Bonjour skip）。适用local/docs门禁最终均退出0；验收通过后才更新local_merged。

原47份跟踪WIP均为本聊天文档，必要独立本地归档提交9a8f0cf1，旧untracked空白19fed414修正，后续边界文档a338bfaa/f0159b48/db44dfb1；产品候选独立提交66adfbde及证据修正eb9539f4，不混入其他产品WIP。无push/tag/release。

## 经验复盘

已修正上游启发落地的两项实际边界：重试必须测试生产typed nonZeroExit而非只有fake result；完整诊断白名单和成功/失败同命令来源绑定不能被宽泛substring/固定fixture规避。来源fixture收紧后仅调整原测试来源字段，没有削弱断言。原tracked patch尾空白、冻结交接和commit文件不一致在主控阻止后以docs-only eb9539f4修正；先红后绿hash与candidate生产blob一致。共享skill/dev合同已写明配置执行预算和runner清理耗时、取消不结束同步在途Process，未将离线通过宣传成设备恢复。

需要保留的16份执行/主控space文档及ignored红/绿/full/docs日志已复制到`../TritonKit-worktrees/archives/20261026-sp221-sp222/`，MANIFEST.json逐文件SHA256/大小已复核；后续新增root日志将另存同归档。本机build依赖缓存不作为唯一验收证据；不归档可重建buildproducts。正常清理前再次检查worktree干净。

## 合后最终门禁

actualmain a0eebff0：独立完整CLI退出0（XCTest91/零失败，SwiftTesting1515/153 suites；3个真实环境skip），独立根包退出0（XCTest5；SwiftTesting108/20 suites+293/41 suites，真实Bonjour skip）。`TRITON_VERIFY_XCODE=0 verify.sh --local`退出0，含根包、Release CLI构建、CLI smoke、fake Harmony/iOS runtime smoke、docs/diff；只跳过Xcode真实Simulator构建，因为本监控未获设备/真实Xcode动作授权，未把fixture smoke当成设备恢复。单独ci-docs/check-docs/diff均通过，222 spaces。Release只是本地build未发版、未安装替换，未push/tag/release。

只在以上实际合后门禁通过后将SP221状态标local_merged。严格launchd错误样本仍是上游文本+离线fixture，不代表本机暂态恢复概率或跨Xcode兼容。30s配置执行预算可能额外host清理耗时；取消不保证同步在途Process立即结束。

## 清理完成

40份本批空间/ignored日志/root门禁与只读摘要已归档并SHA256复核，SP221/SP222两个worktree均clean、agents已停止写入后正常git worktree remove与git branch -d。controller95a1dc8f证据已精确吸收f3d06523，使用history-only ours merge6271d24e保留控制验收提交可达性；两个提交tree完全相同，未回灌旧文档或产品，源branch为main祖先后普通删除。原目录为main，未push/tag/release。
