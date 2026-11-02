# SP-263-issue-252-harmony-wait-errors

状态：最小候选已实现，等待主控串行Swift测试槽。关联 GitHub #252。

## 边界与 BDD

仅本 issue 的 CLI/契约或公开技能修复；不操作用户设备，不混入其他候选。Given issue 中的脱敏复现，When 执行实际 parser 或受控后端，Then 契约与实际行为一致，保留失败、未知和无副作用边界。细化验收由负责人写入 plans。

## 归属与验收

分支 feat/SP-263-issue-252-harmony-wait-errors；worktree /Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-263-issue-252-harmony-wait-errors。主控串行运行共享构建与 Git 写操作。先 RED 后实现与 GREEN；独立审阅、完整回归和 CI 通过后合并，issue 保持开放。

## 当前证据

现有v0.2.38 fake-HDC九场景复跑：5个待修复场景真实失败，4个原有边界通过（idle零后端、条件timeout、observe基准、runtime server错误）；证据`.triton/sp263-validation/baseline-cli/report.json`。新的10项Swift回归尚未执行。候选只改Wait catch、专属错误helper及wait schema.failureCodes；不修改#147轮询机制或设备状态。详见[契约](plans/contract.md)和[自动验收](plans/accept-wait-errors.py)。
