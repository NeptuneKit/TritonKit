# SP-259-issue-248-xcode-diagnostics

状态：已通过 [PR #260](https://github.com/NeptuneKit/TritonKit/pull/260) 合入远端 main，合并提交 `8b6849be651dd8bd539e9ac0dee3d5cc06f6cdb9`；最新联合主线 `572b4afb` 的必要 CI 已通过。#248 的机制修复和本轮自动验收已完成，待 v0.2.39 发布及安装复验；issue 保持开放。

## 边界与 BDD

影响 CLI Xcode 最终诊断和 shared Codable 诊断覆盖元数据。Given 日志超过内存前缀且尾部有 fatal，When 构建失败生成 summary，Then 有界读取本次日志并保留 fatal 原因、覆盖范围和原退出码；无命中时明确 diagnostics-unavailable，不再推荐缺失的字段。范围不包含原私有工程的编译修复或缓存操作。

完整 BDD、预算和脱敏边界见 [诊断契约](plans/diagnostic-contract.md)；测试与运行证据见 [验收记录](plans/validation.md)。

## 归属与验收

分支 feat/SP-259-issue-248-xcode-diagnostics；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-259-issue-248-xcode-diagnostics。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和CI通过后已合并，issue保持开放。

候选文件面：Xcode bounded diagnostic helper、既有 parser 与最终适配点、诊断 coverage DTO、Xcode schema 和专属测试。未修改通用进程 runner、Harmony wait、参数解析或设备流程。

## 主控最终整合检查点（2026-11-02）

- 冻结候选97项Xcode相关测试通过；三项真实受控CLI案例覆盖3.3MB日志尾部fatal、无诊断与64MiB预算截断。整合后二进制重新验证tail-fatal与无诊断；原退出码/失败状态保持。
- 上述实现及本issue精确head CI通过后独立合并；最新联合主线为 `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`，[主线CI 41427953350](https://github.com/NeptuneKit/TritonKit/actions/runs/41427953350)已成功。
- 联合本地候选 `eb14f489218d80bf1072f0696b799939937b0131`（native祖先`71218395`）完成CLI 162 XCTest + 1719 Swift Testing、根包7 XCTest + 404 Swift Testing、Web159项串行测试、Web生产构建和完整 `verify.sh --local`。3项既有条件跳过单独保留；不是所有设备现场验收。
- 原始证据在同级 `TritonKit-worktrees/archives/SP256/` 的 `integrated-cli-full-v2.log`、`integrated-root-v2.log` 以及 `archives/SP264/` 的 `web-test-v3.log`、`web-build.log`、`local-preflight.log`。首轮组合失败 `integrated-cli-full.log` 与各issue RED/审阅反例继续保留，不用后续GREEN覆盖。
- 当前仅完成源码整合与所述自动验证；v0.2.39尚未发布，双架构资产、Homebrew、public skills安装与包外浏览器验收由[SP264](../SP-264-release-v0-2-39/README.md)继续收口。后续发布结果以该Space实际记录为准，不将本检查点解释为已发布。

原plans中“待执行/未合并”等语句记录各自采样阶段，当前状态以上方整合检查点为准。范围外私有现场不借本轮测试宣称恢复，未执行GitHub issue关闭。
