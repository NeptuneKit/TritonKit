# SP-163：iOS Simulator 前台坐标 tap 路由

## 边界

- 对应 GitHub issue：#200 `[Bug] Simulator coordinate tap resolves a background embedded runtime`
- 影响层：CLI `act tap` 的 selector/routing、agent-facing schema、focused tests 与文档；不新增 HTTP/Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-163-issue-200-simulator-foreground-runtime/`
- 分支：`feat/SP-163-issue-200-simulator-foreground-runtime`
- 基线：`origin/main@adbfc92c`
- 目标：显式 Simulator selector 的纯坐标 tap 不再通过“同 Simulator 唯一 embedded runtime”回退串到后台 App，而是进入已有、受约束的 iOS Simulator host-side tap path。

## 非目标

- 不读取、启动或修改真实 Simulator、业务 App、embedded runtime 或 host HID 状态。
- 不改变 canonical runtime target（`triton:ios-simulator:<udid>` 与 `/app:<bundle-id>`）的 embedded runtime 语义。
- 不把 host tap acknowledgement 宣称为业务完成；仍需 `observe` / `wait` / `screenshot` 验证。
- 不扩展到真机、远端设备、系统级 text/semantic selector 或 Web/Wails。

## BDD 验收

### 场景 1：`sim:<UDID>` 坐标 tap 使用 host-side path

- Given 用户显式传入 `--device sim:<UDID>` 与 `--at x,y`（或成对 `--x/--y`）
- When 未显式传 `--platform`
- Then CLI 将其识别为 iOS Simulator host selector，使用既有 host-side tap path，不查询 embedded `/targets`，也不返回与 hint 冲突的 `target_not_found`。

### 场景 2：裸 Simulator UDID 不回退到后台 runtime

- Given 用户显式传入形如 UUID 的裸 Simulator UDID 与纯坐标 selector
- And 同 Simulator 仅连接了后台或陈旧 embedded runtime
- When 执行 `act tap`
- Then CLI 进入同一受约束 host-side path，不以 simulatorUDID 唯一匹配回退到该 runtime。

### 场景 3：canonical runtime selector 保持精确

- Given 用户传入 `triton:ios-simulator:<UDID>` 或 `triton:ios-simulator:<UDID>/app:<bundle-id>`
- When 执行 embedded coordinate tap
- Then CLI 保持 runtime target 语义；app-scoped target 不存在时必须 fail-closed，不能改投同 Simulator 的其它 bundle。

### 场景 4：受约束范围与恢复信息一致

- Given selector 不是 `sim:<UDID>`、`booted`、`current` 或裸 UUID，或 tap 不是纯坐标
- Then 不自动切换 host-side path。
- Then schema/help 明确 Simulator selector 的 host routing、canonical runtime selector 的 embedded routing，以及 host acknowledgement 需后验验证。
- Then host-side failure 仍输出单一合法 JSON error envelope。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp163-200 --filter SimulatorForegroundTapRoutingTests
swift test --package-path CLI --scratch-path .build/sp163-200 --filter ServerTargetSelectionTests
swift test --package-path CLI --scratch-path .build/sp163-200 --filter SchemaFactSourceTests
swift build --package-path CLI --scratch-path .build/sp163-200-release -c release --product triton
.build/sp163-200-release/release/triton schema --command act --json
docs-linhay/scripts/check-docs.sh
git diff --check
```

真实 Simulator/私有 App 不作为本次验收前置条件；routing 以纯函数与 parser/schema fixture 验证，禁止设备状态操作。

## 当前状态

- 已完成（本地）：`act tap` 在 embedded resolver 前识别受约束的 Simulator 坐标 selector，直接使用 ready local host-HID 并返回，因此不会查询 `/targets`；canonical runtime selector 保持 embedded 精确语义。
- TDD red：新增 focused suite 首次因 routing helper 尚不存在而编译失败；补入最小实现后 6/6 通过。
- focused regression：`SimulatorForegroundTapRoutingTests`、`ServerTargetSelectionTests`、`InputOutputTests` 与 iOS Web host-HID tests 合计 20/20 通过，覆盖 selector 分流、canonical fail-closed、单 JSON failure envelope、坐标归一化与 Baguette argv。
- release CLI：`swift build -c release --product triton` 通过；release `triton schema --command act --json` 已验证 `/targets` bypass 语义与 `input.result` contract。
- 本地总门禁：`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 通过（根包 239/239、release CLI/smoke、Harmony host smoke、iOS runtime observe smoke、docs/diff）；按本轮边界跳过真实 Xcode/Simulator 验证。
- 默认 CLI 全量测试可完成，但有 11 个基线 issue：5 个 Xcode archive/export schema matrix/taxonomy、1 个 public skill command snapshot、5 个 Harmony wait timing；本次 focused suites 无新增失败。
- 风险：未连接真实 Simulator、Baguette 或私有 App；host-HID 成功仍只是提交回执，真实业务完成必须以后验 observation/evidence 证明。GitHub #200 已随 CI `31778845414` 全绿后评论并关闭（合并提交 `8cc72765`，随下一 patch 发布）。
