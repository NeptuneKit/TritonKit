# Host Adapter Next Steps

## 目标

把真实项目回归中已经出现的裸 `xcrun simctl` 动作收敛为 TritonKit 机器可读 CLI，降低其他 AI agent 复制宿主命令、解析人读输出和遗漏验证的概率。

## 建议顺序

1. 先实现只读/短命命令：`host simulators`、`app container`、`app prefs dump/get`。
2. 再实现动作命令：`app open-url`、`sim privacy`、`sim location`、`sim ui`。
3. 再接入 `.tritonplan` step：`open-url`、`prefs-get`、`privacy`、`location`。
4. 最后处理长生命周期命令：`logs stream`、`xctrace record`。

## 下期候选需求池

### serve-sim 参考吸收

- 来源：`https://github.com/EvanBacon/serve-sim`，本地快照：`docs-linhay/references/serve-sim/`，HEAD：`f94d57c`。
- 候选能力：
  1. Simulator streaming helper lifecycle：start/list/status/stop 的 JSON contract，作为本机预览或 evidence 辅助，不作为 Web/Wails 业务入口。
  2. 归一化坐标动作：借鉴 `tap` 优先于 begin/end gesture 的设计，把 `0..1` 坐标、edge gesture、button、rotate 纳入 `triton act` / `triton sim` schema。
  3. 权限准备：补齐 `sim permissions grant|revoke|reset|list`，重点评估通知权限这类 `simctl privacy` 覆盖不足的场景。
  4. 日志与 AX 辅助证据：评估 `/ax`、foreground、stream config、log forwarding 是否能映射为 Triton evidence artifact。
  5. Camera injection：仅进入后续独立设计候选，先评估 Debug-only 边界、DYLD injection 风险、macOS 版本和 arm64 限制。
- 不做：
  1. 不引入 Node/npm 作为 `triton` CLI 默认运行依赖。
  2. 不复制 Web preview / `/.sim/exec` host shell endpoint。
  3. 不把远端 tunnel 或无认证 LAN 控制作为默认产品面。
  4. 不把 camera injection 并入 host adapter P0。

## 测试门禁

- CLI 参数解析和 schema 必须有单元测试。
- `simctl` 执行层使用可注入 process runner，单元测试断言 argv，不依赖真实 simulator。
- 真实 simulator smoke 只放在脚本或手动验收中，避免常规 `swift test` 长时间占用设备。
- JSON error 必须覆盖工具不存在、设备不存在、bundle 不存在、plist 不存在、命令超时、非零退出。

## 文档写回

- 新增命令后同步 README、`docs-linhay/dev/ai-cli-readable-control.md`。
- 更新 `TritonKit.skills/tritonkit-real-project-regression`，把真实项目回归中的裸 `xcrun simctl openurl/get_app_container` 替换成 `triton app ...`。
- 若引入 `SKProcessRunner`，新增 dev 文档说明依赖边界：只用于 CLI/macOS host adapter，不进入 embedded runtime。
