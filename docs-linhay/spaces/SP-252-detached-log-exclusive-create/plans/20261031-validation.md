# 2026-10-31 detached 输出验证

## 执行边界

基线 `8dc3514d6f5d3dd55884c5e4393e423c81c6b593`，分支 `feat/SP-252-detached-log-exclusive-create`，独立 worktree `/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/SP-252-detached-log-exclusive-create`。仅修改 CLI host process helper、新测试与本 space。主控负责共享索引、memory、adoption-state、main 整合及关闭；执行者不写这些文件。

## BDD / 红测设计

保留旧 `prepareHostArtifactOutputPath → createFile → FileHandle(forWritingTo:)` 实现，仅加入内部非全局注入 seam：预检后闭包和 detached output opener。测试从真实函数进入，不复制新 helper 实现。

- 预检后插入 regular/hardlink/symlink/FIFO，要求 typed artifact rejection，竞争者 inode/mode/content 不变；FIFO 持有本 fixture 的 `O_RDWR|O_NONBLOCK` fd，旧 writer 也不会等待 reader。
- fresh 输出要求权限 0600、`FD_CLOEXEC`、既有内容不可覆盖。
- stderr opener 失败时保留 stdout FileHandle 强引用，再检查原 fd 为 EBADF；排除 ARC 自动释放伪绿色。launch 失败同样覆盖两个句柄。
- 自有短命 shell 写 stdout/stderr，并以有界完成文件观察；nil 写 /dev/null 并启动自有 true fixture。

## 原始证据

持久目录：`/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/archives/SP-252-detached-log-exclusive-create/`。包含原始 red/green/full CLI 日志、独立退出码、红测 seam diff 与测试快照、环境与命令、最终候选记录及 SHA-256 manifest。日志直接写归档目录，不以 `.build` 为唯一保管位置。

## 结果与候选

实现提交：`86662bfe`（完整 SHA 见归档 `implementation-sha.txt`）。

| 检查 | 命令 | 结果 | 原始证据 |
| --- | --- | --- | --- |
| 首轮旧逻辑红测 | `swift test --package-path CLI --no-parallel --filter HostDetachedOutputTests` | 退出 1，4 tests / 16 issues；为预期真实失败 | `focused-red.log` / `.exit` |
| 补强旧逻辑红测 | 同上 | 退出 1，4 tests / 16 issues；为预期真实失败 | `focused-red-v02.log` / `.exit` |
| 最小修复绿测 | 同上 | 退出 0，4 tests / 1 suite；8 参数场景 | `focused-green.log` / `.exit` |
| 完整 CLI | `swift test --package-path CLI --no-parallel` | 退出 0，1665 tests / 176 suites（Swift Testing）；XCTest 162 项通过，绑定实现候选 | `full-cli.log` / `.exit` |

首轮后按主控审查补强：fcntl 返回负值必须先失败，不能对 -1 按位检查；mkfifo/open keeper/link/symlink/lstat 前置改 require；launch 失败精确断言 `.launchFailed`；成功路径保留 handles 验父进程 FD 关闭。补强在旧生产逻辑上重新产生真实红测后才改实现。

本机观测：四类竞争者叶子的 inode 被旧 createFile 替换，regular/hardlink 叶子内容改变；hardlink/symlink 原目标 sentinel 未变。不可把这些证据说成目标被写穿。stderr retained 引用只证明新显式关闭保证，未证明原 ARC 回收后的持续泄漏；旧 launch 失败原有关闭已通过，是回归覆盖。

默认 scratch `CLI/.build`，`swift test --help` 显示默认 build-system 为 swiftbuild；本次测试/构建严格串行，不与其他任务共享 scratch。

## 安全与验收边界

只解决最终叶子的预检后抢占；父目录整体替换与跨用户目录威胁不在全面承诺范围。本轮不运行设备、模拟器、上游代码、第三方工具或用户工程；既有 SwiftPM 依赖的正常构建不新增依赖。主控仍需独立审查与复验，focused 不替代完整 CLI/local/main 集成。

## 文档门禁

`docs-linhay/scripts/verify.sh --ci-docs` 通过（退出 0），253 spaces 注册检查与 release/docs 契约均通过；收口后的同命令复验、独立 `docs-linhay/scripts/check-docs.sh`、`git diff --check` 原始结果见归档 `ci-docs-v02`、`check-docs`、`diff-check` 日志与独立退出码。最终候选 SHA 和精确文件清单以归档 `frozen-candidate.json` 为准；归档文件 size/hash 见 `SHA256SUMS.json`，不包含清单自身。

## 交接阶段与经验沉淀

实现及 CLI 验证完成；main 整合、完整 local 门禁和合并后复验交由 SP-253 主控，不在本执行 worktree 声称完成。根包测试、release 构建/发布、安装接替、真实设备、独立攻击进程及用户场景验收未执行。没有新增依赖、锁文件或生成文件的 tracked 变化。

经验已回写本 space 原文：预检后竞态须在原函数确定性插入，再以竞争者 inode/mode/content 观察；FD 显式关闭验证保留引用；POSIX flags 前置成功与 FIFO 非阻塞夹具必须 fail-fast。本次未写共享 memory/skill/索引，由主控按权限整合，避免与其他执行面冲突。
