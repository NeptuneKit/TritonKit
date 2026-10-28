# SP-230 · Android install readiness 与截图失败分类

- Issue：[#228](https://github.com/NeptuneKit/TritonKit/issues/228)
- 阶段：候选已冻结，待主控统一测试与整合；未发布或真实设备验收。
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
- `check-docs.sh` 与 `verify.sh --ci-docs` 均因独立分支缺前序 SP-228/SP-229 登记，失败于编号连续性；主控汇集各 space 后重跑，不建虚假占位 space。
- 下一步：主控在联合候选以 `--build-system native --jobs 2 --no-parallel` 运行 `AndroidInstallReadinessTests|DeviceCrossPlatformTests|FailureDiagnosticsTests`，再串行执行旧实现反证与完整 CLI/local 门禁。具体记录见 [验证交接](plans/20261028-validation.md)。
