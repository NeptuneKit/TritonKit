# SP-223/SP-224 实际main验收与收口

2026-10-26：产品合入本地main `9fbda1d5df52bc8e5d814d65fa5992552a32f86b`，实现候选`25205ea2`、独立联合`80922842`、主控报告`c390a89f`、日志补证`1c735787`。合前actualmain临时同级worktree干净，merge-tree通过；合后3份产品/测试blob逐字节匹配冻结manifest。当前local_merged，未push/tag/release。

| 验证层 | 结果 |
| --- | --- |
| 正式旧实现反证 | 三runner×stdout/stderr，6场景18行为断言失败；后续退出事实丢失反证2定义/6场景6issues，不混计 |
| 执行与独立focused | 各50 tests/2suites通过，含12新增测试定义及参数化反例 |
| 独立完整CLI | XCTest91零失败；SwiftTesting1527/154suites报告通过，3真实环境skip；exit0 |
| actualmain完整CLI | 同91+1527/154，3skip，exit0；postmerge-cli.json绑定9fbda1d5、PID76287、138.989s含重编译，测试35.800s |
| actualmain实际CLI argv | fake-adb4场景成功/非零/未EOF/非零且未EOF，单一JSON、无重放；未EOF约0.3s失败，exit7保留；不连接设备 |
| actualmain离线local总门禁 | exit0，154.995s；根包XCTest5、SwiftTesting108/20与293/41通过，Release CLI build、release/fakeHarmony/fakeiOS smoke、docs/diff通过；TRITON_VERIFY_XCODE=0，真实Simulator构建未执行 |

根包真实Bonjour有skip，CLI三skip为owned Simulator JPEG与两真实NetService。focused与full重叠不累加。真实设备、跨Xcode、TSan、实际磁盘耗尽/故障FS、安装接替未验；0.25s仅pipe收尾预算，不承诺同步文件open/write/close硬截止；大stdin旧路径不变。

原verify.sh首轮触发自动repository元数据Updating后按本任务PID停止，exit-15，不算pass，Package.resolved无diff；离线wrapper只为swift build/test补--disable-automatic-resolution --skip-update，原local各步骤完整执行。原始被停止日志与成功日志均保留；未安装升级版本。合后日志初次暂存diff发现编译诊断空白，未止住shell commit链而提交daa32cbe；后续7eeef6f8将完整raw保留ignored/归档，tracked摘要保持连续测试输出或明确摘要，postmerge-log-manifest逐hash区分raw/摘要，最终range diff检查通过，不冒充首次检查绿色。

证据位于本目录validation，原始大日志在原主目录`.build/reference-monitor/20261026-followup/root/raw-main/`；主控原始focused编译日志在其ignored目录，清理前归档至同级archives/20261026-sp223-sp224，manifest核验。两源worktree已停止、clean，branch tip均可达main后正常清理；原11份文档整理未提交，开工hash/精确副本和patch保留，临时main完成后原目录回main并保留整理diff。

当前清理和最后docs门禁结果写入本文收尾段；不得把临时main通过当原目录回main已完成。经验已回写ops治理与CLI文档，输出完整性/exit事实分开，旧SP222整理WIP不混入本批提交。
