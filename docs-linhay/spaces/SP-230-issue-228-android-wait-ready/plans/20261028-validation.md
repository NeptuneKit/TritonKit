# #228 候选验证交接（2026-10-28）

## 已知根因与候选

`waitForHostDeviceReady` 的 Android 分支原来只检查 adb state + `pm path android`。候选插入 `sys.boot_completed` 探针，并只在其为 1 时继续检查 package service；保留最后一次成功轮询三项命令。PackageManager 暂不可用继续有限等待，截止时保留既有 package-manager failure 类型。

`failHostCommand` 原来将 ADB 任意非零输出中的 `no such file` / `not found`（或 exit 127）当作 adb 缺失，抢在 screencap/pull 分类之前。候选只接受 `env: <exact executable>:` 的 127 lookup 缺失信息，远端文件与 shell 失败留在操作级分类。

## 测试及实际状态

| 检查 | 结果 |
| --- | --- |
| 新增 fake-adb 慢启动、boot 后 package 暂失败、截图与 env JSON fixtures | 已编写，待执行 |
| 旧实现红灯，CLI/.build，session 56285 | 编译阶段停止，exit 143；未到测试，不能声称旧错已被测试抓住 |
| `git diff --check` | 通过 |
| `check-docs.sh` | 失败：独立 SP-230 分支缺 SP-228/SP-229 前序登记 |
| `verify.sh --ci-docs` | scope classifier 通过，docs 同上失败 |
| 真实 Android 14 cold boot / APK 安装 / framebuffer | 未执行，fixture 不替代真实验收 |

未执行到测试的红灯日志位于 `.build/issue228/red.log`；docs 日志为 `.build/issue228/docs.log`、`.build/issue228/ci-docs.log`，为本地 ignored 辅助记录，不宣称提交或发布证据。

## 主控后续

1. 合并候选文件，在单一 scratch 使用 `swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter 'AndroidInstallReadinessTests|DeviceCrossPlatformTests|FailureDiagnosticsTests'`。
2. 同 scratch 串行旧实现反证：保留测试与其他联合改动，仅移除本候选 Android boot gate 和 executable lookup 窄化，再验证上述新增测试确实失败；恢复候选后重跑。
3. 集合 space 注册后 docs/local 与完整 CLI 门禁；发布与真实设备验收由主控分别报告。

没有执行设备动作、git commit/push/merge 或远端 issue 评论/关闭。
