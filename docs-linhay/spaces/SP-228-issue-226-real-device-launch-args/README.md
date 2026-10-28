# SP-228 · GitHub #226 · iOS 真机 launch 参数终止符

## 边界

修复 `devicectl device process launch` 的 iOS 真机参数构造：bundle identifier 后存在 App 参数时插入 `--`，使以 `-` 开头的参数和值按原样传给 App。模拟器 `simctl`、设备发现、真实设备执行和远端 GitHub 操作不在本切片内。

## BDD

- Given 一个 ready 的 iOS 真机和 `--arg=-launch-key --arg value`，when 构造 `app launch` 命令，then bundle ID 后出现 `--`，且 App 参数顺序和值保持不变。
- Given 没有 App 参数，when 构造 devicectl launch，then 不额外插入终止符，保持既有 argv 契约。
- Given 环境变量与 App 参数同时存在，when 构造命令，then 环境变量仍使用 JSON 选项并脱敏，App 参数仍位于 bundle ID 后。

## 验收

- `TKHostAdapterModelsTests` 覆盖无参数、环境变量、dash-prefixed 参数、多参数顺序。
- focused Swift 测试通过；未执行真实 iOS 真机 launch。
- 不 push、不开 PR、不关闭远端 issue。
