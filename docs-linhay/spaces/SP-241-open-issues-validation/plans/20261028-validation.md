# 全部开放 issue 联合验收（2026-10-28）

## Requested

处理 `NeptuneKit/TritonKit` 全部开放 issue：#214、#221～232。影响层是 embedded UIKit runtime、CLI/HTTP 现有命令契约、host adapter、shipped iOS Runner 及使用文档；不引入 Web 写操作或桌面壳新控制面。

## Observed

基线 main `a0d187ace03d6e56b79b50a7a601c91b359b7955`，13个 issue 独立 space/branch/worktree，联合候选位于 `feat/SP-241-open-issues-validation`，实现整合提交`51d505bb`。主目录已有参考追踪 WIP 保留。上述验证是在本地交付时完成。用户随后明确授权推送分支并创建PR；进入远端审查/CI阶段，保留本地证据原始时间边界。没有合并、单独发送issue回复、关闭、发布或切换用户主目录。增量[GitHub快照](20261028-open-issues.json)和[最终本地复查](20261028-open-issues-delivery.json)均为13项。实现SHA、binary与原始日志摘要在[证据索引](20261028-evidence.json)。

| Issue | Space | 处理结果与验收边界 |
| --- | --- | --- |
| #214 | SP-240 | 既有通用删除已经取消；核对只读 inspect/preview 和 confirm 拒绝，保留原缓存来源未知。未删缓存。 |
| #221 | SP-238 | 穿过非输入焦点包装层，停在已聚焦公共 UIKeyInput owner，不能误落 UISearchBar 或内部 field editor，也不能抢焦点。 |
| #222 | SP-237 | 核对 v0.2.33 已发布的 Device Hub HID 路线与真实历史证据；本轮不冒充新增设备验收。 |
| #223 | SP-236 | UIKit 公开 activation 成功，或 typed unsupported + 精确恢复；不猜私有 target/action、不点 sheet 后内容。 |
| #224 | SP-235 | 显式 simulator doctor 独立报告 resize/display probes；拒绝输出绑定所选目标，unknown 不放行截图/输入。 |
| #225 | SP-234 | Runner launch/transport/health/UIAutomation 分阶段；有界诊断 DTX 拒绝和提前退出，不泄露原始日志。 |
| #226 | SP-228 | devicectl bundle 后仅在有 app 参数时插入 `--`，保留 dash-prefixed 参数原值。 |
| #227 | SP-229 | Android结构化warning/error及Gradle failure分类，timeout使用实际单调时钟耗时。 |
| #228 | SP-230 | adb状态、boot completed、PackageManager均满足才ready；远端截图文件错误不误报host adb缺失。 |
| #229 | SP-231 | 每次dump唯一XML路径且要求同路径成功回执；拒绝ERROR/null-root/空或无效XML，不回退旧树。 |
| #230 | SP-239 | 前台app未知方向可只读观察/截图，明确partial与geometryError，禁坐标并使旧ID失效；无效窗口仍拒绝。 |
| #231 | SP-232 | sim logs增量写独占0600产物；signal/timeout/非零/不完整/大小上限保留partial单一JSON。 |
| #232 | SP-233 | 澄清devicectl/Device Hub/Runner职责与现有字段，不虚构统一DTO或新backend。 |

## Evidence

| 检查 | 结果 | 证据范围 |
| --- | --- | --- |
| 完整 CLI native Debug | 通过：1563 Swift Testing + 94 XCTest，0失败 | `.build/cli-full-v3.log`；覆盖HTTP/命令分发、schema、fake host与新增用例 |
| 根包 macOS | 通过：401 Swift Testing + 7 XCTest，0失败 | `.build/local-gate.log`；不含UIKit执行 |
| App-hosted UIKit | 通过：7 tests，0失败 | `.build/uikit-combined-v2.jsonl` + xcresult；iOS27.0/Xcode27.1，#221三项+#223四项 |
| Runner protocol | 通过：32 XCTest，0失败 | `.build/runner-protocol.log`；shipped资源独立包 |
| Runner跨App geometry fixture | 通过：1 XCTest，0失败 | `.build/runner-geometry-v2.jsonl` + xcresult；真实Simulator、注入未知方向，不是原物理设备复现 |
| 真实Simulator doctor/logs | 通过 | [脱敏结果](20261028-real-simulator.json)：独立目标diagnostics；自有日志子进程SIGKILL后607402字节保留、0600、单一partial失败、shutdown恢复成功 |
| 最终docs门禁 | 通过 | `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`；241个space |
| Runner closed package | 通过：11文件manifest | `verify-ios-runner-package.py --root Sources/TritonKitCLI/Resources/ios-runner` |
| 本地总门禁 | 通过：exit 0 | `.build/local-gate.log`；Release CLI、CLI smoke、Harmony host smoke、iOS runtime observe smoke、docs/diff；可选裸Xcode步骤跳过（如下说明） |

Android #227/#228/#229 增加了[已发布0.2.33与候选CLI的黑盒反证](20261028-cli-blackbox-red-green.json)：同一隔离fake Gradle/ADB，旧版分别出现duration=0与错误计数2、boot=0却ready、null-root仍返回stale节点；候选分别测得2058ms且0error/1warning、device_not_ready、hierarchy_unavailable且无旧节点。3项旧版全部失败、候选全部满足要求。[复跑脚本](20261028-blackbox-regression.py)要求显式旧版binary，并校验版本，不接触真实设备。

#226在独立SP-228恢复旧构造函数完成red(exit1)→恢复候选green(exit0)，42项TKHostAdapterModelsTests通过。#223旧实现typed refusal断言失败，再以真实App-hosted pageSheet验收4项通过。#230协议新模型先编译red，后32项green。其余候选的先前冷编译中止未执行行为red，不能从测试源码推定旧版结果；其新用例已随完整CLI实际通过。

## Gaps / Remaining risk

- #224 的报告工具链 Xcode 26.6、本次宿主 Xcode 27.1须区分。目标绑定诊断不证明未知resize可安全执行。
- #225/#230 的物理设备 DTX 与方向报告，只有 fixture 可控反例；仍需原设备按恢复步骤复验。Simulator XCTest 不证明签名/DDI/物理传输。
- #228/#229 慢启动/服务失败/XML污染使用隔离 fake-adb；不宣称实际 Android 设备复现。
- #222 系统告警、多击/长按及跨工具链未验证项保留；#223 typed unsupported 是 issue 允许的交付结果，不能声称所有 UIBarButtonItem 可编程激活。
- #214 删除不在当前产品范围，不恢复未经证明的安全删除；远端关闭理由需按 not planned 独立说明。

## Fixes made during integration

- 初始多个SwiftPM默认swiftbuild并行编译造成宿主过载；精确停止自有构建，切为单个联合native、jobs=2。被中止测试没有结果。
- #221首次descendant-first深入私有field editor；真实App-hosted测试发现OID错配，改为优先已聚焦UIKeyInput owner，保留原身份断言。
- UIKit根包编译发现既有Foundation.Process shell测试未限定macOS，添加平台条件；不用macOS跳过UIKit的结果替代实际执行。
- #231信号常量断言统一Int类型；非零退出优先保留sim_logs_failed原因，继承pipe不完整仍保留partial证据。

- Runner既有volumeUp/Down在Simulator SDK不可编译，按平台编译；Simulator明确501不支持，并在probe报告实际支持按钮，真机保持原API。fixture只校验真机能力声明，不操作真机音量。
- 完整CLI首轮暴露sim logs父schema缺4个真实已有参数和2个failure code、新Runner与partial-output recovery分类遗漏；补生产schema/共享分类并保留严格闭包测试，完整v3通过。
- timeout fixture的0.2s预算导致首行前被终止（stdout/stderr均空，具体调度阶段未知）；使用直接/bin/sh和2s预算，强化真实warning内容及duration>=2000断言后通过。

## Reproduction

CLI联合测试：`swift test --package-path CLI --build-system native --jobs 2 --no-parallel`。UIKit宿主生成器见 [SP-236](../../SP-236-issue-223-bar-button-activation/plans/generate-test-host.py)，由 `triton xcode test` 显式选择专用Simulator运行。

local门禁通过本地ignored wrapper只向swift build/test添加 `--build-system native --jobs 2`，其余命令和断言不改。local门禁的可选裸xcodebuild步骤显式 `TRITON_VERIFY_XCODE=0` 跳过，由上面的两项真实Triton Xcode构建/测试提供iOS编译证据；这不是门禁内该步骤通过。设备用例串行执行；raw日志保留`.build`，公开摘要不复制设备ID、私有路径或原生日志。最终docs检查和候选Git身份见随附证据索引。
