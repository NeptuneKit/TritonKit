# 2026-10-19 worktree联合验收

## 请求与候选

用户要求已实现内容合main、未实现内容完成实现和验收后合main。本轮本地操作，不推送/发布/清理worktree，保留原主目录WIP及CLAUDE.md。已完成参考资料经文档门禁后以`b1d20af9`进入main。

实现候选：SP-210 `c80f06c6`，SP-212 `618e9e9a`；schema/public说明`4d38c044`；联合产品候选`a8848036`。原始产品基线`d51403a6`。README add/add冲突逐文件保留实现候选的BDD/验收，索引按真实main增补。

## 观察与验证

- SP-210：去除屏幕尺寸和scale猜测；安全getter探测、NSValue类型校验、finite/正尺寸/overflow检查。10 geometry XCTest +6 budget tests通过；生产submitValidatedPress边界非法几何0次提交、合法1次。单envelope编码经过cliErrorDetail和TKCLIErrorResponse。该测试不是完整私有AX或真实设备证明。
- SP-212：13 foreground tests、44 shared focused tests通过；top malformed/null不回退旧记录，冲突unknown，仅展开leading dot；fake-adb与真实本地shell证明argv引用和脱敏，不宣称Android键盘Unicode/%s支持。类名规则核对[AOSP ComponentName](https://android.googlesource.com/platform/frameworks/base/+/master/core/java/android/content/ComponentName.java)。
- 联合CLI：`TRITON_CLI_PATH=$PWD/.build/cli/debug/triton swift test --package-path CLI --scratch-path .build/cli --jobs 4 --no-parallel`复跑1480 Swift Testing +69 XCTest通过。首轮FramebufferHelperTests.timedOutAndroidHelperIsNotAutomaticallyRelaunched因invocations夹具文件未出现失败；未改产品/测试，定向11项和完整复跑通过。该测试使用固定1.5秒等待，首次失败具体调度原因未知，保留原始失败记录，不将复跑抹去。
- 根包：local gate中的`swift test --no-parallel --disable-sandbox`，108+293 Swift Testing及2+5 XCTest通过。
- CLI进程：SP-213 plans/20261019-cli-acceptance.py显式fake ADB，7场景（top、legacy、bare、malformed top、window-focus、conflicting、backend failure）与5组schema通过。JSON解析同时拒绝双envelope；backend失败退出非零。没有真实设备动作。
- 文档：`verify.sh --ci-docs`、独立`check-docs.sh`和diff检查在资料合并前及main合后通过；最终收口还需复跑。
- Release构建、CLI smoke、Harmony host及iOS runtime observe smoke、本地门禁全部通过；Debug与Release实际CLI进程各7场景+5schema通过。最终收口docs-only、独立check-docs、diff均通过；候选验收完成，准备合入本地main。

## 验收边界与经验

本期space明确为离线契约验收。TRITON_VERIFY_XCODE=0，未执行真实Simulator/Android、旧新Xcode/Resize矩阵、签名、依赖升级、安装或发布。Android shared变更没有新增API依赖。独立审查发现纯几何测试不足以支持动作前拒绝声明，已补实际生产提交边界测试；bare activity不补猜测包名。经验回写原SP-210/SP-212说明、public skills与EXPERIENCE索引。

原始日志保留各worktree `.build/sp210-evidence`、`.build/sp212-evidence`、集成worktree `.build/sp211-evidence`。合并完成后在本报告追加main SHA、最终门禁与日志hash摘要。
