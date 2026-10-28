# SP-233 · GitHub #232 iOS 真机后端选择说明

当前状态：本地实现/联合验收完成；汇入 `feat/SP-241-open-issues-validation`，未合main、未发布、远端仍开放。[联合验收与风险](../SP-241-open-issues-validation/plans/20261028-validation.md)为当前事实源；独立分支冻结记录保留为历史。
## 状态与边界

文档/schema已通过联合契约验证；只澄清现有策略和字段，不新增后端或统一 DTO。基线 main `a0d187ac`；独立同名 worktree/feat 分支。未推送、发布或关闭远端issue。

## BDD 验收

- Given USB/wired iOS real target，When discovery/management，Then scope 决定 CoreDevice/devicectl，transport 不选择后端，unknown 保持 unknown。
- Given 各命令输出，Then 文档逐项映射实际 source/tool/sourceCommand(s)/transport/verification，不能宣称每个 DTO 均有 strategy 或 verification。
- Given physical logs / Runner / embedded runtime，Then 分别解释 idevicesyslog / XCTest session / in-app scope；host ACK 不等于业务成功。
- Given 可见 Apple DeviceHub.app，Then 不自动 GUI/private-protocol fallback；未来 adapter 要求公开调用面/版本矩阵、准确身份、显式选择、readiness、ownership、geometry 与独立后置证据。

## 交付与验收

说明见 [CLI 权威契约](../../dev/ai-cli-readable-control.md#ios-wired-real-device-backend-selection-232)，同步 README、device schema 及两份 public skill。现有 DeviceHubDiscovery/AppleCommandCompatibility/SchemaFactSource 测试覆盖所引用的路由与契约，本轮不新增镜像文案断言。

- focused tests：冷编译因宿主高负载按主控要求停止，exit130，未执行测试；原始日志在忽略目录 `.build/issue-validation/20261028-focused-tests.log`。此为历史中止记录；上述suite已随SP-241完整CLI通过。
- `verify.sh --ci-docs` 与 `check-docs.sh`：失败，仅因分批 worktree 基线缺 SP-228～232，连续编号检查拒绝 SP-233；SP-241联合登记后已通过docs门禁。
- 设备/GUI/物理输入：未执行；这不产生新的后端实测声明。

## 经验

复核草稿纠正了两处错误：不能把所有输出字段统一化；不能把所有 diagnostics 都称为 devicectl。修订回原权威文档与 public skills，没有新增重复经验主题。
