# SP-177 issue 213 real device runtime

## 边界
修复 iOS 真机 `app launch/open-url` 成功后，`smoke ios` 无法发现并连接 embedded Triton runtime 的问题。范围仅含 CLI host launch/smoke、runtime readiness 契约、测试与文档；不扩展真机截图、远端设备云或 Web 控制面。

## BDD
- Given 已连接且 ready 的 iOS 真机与可用 Triton server
- When `triton smoke ios --scope real --device <selector> ...` 启动 App
- Then 启动命令向 Debug App 提供可达的 Triton endpoint
- And smoke 在 runtime wait/assert 前验证对应 embedded runtime 已连接
- And host launch 成功但 runtime 未就绪时返回单一、可执行的 readiness failure

## 验收
- real-device launch/open-url 的 endpoint 注入有单元测试
- smoke 的 runtime target 绑定与 readiness failure 有 focused tests
- schema/nextAction 明确真实设备 setup 路径
- `swift test`、release build、`docs-linhay/scripts/verify.sh --local` 通过
