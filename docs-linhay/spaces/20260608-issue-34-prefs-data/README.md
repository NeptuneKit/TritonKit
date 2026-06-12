# 20260608 Issue 34 Prefs Data

## 背景

GitHub issue #34 反馈 `triton app prefs get/set` 在处理 iOS `UserDefaults` 的 `Data` / `NSData` 值时不够安全。真实 App 常把 JSON 编码后的字节存进 `UserDefaults.data(forKey:)`；如果 Triton 把同一个 key 读成普通 JSON array/dictionary，或用 `prefs set <json-value>` 无提示改写为 array/dictionary，App 重启后会无法按 `Data` 解码。

当前第一片只处理本机 iOS Simulator 的 host-side `triton app prefs` CLI 契约，不扩展到真机、远端 agent、HTTP 产品面或 Web/Wails UI。

## 目标

1. `triton app prefs get <key> --json` 对 plist `Data` 值输出稳定、可机读的 JSON 表示，包含 base64、length 与 plist type。
2. `triton app prefs dump --json` 中的 Data 值使用同一表示，agent 不需要猜测 `{ "data": ... }` 是业务字典还是二进制 envelope。
3. `triton app prefs set` 支持显式写入 Data，优先入口为 `--type data --base64 <value>` 或 `--type data --hex <value>`。
4. `prefs set` 输出 `previousValue` / `newValue` 时都能看出 stored plist type，避免 agent 无提示把 Data key 改成 Array/Dictionary。
5. 文档明确当前实现仍直接编辑 App data container 下的 preferences plist；该语义应保持 property list / CFPreferences 兼容值，但不是通过 `defaults write` 进程执行。

## 非目标

1. 本片不实现“已有 Data key 默认 preserve 类型并自动把 JSON 转成 Data”。
2. 本片不新增 HTTP/Wails/Web 入口。
3. 本片不启动真实 Simulator 写业务 App 偏好；以 fixture/unit tests 覆盖 plist Data 读写契约。

## BDD 场景

### 场景 1：读取 Data preference 时输出稳定 envelope

- Given preferences plist 中存在 `SeedState`，其 plist stored type 是 `Data`
- When agent 执行 `triton app prefs get SeedState --device <sim> --bundle-id <id> --json`
- Then JSON 输出的 `value` 为对象，包含 `plistType: "data"`、`base64` 和 `length`
- And `length` 等于原始字节长度
- And agent 不会把该值误判成空 array 或业务 dictionary

### 场景 2：dump 时保留每个 key 的 plist type

- Given preferences plist 中同时存在 string、bool、array、dictionary 和 Data 值
- When agent 执行 `triton app prefs dump --device <sim> --bundle-id <id> --json`
- Then `preferences.<key>` 对 Data 使用同一 envelope
- And `preferences.<key>.plistType` 能让 agent 区分 Data envelope 与业务 dictionary

### 场景 3：显式 base64 写入 Data

- Given preferences plist 中不存在 `SeedState`
- When agent 执行 `triton app prefs set SeedState --type data --base64 <base64> --device <sim> --bundle-id <id> --json`
- Then plist 中 `SeedState` 的 stored type 是 `Data`
- And JSON 输出的 `newValue.plistType` 是 `data`
- And `newValue.base64` 与输入一致，`newValue.length` 等于解码后字节长度

### 场景 4：显式 hex 写入 Data

- Given agent 手里只有 `defaults write -data` 同款 hex 字节串
- When agent 执行 `triton app prefs set SeedState --type data --hex <hex> --device <sim> --bundle-id <id> --json`
- Then plist 中 `SeedState` 的 stored type 是 `Data`
- And JSON 输出的 `newValue.base64` 是 hex 解码后字节的 base64 表示

### 场景 5：Data 写入必须显式且参数互斥

- Given agent 执行 `prefs set <key> --type data` 但没有提供 `--base64` 或 `--hex`
- Then CLI 返回失败，不写 plist
- And 当同时提供 `--base64` 与 `--hex` 时也返回失败
- And 普通 `prefs set <key> <json-value>` 仍写入 JSON 对应的 plist 类型，不假装 preserve 既有 Data 类型

## 验收命令

```bash
swift test --package-path CLI --filter HostPreferencesSetTests
```

必要时补跑：

```bash
swift test --package-path CLI --filter SchemaFactSourceTests
docs-linhay/scripts/check-docs.sh
```

## 实现记录

- `TKHostPreferenceValue.data` 的 JSON 输出改为 `{ "plistType": "data", "base64": "...", "length": n }`，普通 string/bool/int/double/array/dictionary 仍保持自然 JSON 值。
- `HostPreferencesOutput` 增加 `valuePlistType` / `preferencesPlistTypes`，`HostPreferencesSetOutput` 增加 `previousPlistType` / `newPlistType`。
- `HostAppPrefsSet` 增加 `--type json|data`，默认 `json`；`--type data` 要求恰好提供一个 `--base64` 或 `--hex`。
- Data 写入仍复用当前直接编辑 App data container preferences plist 的实现，写入对象为 Foundation `Data`，本片不切换为 `defaults write` / CFPreferences 进程调用。
- 验证：`HostPreferencesSetTests` 覆盖 Data envelope、base64 写入、hex 写入和互斥参数；`SchemaFactSourceTests` 覆盖 schema 契约。
