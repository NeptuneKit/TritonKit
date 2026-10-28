# #229 验证记录

## 候选边界

- 旧路径：共享 `/sdcard/window_dump.xml`，仅退出码检查；退出 0 的 null-root 错误会读取旧 XML。
- 新路径：`captureAndroidHierarchy` 同时供 observation 与 action node resolution 使用。UUID-qualified file、精确回执路径、ERROR/null-root、文件读取、XML节点验证后才发布 artifact/节点。
- Cleanup 只尝试移除本 capture 的 UUID 文件，发生错误也不覆盖原始 capture failure；成功回执中保留 cleanup 命令但不声称删除已验证。
- 保留 Android bridge 优先与既有 collection budget。未改设备发现、键盘、截图或真实环境配置。

## 自动化

`swift test --package-path CLI --no-parallel --jobs 2 --filter 'AndroidHierarchyFreshnessTests|ObservationOutputTests'` 已在本 issue worktree 的独立 CLI/.build 启动，但默认 swiftbuild 未按预期约束宿主并发，主控要求停止；在依赖编译阶段终止，未得到测试结果。下一次使用 `--build-system native --jobs 2`，等待主控编译窗口。

涵盖：旧文件存在且 exit0+null-root；ERROR、空/错路径回执、非零dump；缺失、空、无效、无节点、截断 XML；连续调用唯一性、观察和坐标解析复用、成功/失败只清理自身路径、cleanup失败保留原错误。

## 文档与剩余边界

`git diff --check` 通过。`verify.sh --ci-docs` / `check-docs.sh` 受独立worktree登记间隙阻断：基线最高 SP-227，本分支只有 SP-231，脚本要求连续编号；主控联合登记 SP-228～240 后复验，不能把此失败记成通过。

没有运行真实 Android Emulator null-root 重现，没有把 fixture 当设备实测，也没有进行远端写入。先前 partial 实现的测试执行证据不完整，本次以重跑结果为准。

## 经验

退出0只能证明进程状态，不能证明 UIAutomator 新产物。必须将唯一产物路径、语义成功回执、内容验收绑定在同一次 capture，再允许时间戳/坐标消费；此约束已同步 README、CLI契约说明与 public emulator/regression/feedback skills。

主控决定将候选整合至 SP-241 后单次 native 构建统一验证；本 worktree 停止写入。此前未跑完 focused tests，也未执行旧实现 red 反证；这些不得宣称通过。
