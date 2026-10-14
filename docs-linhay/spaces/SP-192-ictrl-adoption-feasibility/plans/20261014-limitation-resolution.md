# SP-192 构建与 iOS 回归限制收口

状态：完成。Android 完整构建、iOS 115 项回归及本地总门禁均通过。本阶段用户授权“你来处理限制”；当时沿用 SP-192 worktree，保留此前五机制实现，不提交、合并、发布或操作用户业务 App。

## 影响层与验收

- Android Bridge：恢复完整 Gradle 依赖解析，真实执行 testDebugUnitTest 与 assembleDebug；不以直接 Kotlin 编译代替 APK 构建、不跳过测试、不改变版本或默认启用第三方 mirror。
- iOS runtime tests：修复三项 alert responder / modal 路由测试的真实窗口夹具和一项 UIView.alpha / CALayer.opacity 联动契约；真实 iOS Simulator package suite 全部通过。若回归发现额外窗口焦点问题，按实际证据修复，不放宽断言。
- 文档与治理：保留原始失败与基线对照为历史，更新最终结果、space/索引/memory/public skill 必要模式。

## BDD

1. Given Google Maven 直连超时与不完整 Gradle metadata，When 用可验证的官方来源或显式本机网络通路恢复依赖，Then 同版本 Gradle 可执行完整 JVM suite 并生成有效 Debug APK，输出不包含代理凭据。
2. Given 真实 UIAlertController responder 层级及同窗口可命中的背景 collection cell，When 对已挂载的 alert 目标触发 tap，Then 不回落选中背景 cell；支持的 accessibility activation 仅执行一次。hostless 单测不宣称完整 UIKit presentation 验收。
3. Given UIKit alpha 与 backing layer opacity 同步，When 单独或同批 patch 两个属性，Then 按已定义执行顺序得到真实值、报告真实 applied 字段，测试不要求同一个 backing value 同时等于两个不同值。

## 分工

- Android subagent：Tools/AndroidBridge 构建配置与私有依赖恢复脚本，不运行 build。
- iOS subagent：alert / property patch tests，必要的 LegacyInspection 窄修复，不运行 build。
- 主控：窗口回归审计、构建与设备验证串行、文档/索引/memory与最终门禁。

## 当前证据

此前完整 CLI 1250项、本地门禁通过。iOS 109passed/4failed，四项均在原始 main98passed/5failed中重现；新增预算场景通过。Android全部16主源码直接编译与纯JVM7项通过，Gradle APK/JVM coupled尚未完成。上述结果是历史基线，不代替本轮全绿验收。

## Android 复核结果

- 官方 Google Maven 源恢复可达，沿用现有 AGP 8.5.0 / Kotlin 版本及仓库配置。未启用第三方镜像、私有备用源，也未改变 TLS 校验。
- 主控串行执行 `./gradlew -Dorg.gradle.internal.http.connectionTimeout=10000 -Dorg.gradle.internal.http.socketTimeout=20000 :app:testDebugUnitTest :app:assembleDebug`，43 秒完成，43 个任务执行。
- 8 个 JUnit XML suite：52 项、0 failures、0 errors、0 skipped；包括此前缺依赖的 HTTP / MockK / JSON 场景。
- Debug APK：`Tools/AndroidBridge/app/build/outputs/apk/debug/app-debug.apk`，5,380,381 bytes。原始日志、XML 汇总、checksum 和未执行的私有备用脚本仅留 `.triton/sp192-validation/`。
- 此结果解除 APK / JVM 测试构建限制，不代替 Android Emulator 或真机上的运行验收。

## iOS 诊断过程

- 属性测试修正后已通过：原组合 patch 中 view.alpha=0.4 与 layer.opacity=0.6 作用于同一 backing value，handler 既有 view → layer 顺序决定最终值；新增两个独立入口联动测试，不修改产品行为。
- 第一版真实 present 等待、第二版 completion + 主 run loop / transaction 推进，三项 alert 均未达到 completion 前置条件；保留失败，不延长 deadline、不放宽挂载检查。两次测试流程跑完但 Xcode 未正常收口，超时产生的不完整 xcresult 不计为完整验收。
- 该 hostless runner 无法提供正常 App presentation 生命周期；最终夹具以真实 alert responder/window 夹具隔离路由边界，并要求背景 candidate 实际存在。实际 App 弹窗展示属于带 host 的集成场景，本轮不因此宣称已验证。

## iOS 最终回归

- 主控通过 `triton xcode test --package . --scheme TritonKit-Package --only-testing TritonKitTests` 在实际 iPhone 17 / iOS 27.0 Simulator 执行全部 runtime package tests；使用独立 DerivedData 与全新 result bundle。
- 进程 exit 0，完整 xcresult：115 passed、0 failed、0 skipped、0 expected failures；`triton xcresult summary` 返回 Passed，inline topFailures 为空。Swift Testing 内部计数 113 加另两项测试为 xcresult 总计 115，不混用计数。
- 三项 alert 保留 unsupported / accessibility activation / 不选择背景 cell 的全部断言；每项先验证真实 responder、window 与同坐标 background fallback candidate。新增 callback 只调用一次的断言。此次只修复 test fixture，没有改变生产输入安全检查。
- 属性测试覆盖组合 view→layer patch 顺序、view.alpha 独立入口及 layer.opacity 独立入口，真实 backing 联动与 applied 字段都通过。
- 该结果解除此前四项既有测试失败；实际 App presentation、Android/Harmony 设备运行、OCR 输入坐标校准等未测边界仍保留。

## 最终门禁

- `docs-linhay/scripts/verify.sh --local` 复跑 exit 0：SwiftPM 依赖边界、iOS Debug 隔离、macOS root tests（59 runtime / 274 shared）、Release CLI build / smoke、Harmony与iOS runtime fixture smoke、真实 iOS Simulator build、docs 与 diff 检查通过。
- worktree 与主工作区的 `verify.sh --ci-docs`、独立 `check-docs.sh`、`git diff --check` 均通过；仅同步本 space 文档、索引行、memory 与一项内部 skill 模式，保留其他任务内容。
- CLI/共享实现未在本轮改变，沿用此前本次产物下完整 CLI 1250 项 / 117 suites 的通过结果；本轮改变的 UIKit 测试已在实际 iOS suite 完整执行。
- 限制收口当时源码与测试保留于独立 worktree，未提交或合并；随后用户授权本地提交/main 集成，实际结果见[整理计划](./20261014-integration.md)。全程未推送、发布或操作用户业务 App。
