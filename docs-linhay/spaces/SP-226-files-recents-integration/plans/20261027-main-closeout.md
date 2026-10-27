# 2026-10-27 Files Recents 主线验收与关闭

## 交付

执行候选 `46bbf1c95c919f9ac0c6bcc6bc0386f97179af4f`；独立联合候选 `32fd37321acde93e4f15b559467a76340fc47c1e`；主控证据 `1847653e546eff9ce2e8be5092f060b22f44cd74`；实际main合并 `607cdf1c025547ce8b5be21eaa00548e25400bb4`。原目录main干净后merge-tree预检无冲突，no-ff合并。仅catalog增加files-recents/searchd与search downside；原24 feature映射、15类别、168 slimmable/171 managed labels不变。原catalog来源SHA保留，新增来源独立注明。

## 验收证据

- 执行红测试真实失败：旧catalog不认识files-recents，XCTest3失败、SwiftTesting2 issues；最小实现后focused XCTest10+SwiftTesting132通过。
- 独立主控重复focused通过；首轮完整CLI XCTest94通过、SwiftTesting1528出现1个既有FramebufferHelper marker缺失失败。未改helper/测试或放大timeout，独立suite11与精确1用例通过，相同产品第二次完整94+1528/154 suites通过。首轮原因未知，复跑不等于修复，原失败日志和hash保留。
- 实际main合并后完整CLI：PID70173、exit0、141.414s（含重建），XCTest94零失败，SwiftTesting1528/154 suites报告通过，3个显式真实环境skip（Simulator1、NetService2）；日志hash `88f9b4ada130815b978dd1044f38b08ab92bb2f62e57c0fb8aca133083e55b1b`。
- main构建的实际 `triton sim resource features` 与 `profiles` 各输出单一合法JSON，exit0/stderr空；与主控输出逐对象一致，25 features、files-recents唯一且仅searchd。二进制hash见[离线结果](20261027-main-validation/offline.json)，命令/退出/日志hash见[完整CLI结果](20261027-main-validation/main-cli.json)。
- 合后 `verify.sh --ci-docs`、`check-docs.sh`（226 spaces）、`git diff --check`及合并范围diff检查均通过。最终docs-only回写再运行文档门禁；产品不变不重复Swift测试。

实际命令默认输出JSON，不接受 `--json`；前期验收指令误写导致exit64，现已纠正并保留证据。没有扩改parser。健康结果仍为 `service-overrides-only`，缺省override沿用既有语义；真实Files/document picker UI、Simulator服务恢复、其它工具链未运行。没有shared core变更，根包和local总门禁未重新运行；完整CLI与实际离线入口是本切片验收范围。未执行设备、签名/DDI、依赖安装、第三方代码或push/tag/release。

## 清理与会话关闭

原始红绿/首轮失败/复跑/离线JSON/编译日志，以及两space的冻结文档和main验证文件已复制至 `../TritonKit-worktrees/archives/20261027-sp225-sp226/`；MANIFEST.json共53份文件逐一核对size+SHA256匹配。完整CLI在控制worktree产生的ignored CLI/.triton夹具日志也已归档，未遗失。

确认执行与主控tip均为main祖先、两worktree干净且停止写入后，正常git worktree remove并git branch -d删除两份已合并工作区/分支。当前仅原目录main。会话归档工具已分别返回archived=true：执行 `01a17b28-ccf7-7593-b589-72fa36290516`、主控 `01a17b29-206c-7b73-bfc4-6bded108ca9d`。长期追踪聊天保持开放。

经验回看：本次误写命令与未知夹具失败已修正并记录在原SP226[独立验收](20261027-independent-validation.md)，保留真实入口、失败/复跑和边界，不新增重复skill。采用登记、space索引与当日memory同步回写；16条采用合并SHA均在main。上游读取9个partial仍保留，开发完成不冒充读取缺口恢复。
