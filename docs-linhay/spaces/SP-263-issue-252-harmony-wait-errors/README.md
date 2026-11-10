# SP-263-issue-252-harmony-wait-errors

当前交付状态（2026-11-02）：十二项独立修复已随 [v0.2.39](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.39) 发布，发布提交/tag 为 `026d329e5346fce77ae62a2828e3d27ed2d94c2e`；候选、main/tag/Release CI、双架构制品与安装验证通过。公开安装版三端 HTTP/浏览器预览及自有资源清理已完成；完整状态见 [SP264](../SP-264-release-v0-2-39/README.md)，不将发布等同于原私有现场恢复。

状态：已通过 [PR #258](https://github.com/NeptuneKit/TritonKit/pull/258) 合入远端 main，合并提交 `dbe4ea08c96a839c77e20bcdbdf1e1db21729d2d`；前批联合主线 `572b4afb` 的必要 CI 已通过。#252 的机制修复和本轮自动验收已完成，已随 v0.2.39 发布并通过制品/安装验证；issue 保持开放。

## 边界与 BDD

仅本 issue 的 CLI/契约或公开技能修复；不操作用户设备，不混入其他候选。Given issue 中的脱敏复现，When 执行实际 parser 或受控后端，Then 契约与实际行为一致，保留失败、未知和无副作用边界。细化验收由负责人写入 plans。

## 归属与验收

分支 feat/SP-263-issue-252-harmony-wait-errors；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-263-issue-252-harmony-wait-errors。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和CI通过后已合并，issue保持开放。

## 首轮证据

现有v0.2.38 fake-HDC九场景复跑：5个待修复场景真实失败，4个原有边界通过（idle零后端、条件timeout、observe基准、runtime server错误）；证据`.triton/sp263-validation/baseline-cli/report.json`。新的10项Swift回归在首轮尚未执行；后续均已通过，见下文。候选只改Wait catch、专属错误helper及wait schema.failureCodes；不修改#147轮询机制或设备状态。详见[契约](plans/contract.md)和[自动验收](plans/accept-wait-errors.py)。

## 前批整合检查点（2026-11-02，历史证据）

- HarmonyWaitFailureTests全部10项及HarmonyWaitRuntimeTests在最终完整CLI回归通过；最终整合binary的fake-HDC九场景通过，保留missing/offline/ambiguous/executable与真实transport区别，以及unsupported idle零后端调用。
- 上述实现及本issue精确head CI通过后独立合并；当时联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 该历史检查点仅完成源码整合与自动验证；后续 v0.2.39 发布、公开制品、安装及三端预览已由[SP264](../SP-264-release-v0-2-39/README.md)完成，当前交付状态见顶部。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以顶部交付结论及SP264最终验收为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
