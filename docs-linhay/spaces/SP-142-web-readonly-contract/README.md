# SP-142 Web Readonly Contract

## 状态

- 状态：已完成（本地 checkpoint）。
- 负责人：Codex。
- Branch：`feat/SP-142-web-readonly-contract`。
- Worktree：`../TritonKit-worktrees/SP-142-web-readonly-contract/`。
- 基线：`main@d016979d`。

## 裁决

**Adopt：`triton web` 与 `/web/*` 只提供 DTO、诊断和可视化；浏览器不得发起输入、节点属性修改或其它业务写操作。**

这一选择保持 Hybrid 的事实入口：需要控制时由 agent/操作者显式调用 `triton act …` 或既有通用 HTTP runtime 契约；Web mock 仅展示其可读结果。它修复 README、AGENTS 和实现中已经存在的边界冲突，不重新定义 Web/Wails 为控制产品。

## 边界

包括：

- `triton serve` 的 `/web/input`、`/web/node-property` 返回稳定、单一的只读 JSON error envelope，且不解析或转发输入/patch body。
- `triton web` packaged bridge 的 `/web/host-input` 和 `/web/node-property` 同样拒绝写请求，不调用 runtime、host adapter 或自管 `triton serve`。
- React mock 和 single-device HTML 去除写入分发；属性 patch 只保留本地草案与复制，镜像不再伪造动作成功。
- 单元/Node contract tests 覆盖 endpoint、405、稳定错误码、无上游转发与 HTML 不含写入口。
- 受管的 Web bridge `triton serve` 固定绑定 `127.0.0.1`；不会因 real-device mirror、环境变量或错误提示自动打开 LAN-facing server。真机 runtime 只可走另行批准的显式 CLI/HTTP workflow。

不包括：

- 通用 `/input` HTTP runtime 契约、CLI `act`、`debug patch-node` 或 host adapter 的控制能力；它们仍是显式机器控制面。
- 新 Web/Wails 控制产品、设备/Simulator/server 生命周期、Android/Harmony 扩张、testrec/workspace，或 #164 evidence WIP。

## BDD 验收

1. Given 任意 POST `/web/input` 或 `/web/node-property`，When server 收到请求，Then 返回 405 的单一 `TKCLIErrorResponse`、稳定只读 code 和 CLI action hint，且不解析/发送 payload。
2. Given packaged Web 或 Vite dev bridge 收到 `/web/host-input` 或 `/web/node-property` 写请求，When 请求到达，Then 返回同一类 405 readonly envelope，且不会启动、探测或转发 Triton server。
3. Given Web 用户点击镜像或查看节点属性，When 页面刷新，Then 仍可读取 DTO/截图/层级，但不出现可执行 POST 分发；页面明确显示 readonly 状态。
4. Given agent 需要实际控制，When 读取 error hint，Then 能得到 CLI action 路径；本 slice 不删除该 CLI/HTTP 控制入口。
5. Given Web bridge 需要 target registry 或其它只读 runtime data，When 它自管 `triton serve`，Then 只能以 `127.0.0.1:19421` 绑定；real-device mirror unavailable 时不得建议 `0.0.0.0` / `TRITON_HOST`，也不得自动提升为 LAN-facing server。

## 验证与停止条件

- 先让 Swift / Node focused tests 证明当前 POST 与写入标记为红，再只做最小路由和 UI 收敛。
- 计划执行 `WebCommandTests`、`SingleDeviceWebPageTests`、相应 Web Node tests、`npm run build`、`git diff --check` 与 docs gate；不启动 dev server、`triton serve`、Simulator、Xcode 或设备。
- 当前 branch 从 `main@d016979d` 独立分出，而当前 `main` 已发布并占用 `SP-141-packaged-web-simulator-input`。本 branch 单独应用时会产生 docs registry 空档；未来 integration 必须保留已发布 SP-141、以本 slice 作为合法 SP-142 追加，不能占位、复制或重写历史。

## 已知风险

- 历史 Web mock 曾经承载过 host input / runtime node patch；本期将其移出浏览器，可能改变旧手工 demo 的行为。这是有意的安全收敛，CLI/通用 HTTP 控制面保持可用。
- `/web/*` 以外的通用 `/input` 仍是运行时控制 API；本期不把它误称为 Web readonly route，也不改其兼容性。
- Web 的**读取** bridge 仍可能为 target registry、stream 或 hierarchy 触发既有的 loopback `triton serve` 管理逻辑；本期不宣称“零宿主生命周期副作用”，但其不再绑定或建议 LAN-facing server。真机 runtime 的 LAN server / lifecycle 仍须另立产品与授权空间。

## 验证记录

- TDD red：新增 Swift readonly factory 断言后，`WebCommandTests` 因 `webReadonlyWriteResponse` 尚不存在而编译失败；随后以统一 factory 最小实现转绿。
- `swift test --package-path CLI --scratch-path .build/sp142-web-readonly-contract --filter 'WebCommandTests|SingleDeviceWebPageTests'`：49/49 通过；新增 Hummingbird `.router` 内存路由测试以畸形 JSON body 验证 5 条 browser write route 仍返回 405 + endpoint/code，不监听端口、不启动服务，也不会进入 payload 解析。
- `node --import ./dev/polyfill.mjs --test dev/iosSimulatorBridge.test.mjs dev/ios-bridge/nodePropertyRoute.test.mjs dev/currentWebContracts.test.mjs`：18/18 通过；Vite contract test 改为无 config/dependency scan 的 middleware loader，不依赖 `triton` binary 或常驻 dev server。
- loopback hardening TDD：先把 Web launch plan、bridge bind host、real-device runtime hint 与 static source contract 改为期望 `127.0.0.1`，得到 Swift 2 个断言失败和 Node 3 个失败；最小实现后 `WebCommandTests` 24/24、`iosSimulatorBridge + iosRuntimeMirrorBridge + currentWebContracts` 19/19 通过。受管 host 不再读取 `TRITONKIT_WEB_MANAGED_SERVE_HOST`，schema 输出明确它不会自动开启 LAN-facing runtime server。
- 复核：同一独立 scratch 的 `WebCommandTests|SingleDeviceWebPageTests|ServeCommandTests` 55/55 通过，`npm run build` 通过（仅既有 bundle 大小 warning）；release `swift build --product triton` 后，仅打印的 `triton web --print-command --json` 断言 `readonly=true`、`discovery.managedServeHost=127.0.0.1` 与受管 host 环境变量同为 loopback。未监听端口或启动任何 runtime。
- `check-docs.sh` 与 `verify.sh --ci-docs` 均仅因本 branch 缺少并行 SP-127–141 的历史登记而在 SP-142 连号处失败；不以占位目录、脚本放宽或改写已发布 SP-141 消除该治理信号。
- `TRITONKIT_TRITON_BIN=<SP-142 scratch triton> npm test`：75/75 通过。若不显式提供该测试专用 binary，12 个既有 Vite SSR suites 会在加载 Web dev bridge 时 fail fast；这不是 Web write contract 失败。全套仍有 Vite close 时的非致命 dependency-scan 噪声，命令 exit 为 0。
- `npm run build`：通过；仅保留既有 bundle 大小 warning。`antd usage Web/src --format json` 完成；`antd lint Web/src --format json` 仅报 5 条既有 static `message.*` / `ConfigProvider` context warning，本期删除两条写入路径后未新增 warning。
- `swift build --package-path CLI --scratch-path .build/sp142-web-readonly-contract-release -c release --product triton`：通过；仅输出既有 Simulator 私有 Objective-C selector warning。
- 未启动 `triton serve`、Vite dev server、Simulator、Xcode 或设备；#164 dirty evidence worktree 未读取或修改。

## 集成顺序

本 branch 从 `main@d016979d` 独立创建；当前 `main` 已有已发布的 `SP-141-packaged-web-simulator-input`。主控集成时必须以届时 main 为基线，保留该发布事实、将本 slice 作为 SP-142 处理并重跑 docs gate；不得复制、替换或重编号 SP-141，也不得用跳号登记伪造连续性。
