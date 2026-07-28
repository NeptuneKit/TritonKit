# SP-141 Packaged Web Simulator Input

状态：待发布（v0.2.16）

## 背景

`triton web --simulator-only` 的 `/web/target-registry` 会把就绪 iOS Simulator 暴露为 `canInput=true`，且列出 host `tap`、`swipe`、`longPress` 能力；但打包版 Web server 的 `/web/host-input` 只接受 iOS 真机 App runtime mirror，导致用户点击模拟器画面后收到：

```text
Web host input is only enabled for iOS real-device App runtime mirror targets in this bridge.
```

Vite dev bridge 已能把 simulator/emulator 输入转发到 `triton serve /web/input`，缺口仅存在于 `Sources/TritonKitCLI/CLIWebRuntime.swift` 的打包版 bridge。

## 影响层

- CLI：修复打包版 `triton web` 内建 HTTP bridge 的 host target 输入分发。
- HTTP：保持 `/web/host-input` 请求 DTO 与 `/web/input?target=host:<platform>:<selector>` 执行契约一致。
- Web：继续消费 target registry 能力并提交既有手势 DTO，不新增 UI 或业务状态。
- 不涉及 Wails、桌面壳、embedded SDK、真机安装或公开远端 HTTP 产品面。

## BDD

### 场景 1：打包版 Web 向 iOS Simulator 发送 host input

- Given target registry 返回就绪的 `host:ios:<udid>`，并声明 `tap` 为 host supported
- When Web 向 `/web/host-input?platform=ios&target=<udid>&scope=simulator&kind=simulator&source=host` POST `TKInputRequest`
- Then bridge 必须进入既有 `runWebHostDeviceInput` host adapter
- And 不得返回仅真机 runtime mirror 可用的 unsupported 文案

### 场景 2：iOS 真机 runtime mirror 保持原行为

- Given target 为 `ios-real:*` 且 scope/kind/source 表示 runtime mirror
- When Web 提交 input
- Then bridge 继续解析无 `simulatorUDID` 的 connected runtime target，并通过 runtime `/input` 执行

### 场景 3：无效平台不伪造成功

- Given platform 不属于 iOS、Android、Harmony
- When Web 提交 input
- Then bridge 返回明确 unsupported 结果，不执行 host adapter

## 技术选择

- 在 Swift packaged bridge 中复用 `runWebHostDeviceInput(id:input:)`，host target ID 统一由 `host:<platform>:<target>` 构造。
- runtime mirror 判断继续使用 `isWebIOSRuntimeMirror`，避免真机错误落入 Simulator host adapter。
- 先用 focused Swift 测试固定分流合同，再做真实 `triton web` HTTP + 浏览器 smoke。

## 非目标

- 不新增 `pinch`、`rotate`、multi-touch 能力。
- 不改变 Baguette host-HID adapter 的支持边界或坐标算法。
- 不把 Web 提升为新的独立业务控制面；执行仍复用 CLI/HTTP 事实入口。
- 不提交、推送、发布或替换已发布 tag。

## 验收

- `SingleDeviceWebPageTests` 覆盖 packaged bridge 的 simulator host 路由、真机 runtime mirror 与非法平台。
- `swift test --package-path CLI --filter SingleDeviceWebPageTests`
- `npm test`、`npm run build`
- 用当前就绪 Simulator 启动修复后的本地 `triton web`，POST tap 不再返回 real-device-only 错误；浏览器页面点击显示成功状态并刷新画面。
- `git diff --check`
- `docs-linhay/scripts/check-docs.sh`

## 实现结果

- `CLIWebRuntime.swift` 新增 `WebHostInputBridgeRoute`：
  - iOS 真机 selector 或 runtime metadata 进入 `.runtimeMirror`，保留既有 embedded App runtime 输入；
  - iOS Simulator、Android Emulator、Harmony Emulator 进入 `.host(id:)`，复用 `runWebHostDeviceInput`；
  - 空 target、未知平台或无充分来源标记进入 `.unsupported`。
- `SingleDeviceWebPageTests` 新增 packaged bridge 分流测试，覆盖 iOS Simulator、Android Emulator、`ios-real:*` 与非法平台。
- 未修改 React 手势 DTO、坐标转换、Baguette/ADB/HDC adapter 或 capability 列表。

## 验证结果

- 红灯：新增测试首次运行因 `webHostInputBridgeRoute` 不存在而编译失败，证明测试命中缺口。
- `swift test --package-path CLI --scratch-path .build/sp141-red --filter SingleDeviceWebPageTests`：27 tests passed。
- `TRITONKIT_TRITON_BIN=<sp141-debug-triton> npm test`：82 tests passed；Vite 并发测试结束时仍有既有 dependency-scan restart 噪声，不影响结果。
- `TRITONKIT_TRITON_BIN=<sp141-debug-triton> npm run build`：通过，3164 modules transformed；保留既有大 chunk warning。
- 真实 packaged HTTP smoke：本地修复版运行于隔离端口 `34129`，对当前就绪 iOS Simulator POST tap 返回 `ok=true`、`action=tap`，message 为 `iOS Simulator tap was submitted through Triton host-HID adapter.`。
- Playwright 页面 smoke：`Triton Inspector` 正常加载，target 为 `Overloaded Douyin Playback iPhone 17`；点击真实画面后 UI 显示 `tap 603,1311`，console 0 error / 0 warning。
- 原地址接管：确认旧监听进程为 Homebrew `triton 0.2.15` 后，仅终止该 `34127` listener，并以本地修复版 debug binary 在同一 `http://127.0.0.1:34127/` 重新启动；未停止或重启 `19421`、Simulator 与现有 App。对原地址重复 HTTP tap 与 Playwright 点击，均得到相同成功结果。
- CLI 全量测试曾以隔离 scratch 启动，但仓库既有测试硬编码查找 `CLI/.build`，同时已有 schema/device-proxy/Harmony unrelated failures；运行约 3 分钟后无新增输出，已停止，未把它计为本次通过证据。

## 证据

- [packaged Web Simulator tap success](./screenshots/20260728-packaged-web-simulator-tap-success-v01.png)

## 后续边界

- 当前安装的 Homebrew `triton 0.2.15` 不含此源码修复；本会话已由本地 debug binary 受控接管 `34127`，源码修复与版本入口已进入 `v0.2.16` 发布准备。
- 审计同时发现 keyboard relay、LIVE 门禁与 `readonly/canInput` 语义存在历史漂移，但不属于本次 simulator packaged bridge 缺口，未顺手扩面。
