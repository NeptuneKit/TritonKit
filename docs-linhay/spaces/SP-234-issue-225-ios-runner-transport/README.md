# SP-234 · iOS Runner 启动阶段诊断

当前状态：本地实现/联合验收完成；汇入 `feat/SP-241-open-issues-validation`，未合main、未发布、远端仍开放。[联合验收与风险](../SP-241-open-issues-validation/plans/20261028-validation.md)为当前事实源；独立分支冻结记录保留为历史。
- Issue：[#225](https://github.com/NeptuneKit/TritonKit/issues/225)
- 影响层：CLI / HTTP 共用 Runner service、错误 schema。
- 边界：不改变签名、配对、Developer Mode；不把 XCTest transport refusal 判为确定的 Apple 工具链缺陷。

## BDD

1. Given native XCTest 拒绝 driver channel，When Runner start 轮询失败，Then 提前返回固定脱敏原因与 startup 阶段，而非仅提示解锁。
2. Given health 已成功但 automation probe 未成功，Then 保留 health verified，UI automation unverified。
3. Given native launch 失败或子进程提前退出，Then 分别暴露 typed 分类，不回传原始日志/路径/凭据。
4. Given 未知错误或日志不可读，Then 保持保守 readiness failure，不凭字符串猜测根因。

## 验收

- 生命周期 fixture 覆盖 early DTX、launch failure、health-only 与日志隐私；所有异常保持单一 JSON envelope。
- 日志分类只读取本会话 native.stdout/stderr 的有限尾部，不跟随 symlink、不读取非 regular 文件。
- 本轮不启动设备或修改签名；真实 iOS/XCTest 组合验证由主控单独执行。

## 验证记录

见 plans/20261028-validation.md（验证完成后写入）。
