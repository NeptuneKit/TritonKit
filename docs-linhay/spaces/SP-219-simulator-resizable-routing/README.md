# SP-219 — Simulator Resizable display 路由

## 边界

来源为 [lycorp-jp/sim-use `42aa9a244f4e20fdd97ef8dd738fd34bb91cf671`](https://github.com/lycorp-jp/sim-use/commit/42aa9a244f4e20fdd97ef8dd738fd34bb91cf671)，对应 Xcode 27 Resize Mode 的 `Resizable` display。SP-214 已实现 fresh display topology 查询和未知时 fail-closed；本切片只补齐在**已确认、目标绑定的 Resizable display** 上执行 AX/触摸/视频的路由契约。

影响层是本机 iOS Simulator CLI/host adapter 与机器可读失败 DTO。不得扩展到真机、远端、设备云、Duo 全量控制、任意 display ID 或未经验证的回退；不得运行第三方代码、安装依赖或操作设备。

非目标文件面：Web/Wails 展示层、HTTP 新写控制面、Android/Harmony、发布包装。

## BDD / TDD

- Given fresh `appResize` 返回目标 UUID、`displayName=Resizable`、合法 display UUID 和 scene size，When 执行支持的 AX/触摸/视频动作，Then command 使用同一 fresh display identity，动作/捕获结果带可审计 route/display metadata。
- Given Resize Mode inactive，When 执行普通 Simulator 动作，Then 保持当前主 display 行为，不新增查询副作用以外的路由。
- Given display identity 缺失、target 不匹配、查询超时/不支持、状态在动作前变化或输出截断，When 请求动作，Then 单一机器可读 unknown/fail-closed envelope，0 个 AX/HID/video side effect。
- Given caller 伪造 `--display` 或跨目标复用缓存 display UUID，When 执行动作，Then 拒绝并报告 `ios_simulator_resize_display_identity_mismatch`。

## 文件面与验收

执行会话负责：`Sources/TritonKitCLI/CLIHostSimulatorResizeRuntime.swift`、`CLIHostSimulatorResizeCapture.swift`、AX/触摸/视频调用方及对应 `CLI/Tests/TritonKitCLITests/*Resize*` / contract tests；如需新小型模型文件需在本 space 记录。先补失败测试，再最小实现。

验收必须包含 focused offline fixtures：fresh probe identity、route propagation、unknown zero-side-effect、普通主 display 回归、机器可读错误单 envelope；运行受影响 CLI tests、`swift test --package-path CLI --no-parallel`（或明确失败原因）和 docs/diff 门禁。真实 Simulator/Xcode 运行仍是后续用户验收边界，性能数字仅标上游自述、不得冒充本地验证。

## 许可与风险

上游为 MIT（固定 HEAD 许可证已在 SP-207 原始证据保存）。只借鉴显示身份与 fail-closed 机制；不复制托管 Device Hub 或第三方运行时。最大风险是 Apple `devicectl`/`simctl` 在不同 Xcode 版本的 display 参数差异，未知时必须拒绝。

## 状态

评估可纳入，等待创建显式 `gpt-6.1-sol` 执行会话。主控 SP-220 负责真实 diff、测试证据、冲突处理和本地 main 合并；会话创建失败必须保留 pending，不回退模型。
