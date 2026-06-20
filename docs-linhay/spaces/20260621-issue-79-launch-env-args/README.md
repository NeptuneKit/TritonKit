# Issue 79 - Launch env and app arguments

## 背景

GitHub issue #79 反馈真实 iOS Simulator 验证时，`triton xcode run` 与 `triton app launch` 缺少 launch environment 和 app arguments 注入能力，导致 agent 只能 fallback 到裸 `xcrun simctl launch`。

## 范围

本 space 覆盖本机 iOS Simulator host-side launch：

- `triton app launch --env KEY=VALUE --arg VALUE`
- `triton xcode run --env KEY=VALUE --arg VALUE`
- `--env` 值实际传入 `SIMCTL_CHILD_<KEY>`，但 JSON/sourceCommand 只暴露 key 与 `<redacted>`。
- `--arg` 值追加到 `simctl launch <udid> <bundle-id>` 之后。

不在本期范围：

- iOS real-device `devicectl` env/args 注入。
- Android / Harmony launch env/args 注入。
- 新增独立 config/secret session 命令组。

## BDD 场景

### 场景 1：app launch 注入 env 和 app args

Given agent 使用 `triton app launch` 启动已安装 iOS Simulator app  
When 传入重复 `--env KEY=VALUE` 与重复 `--arg VALUE`  
Then Triton 通过 `SIMCTL_CHILD_<KEY>` 注入环境变量，并把 app args 追加到 launch argv  
And 输出的 `sourceCommand` 不包含 env 明文值。

### 场景 2：xcode run 注入 env 和 app args

Given agent 使用 `triton xcode run` 完成 build/install/launch  
When 传入重复 `--env KEY=VALUE` 与重复 `--arg VALUE`  
Then 最终 simulator launch 使用同一 redaction 策略和 app args  
And schema 中可发现 `--env` / `--arg`。

### 场景 3：非法 env key 在执行前失败

Given launch env key 不符合 `[A-Za-z_][A-Za-z0-9_]*`  
When agent 运行 launch 命令  
Then Triton 在 host tool 执行前返回 validation error。

## 验收

- Focused tests 覆盖 `app launch` planner、redacted `sourceCommand`、schema、CLI parse。
- Focused tests 覆盖 `xcode run` 参数解析和 schema。
- `git diff --check` 与 `docs-linhay/scripts/check-docs.sh` 通过。
