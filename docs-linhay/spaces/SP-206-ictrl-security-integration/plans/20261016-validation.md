# SP-206 冻结联合候选验证

日期2026-10-16（Asia/Shanghai）；集成worktree `../TritonKit-worktrees/SP-206-ictrl-security-integration`，基线`dd613a994abe45aa14e072c381662a0e3d868f03`。环境macOS27.0.1、Apple Swift6.4、arm64。源冻结与联合产品SHA清单分别见 [source-freeze](20261016-source-freeze.json)、[joint-candidate](20261016-joint-candidate.json)；阶段为本地实现/联合验收，后续main整合另记。

## 实际命令与结果

原始日志位于本worktree `.build/sp206-validation/`。所有测试与同一scratch构建串行；旧错反证使用独立scratch和精确历史源码，不回退共享工作区。下列focused与full重复，不相加计数。

| 检查 | 命令/日志 | 结果 |
| --- | --- | --- |
| 聚焦 | `TRITON_TEST_BONJOUR=1 TRITON_CLI_PATH=$PWD/CLI/.build/debug/triton swift test --package-path CLI --no-parallel --disable-automatic-resolution -j 4 --filter 'IOSRunner&#124;Serve(Command&#124;Discovery)Tests&#124;ServerResponseLoggingTests'` / focused.log | 80 Swift Testing+18 XCTest通过，包括真实Bonjour、共享deadline、错绑回包 |
| 完整CLI | 上述命令去掉filter / cli-full-frozen.log | 1451 Swift Testing、144 suites及59 XCTest通过，真实Bonjour显式开启 |
| 根SDK Debug | `TRITON_TEST_BONJOUR=1 swift test --no-parallel -j 4` / root-debug.log | SDK93+shared287 Swift Testing、5 XCTest通过，真实多候选/无候选浏览包含在内 |
| 根SDK Release | `swift test -c release --no-parallel -j 4` / root-release.log | SDK92+shared287 Swift Testing、5 XCTest通过；Release默认/显式发现均no-op |
| 随包生产server | `swift test --package-path Sources/TritonKitCLI/Resources/ios-runner --scratch-path .build/runner-protocol --no-parallel -j 4` / runner-protocol.log | 29 XCTest通过：全部11路由错secret/session/method/过期；8 UI路由出队过期0执行；篡改/重放/合法控制组 |
| 资源严格校验 | `python3 docs-linhay/scripts/verify-ios-runner-package.py --root Sources/TritonKitCLI/Resources/ios-runner`、同命令Release实际bundle目录、`--self-test` | 源和Release随包11文件一致；9打包负例通过；两份channel源码逐字一致 |
| Debug/Release进程smoke | `python3 docs-linhay/spaces/SP-203-ictrl-discovery-hardening/plans/verify-serve-discovery.py <候选triton> <本次JSON>` | 各7 checks通过；自建loopback端口、默认不广播、非法配置、HTTP/CLI状态与伪造身份降级、退出清理 |
| 本地总门禁 | `TRITON_VERIFY_XCODE=0 TRITON_IOS_RUNTIME_SMOKE_PORT=30206 docs-linhay/scripts/verify.sh --local` / local.log | 原脚本通过：依赖边界、Debug隔离、根包、Release CLI、CLI/Harmony/iOS mock smoke、docs/diff；可选Simulator build明确跳过 |
| 单合法信封 | `json.loads`解析门禁evidence/verify失败stdout | 两份均为单一JSON、ok=false/validation_failed；HTTP/CLI status内容另经实际进程比对 |
| 文档 | `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` | 206 spaces、28治理fixture及其他契约检查通过；SP-201仅最小登记后再次通过 |
| 无签名iOS SDK | 候选`triton xcode build --for-testing --sdk iphoneos --destination generic/platform=iOS`，关闭CODE_SIGNING_ALLOWED/REQUIRED；私有资源副本，独立DerivedData与新xctestproducts | build-for-testing通过，两测试target和真实UIKit executor编译；无设备运行 |

Xcode首次底层build成功，但新增 `project.xcworkspace/xcshareddata/swiftpm/configuration` 等空目录改变源码树摘要，prepared snapshot返回identity_mismatch/exit1；未把底层成功冒充整条命令通过。文件内容与原11文件一致，目录稳定后用新artifact与manifest重建，CLI exit0/ok=true。分发资源未受影响、严格校验仍通过。后续使用私有副本并在新目录稳定后重新准备，不能修改manifest hash或放宽资源白名单。

## 隔离旧错与历史证据

- SDK：`git archive dd613a99`导出原SDK/shared/Package；抽取本联合候选的defaultEnvironmentDoesNotBrowse测试原样运行，编译通过后1 test/3行为断言失败（resolver调用1、采用untrusted.local:19426）。新候选同测试通过。记录见 [旧SDK失败摘要](20261016-sdk-legacy-red.txt) 与 [输入SHA](20261016-negative-inputs.json)。这替代独立会话“7 issues”但原始日志未找到的证据缺口。
- Runner：原Wire/Transport直接来自`git show dd613a99`；隔离package运行相同恶意监听器场景，1 XCTest/4失败：泄露token/Bearer并接受伪echo，新候选拒绝且不重试。见 [旧Runner失败摘要](20261016-runner-legacy-red.txt) 与输入SHA。该测试是真实socket，不是parser。
- 日志：复核SP-204原始red-tests.log，编译通过、4 tests中3失败/8 issues；未知与普通响应输出100188/200298 UTF-8 bytes、hierarchy信息泄露、id0仍静默。历史日志未包含source/test SHA，不能单凭日志证明完整候选；输出与基线handler对应。联合候选真实handleResponse隐私/字节上限/业务payload相等测试已通过。
- 日志补证：主控另抽取精确dd613与联合候选的handleResponse函数，复用同一合成秘密、真实shared消息编码和不进入场景的UI/cache空依赖；新函数两条unknown/default路径exit0，旧函数编译成功后秘密泄露断言失败exit133。见[输入SHA](20261016-log-negative-inputs.json)与[结果](20261016-log-negative-result.json)。此窄反证不冒充全服务或缓存端到端；完整联合handler测试承担后者范围。
- 伪造身份：SP-203 forged-status-red.log编译后1 test/2 issues，针对开发中DTO缺decoder；dd613基线尚无DTO，不能误写成精确基线反证。
- 旧服务UI过期执行：SP-205已留旧生产server抽取反证；本次29项随包与CLI真实互通重新证明现候选拒绝。旧证据保持抽取+注入clock/UI计数范围。

## 风险与阶段

未执行真实iOS App本地网络权限/接入、Simulator XCTest或UI动作、USB真机、签名、DDI、双架构发布、安装接替、用户场景验收。未运行iCTRL、未新增外部依赖、未修改上游监控；本机既有固定版本SwiftPM依赖解析不代表新增依赖。发现策略不提供embedded身份认证；Runner证明会话密钥持有，不证明进程/物理设备身份，不防透明密文转发、DoS或凭据文件泄露。

本期共有实现/测试/文档变更按清单提交；SP-201只提交用户另外授权的最小登记，其完整WIP保留，main最终复核与commit见space后续记录。


## 本地 main 合并后复核

实现`6bfeba80`、文档`6d41729a`；main文档检查点`2cbd69c8`保留工作树WIP，再以`0a246d00`完成合并。主仓产品SHA与冻结联合候选全部相等；本次候选未新增产品修复，因此没有用主仓旧二进制替代验证。

- 在实际main重新运行完整CLI：1451 Swift Testing/144 suites+59 XCTest全部通过（`TRITON_TEST_BONJOUR=1`、`TRITON_CLI_PATH=$PWD/CLI/.build/debug/triton`、`--no-parallel`）。
- main原始`verify.sh --local`通过，含本地Release重建、根包和smoke；`TRITON_VERIFY_XCODE=0`明确跳过设备构建，资源副本通用iOS编译的证据仍单列。
- main `verify.sh --ci-docs`、独立`check-docs.sh`、源与Release实际bundle严格校验、Release实际serve进程7项检查、`git diff --check`均通过。main含独立SP-207 WIP，所以文档门禁207 spaces；本期提交树单独导出校验206 spaces+28治理fixture通过，不依赖SP-201完整WIP或SP-207文件。
- 主仓无关WIP42文件SHA在合并后核对原字节保留；共享索引/参考档案/memory按本期hunk合并，SP-207后续授权、模型规则与ops变更不覆盖、不提交。SP-201完整README/设计/验收保留，仅用户另行授权的最小登记进入本期提交。
- 日志：主仓`.build/sp206-main-validation/`；主控`.build/sp206-validation/`。本地完成，未push/tag/release/运行接替。
