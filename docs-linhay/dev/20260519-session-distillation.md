# 2026-05-19 session distillation

## 本轮沉淀的模式

### 开发阶段反馈入口

TritonKit 仍处于开发阶段。外部试用、接入或评估时，如果用户提出需求、bug、兼容性问题、文档缺口或不清楚的行为，AI agent 应负责澄清、复现、收集证据，并直接向 `NeptuneKit/TritonKit` 提交 GitHub issue。

复用入口：

- `.agents/skills/tritonkit-dev-feedback/SKILL.md`

### CI / Release 产物契约

GitHub CI 和 tag release 必须同时产出两类可分发资产：

1. `triton` CLI 包：`triton-macos-<arch>.tar.gz` / `.zip`
2. 项目级 skill 包：当前至少包含 `tritonkit-dev-feedback.tar.gz` / `.zip`

复用入口：

- `.github/workflows/ci.yml`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- `docs-linhay/dev/20260519-github-ci-release-artifacts.md`

### Package Manager Debug-only runtime

TritonKit 作为 Package Manager 依赖提供给业务 App 时，embedded runtime 只在 `DEBUG` 编译配置下生效。Release 下 package 必须保持可编译，但 runtime 不连接、不采集、不上传、不响应控制。该边界只跟编译配置有关，不按 iOS/macOS、UIKit 是否可导入等端类型决定。

复用入口：

- `TritonKit.isRuntimeEnabled`
- `TritonKitRuntimeError.disabledOutsideDebug`
- `.agents/skills/tritonkit-ops-governance/SKILL.md`
- `docs-linhay/dev/20260519-debug-only-pm-runtime.md`

## 本轮不纳入的内容

- “按端类型拆分 PM 集成”的误判不纳入规则。后续遇到 PM 相关需求，先确认用户说的是编译配置、平台、包管理器、还是发布产物，不直接把“环境”理解成 iOS/macOS 端类型。
- 临时 artifact 下载命令卡住的处理不沉淀为长期流程。当前只保留结论：CI artifact 元数据和 workflow 步骤足以确认本轮主线；需要内容级核对时再单独处理。

## 后续执行口径

1. 需求涉及外部使用者反馈：先走 `tritonkit-dev-feedback`，AI 直接提交 issue。
2. 需求涉及 CI、release、发布资产：先走 `tritonkit-ops-governance`，同步检查 CLI 包和 skill 包是否仍在产物契约里。
3. 需求涉及业务 App 通过 PM 引入 TritonKit：默认检查 `DEBUG` / Release 双分支，不按端类型启停 runtime。
4. 用户纠正需求语义时，先收窄到用户最新表述，再撤回过度实现方向，最后补双分支验证。

## 已完成验证

- `swift test`
- `swift test -c release`
- `swift build -c release --target TritonKit`
- `swift build -c release --product triton`
- `docs-linhay/scripts/check-docs.sh`
- `qmd update`
- `qmd embed`
- GitHub CI run `26076417656` 成功
