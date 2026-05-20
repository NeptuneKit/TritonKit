# Real project regression handoff

## 背景

当前仓库已完成 DEBUG-only runtime、SwiftPM/CocoaPods 接入、CI/release 产物、iOS 接入 README、Objective-C 残留清理和 Swift runtime 死代码清理。下一阶段将从 TritonKit 自身验证切到真实业务 App 回归与实际需求发现。

## 固化入口

新增项目级 skill：

- `.agents/skills/tritonkit-real-project-regression/SKILL.md`

触发场景：

- 真实 iOS App 接入 TritonKit。
- 在客户/业务项目中跑回归。
- 基于真实 App 行为发现 TritonKit 的实际缺口。

## 下一阶段默认回归序列

1. 确认真实 App 仓库、分支、设备/模拟器、目标场景。
2. 分别检查 TritonKit 和真实 App 工作区状态，外部仓改动不混入 TritonKit 提交。
3. 构建 release CLI：`swift build -c release --product triton`。
4. 启动 `triton serve --host 127.0.0.1 --port 19421`。
5. 真实 App 启动后优先跑 `triton evidence --name <case> --output /tmp/<case>.tritonevidence --json` 生成证据包；需要拆解时再单独跑 `status/list/geometry/ax/screenshot/export`。
6. 若流程需要复用，先沉淀 `.tritonplan`：`triton record --output <case>.tritonplan --json` 只作为模板，随后编辑真实步骤，使用 `triton plan inspect <case>.tritonplan --json` 和 `triton replay <case>.tritonplan --dry-run --var key=value --var secret-env=ENV --json` 校验。
7. 用 `triton replay <case>.tritonplan --json` 或默认 JSON 的 action 命令执行最小真实流程，例如 `triton find "HTTP"`、`triton tap "HTTP"`、`triton type "hello"`、`triton paste "console"`、`triton clear`；同文案多目标先用 `triton find "<text>" --all` 枚举候选，再用 `triton tap "<text>" --index <n>` 或 `triton tap "<text>" --within x,y,width,height` 消歧；批量动作继续用 `triton input --json --summary --strict`。
8. 点击、提交、导航后优先用 `triton wait --text/--gone/--idle/--predicate` 等待异步 UI 状态，再用二次 `ax/find/screenshot/archive/evidence` 验证状态变化。
8. 发现 TritonKit 缺口时，按 `tritonkit-dev-feedback` 直接沉淀 GitHub issue。

## 当前可复用脚本

- `docs-linhay/scripts/verify-overloaded-triton-smoke.sh`
- `docs-linhay/scripts/verify-complex-harness.sh`
- `docs-linhay/scripts/verify-intent-cli-smoke.sh`

## 边界

1. 真实 App 仓库只作为被测系统，未获明确要求不提交、不回滚其本地改动。
2. 嵌入式 runtime 仍只承诺 App 内 UIKit 可公开验证的控制能力。
3. 系统弹窗、SpringBoard、设备级 HID 属于 host-side adapter 后续能力，不在当前 embedded runtime 范围内。
