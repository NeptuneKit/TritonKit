# SP-230 · Android install readiness 与截图失败分类

当前状态：已随PR #233合入远端main（`40850dde`），issue #228已completed关闭；现场复验范围见[远端处置](https://github.com/NeptuneKit/TritonKit/issues/228#issuecomment-6460622988)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
- Issue：[#228](https://github.com/NeptuneKit/TritonKit/issues/228)
- 分支：`feat/SP-230-issue-228-android-wait-ready`；worktree：`../TritonKit-worktrees/SP-230-issue-228-android-wait-ready`。
- 影响层：CLI host Android adapter；不改变 Web/桌面壳与 embedded runtime。

## 边界与 BDD

1. Given adb 可达且 PackageManager 路径已出现，但 `sys.boot_completed` 为空，When wait-ready，Then 不报告 ready，截止后失败。
2. Given boot 完成但 package service 暂不可用，When 继续轮询，Then 直到服务成功才报告 ready，回执包含 get-state/getprop/pm 三项证据。
3. Given screencap 或 pull 报告 `/sdcard` 文件不存在（含远端 shell 127），When 输出失败 envelope，Then 为 `android_screenshot_failed`，不建议重装 adb。
4. Given host env 确认找不到 adb，Then 保留 `android_adb_not_found`。

## 验收

- fake-adb 脚本驱动真实 wait-ready 路径；失败 JSON 必须可作为一个对象解码。
- readiness 只证明 adb、boot completed 与 PackageManager 采样可用；不证明安装必然成功、应用 runtime 或业务就绪。
- 不启动/停止模拟器、不安装 APK、不改变设备状态；真实 Android 14 慢冷启动场景由主控安排后续验收。

## 验证与交接

- `git diff --check` 通过。
- 新增 `AndroidInstallReadinessTests`：5 个测试声明，截图路径通过 2 个参数样本运行；包括真实 fake-process readiness 和单一 JSON 失败 envelope。
- 红灯命令 `swift test --package-path CLI --no-parallel --jobs 2 --filter AndroidInstallReadinessTests` 在旧 readiness/错误分类实现上启动，但整机负载过高，在首次测试 target 编译阶段由主控要求停止（exit 143）；未执行到测试，不能称红灯已确认。日志保留于本 worktree `.build/issue228/red.log`。
- `check-docs.sh` 与 `verify.sh --ci-docs` 均因独立分支缺前序 SP-228/SP-229 登记，失败于编号连续性；现已在SP-241联合登记并通过docs门禁；该失败保留为独立分支历史。
- 联合结果：上述测试已随完整CLI通过，local通过；旧版0.2.33黑盒在boot=0却ready的反证失败，候选明确拒绝。历史构建记录见[验证交接](plans/20261028-validation.md)。
