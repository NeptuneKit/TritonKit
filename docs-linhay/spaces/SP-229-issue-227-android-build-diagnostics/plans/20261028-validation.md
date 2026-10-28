# 验收记录

候选基线：a0d187ac；继承中断后的未提交差异，修订已有测试后验证。

## 初步审计与限制

- Android 原实现以 warning/error/failed 子串统计，task 名和 warning 文本会误计错误。继承的中断候选已开始修复，但只匹配精确 FAILURE:，并漏 Java severity；补充失败夹具后再完成实现。
- 诊断仍沿用现有最多 2000 行采样预算，计数不是整个 Gradle 构建的完整 compiler 总数。
- 2026-10-28 `verify.sh --ci-docs` 的 scope classifier 通过，但结构阶段失败；独立 `check-docs.sh` 同样失败，原因是本 worktree 基线仅到 SP-227，新 SP-229 前缺其他 issue 的 SP-228 登记。仅添加本 issue 登记，不伪建别的 space；主控须在批次联合候选补齐连续登记后复验。
- 未运行真实 Gradle/Android 设备、未解释私有项目为何超时、未提交/合并/推送/关闭 issue。

## 冻结时实际验证状态

- 命令：`swift test --package-path CLI --no-parallel --jobs 2 --filter BuildRunnerTests`，使用独立 worktree 的 CLI/.build。当前工具链默认 build-system=swiftbuild；首次编译到 1729/1781，尚未执行 tests，主控因宿主 load 过高要求暂停。
- 精确停止本任务 test shell PID 2376 的进程树（2386/40148/41265）；session 54539 exit 143，未杀其它 worktree 进程，之后未发现带本 worktree 路径的残余 compiler。保留日志 `/tmp/sp229-red.log`。这不是红测失败或绿色验证证据。
- 在暂停后完成 classifier、原请求 platform 兜底与 monotonic duration 静态修订，未再启动构建。`git diff --check` 通过。
- 主控待在 SP-241 使用单一 native build-system / jobs 2 scratch 验证 BuildRunnerTests，再完成联合 focused/full。反证可串行临时复原基线 CLIBuildRuntime/Models 两文件，保留当前 tests，确认 task/warning 误计与 duration 0 被检测，然后恢复候选复验。不得在构建运行中切换源码。
- 必须覆盖：Kotlin 两条 warning 含 error + 一条 e:；Java error/warning；Gradle FAILURE banner 与 task/heading/footer 不重复计数；重新解析工具失败仍使用原请求平台；fake Gradle warning 后 timeout 返回 ok=false/errorCount=0/warningCount=1/durationMs>=200。
