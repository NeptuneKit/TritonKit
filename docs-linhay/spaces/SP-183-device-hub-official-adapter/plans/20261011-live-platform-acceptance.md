# 专门平台真实验收

用户于 2026-10-11 要求开始真实验收。本轮先在新建的专用 tvOS/watchOS Simulator 上执行；不选择业务实例，不执行真机配对、解除配对或诊断采集。已授权测试通过后本地合并，未授权推送或发布。

## 验收前发现

此前 runner gate 的 fixture 测试不能证明可执行链路：未传 action/delta/nonce 给 XCTest、误将 xcodebuild stdout 当 JSON、缺持久审计、失败退出码与未知动作状态不准确。先修复这些缺陷，再验收。

## BDD

- Given 专用 Simulator、独立 app/UI-test 和新结果目录，When Triton 执行一个精确测试方法，Then 只向该实例发送一次请求动作，并保存请求与审计、原生 xcresult 和唯一结果 attachment。
- Given tvOS 确定性焦点页面，When 方向/选择/菜单输入，Then 分别校验真实焦点/详情/返回状态，不能把 press 返回当业务完成。
- Given watchOS SDK 和 runtime，When 构建专用测试，Then 以实际编译和 test runner 支持决定可验收项；不以 SDK 符号存在宣称 UI test 可运行。
- Given 参数/身份/nonce/后置状态冲突，Then 拒绝成功；启动前失败与启动后未知分开，退出非零，不重试输入。
- Given 验收结束，Then 专用实例关闭、既有实例名称/状态保持不变，公开证据脱敏且原始证据仅私有保存。

## 当前执行

独立 worktree `SP-183-live-platform-acceptance`；主控串行运行设备与 Xcode build/test。主控重新构建当前源码 CLI 后固定使用其绝对路径。初始 runtime 只有 iOS 27.0/27.1；已尝试 Apple 官方 tvOS runtime 下载，后续按实际结果记录。

## 原生执行事实

- tvOS/watchOS 的独立 App/UI-test 原生 `build-for-testing` 均通过，生成各自 `.xctestrun`；fallback 原因为当前 Triton xcode schema 不提供 build-for-testing。
- 通过 `triton xcode test` 执行本机 XCTest 附件传输探针，1 个测试通过，无设备输入；导出实际 xcresult 揭示 test-id 必须包含 `()`，附件 suggestedHumanReadableName 带序号和 UUID。此证据只证明原生附件通道，不能升级为 watch/tvOS 输入成功。
- 修复 native runtime ID 被 display runtime 替代的分类缺陷；新 CLI 现场清单从 18 unknown 恢复为 18 iOS，未依据设备名称猜测。
- tvOS 官方下载两次、watchOS 一次均 exit 70，MobileAsset 网络错误 47；Apple 下载服务连接被重置。当前不再重复下载、不改网络设置、不换非官方镜像。
- 未创建、启动、安装或输入到任何 Simulator；未做真机写入/诊断采集。保留 worktree 的私有构建产物以便 runtime 恢复后直接继续。

[脱敏原生验证摘要](20261011-live-platform-verification.json)记录成功与阻塞分层。

## 回归与现场拒绝路径

完整 CLI 1153 Swift Testing + 26 XCTest、根包 314 Swift Testing + 7 XCTest 均通过；`verify.sh --ci-docs`、`check-docs.sh` 和 `TRITON_VERIFY_XCODE=0 verify.sh --local` 通过。通用 iOS build 明确跳过；双平台专用 test build 已单独实际通过。新 CLI 使用原生构建 xctestrun，面对不存在 UDID / 现有 iOS UDID + tvOS 请求均在 xcodebuild 前拒绝，返回一个 JSON、exit 1、not_started/false、unverified 和对应稳定码，0700/0600 intent/completion 已核实。前后比对现有18个 Simulator 名称/状态一致。

Runner 失败码已纳入 CLI schema 及共享恢复分类；所有 runner 失败仅引导 diagnose/plan，避免对超时或未知状态自动重放输入。相应回归覆盖完整失败码集合。
