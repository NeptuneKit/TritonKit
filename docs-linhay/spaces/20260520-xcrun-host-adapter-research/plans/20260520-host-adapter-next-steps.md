# Host Adapter Next Steps

## 目标

把真实项目回归中已经出现的裸 `xcrun simctl` 动作收敛为 TritonKit 机器可读 CLI，降低其他 AI agent 复制宿主命令、解析人读输出和遗漏验证的概率。

## 建议顺序

1. 先实现只读/短命命令：`host simulators`、`app container`、`app prefs dump/get`。
2. 再实现动作命令：`app open-url`、`sim privacy`、`sim location`、`sim ui`。
3. 再接入 `.tritonplan` step：`open-url`、`prefs-get`、`privacy`、`location`。
4. 最后处理长生命周期命令：`logs stream`、`xctrace record`。

## 测试门禁

- CLI 参数解析和 schema 必须有单元测试。
- `simctl` 执行层使用可注入 process runner，单元测试断言 argv，不依赖真实 simulator。
- 真实 simulator smoke 只放在脚本或手动验收中，避免常规 `swift test` 长时间占用设备。
- JSON error 必须覆盖工具不存在、设备不存在、bundle 不存在、plist 不存在、命令超时、非零退出。

## 文档写回

- 新增命令后同步 README、`docs-linhay/dev/ai-cli-readable-control.md`。
- 更新 `TritonKit.skills/tritonkit-real-project-regression`，把真实项目回归中的裸 `xcrun simctl openurl/get_app_container` 替换成 `triton app ...`。
- 若引入 `SKProcessRunner`，新增 dev 文档说明依赖边界：只用于 CLI/macOS host adapter，不进入 embedded runtime。
