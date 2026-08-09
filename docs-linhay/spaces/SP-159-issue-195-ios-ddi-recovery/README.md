# SP-159：iOS 真机 DDI 恢复动作

## 边界

- 对应 GitHub issue：#195 `[Bug] iOS real-device Xcode readiness blocks before DDI preparation`
- 影响层：CLI/HTTP 共享的 host failure envelope；不新增 Web/Wails 控制面。
- 工作目录：`../TritonKit-worktrees/SP-159-issue-195-ios-ddi-recovery/`
- 分支：`feat/SP-159-issue-195-ios-ddi-recovery`
- 基线：`main@252dcd210ff50fa11edab8eff624f7d3615215f6`
- 目标：当 CoreDevice 在 list/wait-ready 或其他 devicectl 动作中报告 DDI 缺失时，输出可执行且不误导的 iOS real-device `app install` 恢复动作。

## 非目标

- 不自动修改 Apple ID、Team、证书、profile 或 Xcode signing 设置。
- 不声称本机存在可用物理 iPhone/iPad，也不把 fixture 测试当作真实 DDI/tunnel smoke。
- 不改变既有 `ddi_missing` 错误码、不新增真机云或远端设备能力。

## BDD 验收

### 场景 1：DDI 缺失有可执行恢复

- Given `devicectl` 返回 `Developer Disk Image` / `DDI` 缺失
- When Triton 生成失败 envelope
- Then `error.code` 为 `ddi_missing`
- And `error.nextAction` 指向 `triton app install --platform ios --scope real --device <selector> --app <app-path> --json`
- And hint 说明该动作会触发 CoreDevice 准备，而不是承诺 readiness 已成功。

### 场景 2：恢复动作保持真实命令边界

- Given 一个 iOS real-device app install recovery
- When 编码为 JSON/JSONL next action
- Then selector、scope、platform、app path 和输出格式分别保持独立参数。

### 场景 3：其他 iOS 阻塞不被误分类

- Given trust、Developer Mode、locked、offline 或 devicectl 缺失错误
- When 生成 diagnostics
- Then 保持各自稳定错误码和已有 recovery，不伪装成 `ddi_missing`。

### 场景 4：旧 host workflow 不回归

- Given existing simulator/real-device parser and failure tests
- When 运行 focused tests
- Then 既有 Xcode、Device、schema 与 failure diagnostics tests 继续通过。

## 实施计划

1. 先在 `DeviceCrossPlatformTests` / `FailureDiagnosticsTests` 写红灯测试，锁定 `ddi_missing.nextAction` 的完整 args。
2. 在 `CLIHostProcessRuntime` 集中映射 DDI recovery，复用现有 `HostAppInstall` 合同。
3. 运行 focused tests、CLI build 与 docs gate；记录真实设备缺失为环境 skipped。
4. 更新本 space 与 memory；用户已授权远端 issue comment/close、push、PR、merge 的串行收口，但真实设备证据不足时不得伪装为 readiness 已成功。

## 验收命令

```bash
swift test --package-path CLI --scratch-path .build/sp159-issue-195 --filter DeviceCrossPlatformTests
swift test --package-path CLI --scratch-path .build/sp159-issue-195 --filter FailureDiagnosticsTests
swift build --package-path CLI --scratch-path .build/sp159-issue-195 --product triton
docs-linhay/scripts/check-docs.sh
git diff --check
```

## 当前结论

- 仅以 parser、failure envelope、schema 和 command-builder 证据验收。
- 真实 `devicectl` DDI preparation 需要连接且已信任的 iOS 真机及匹配 Xcode；当前环境未宣称通过。
