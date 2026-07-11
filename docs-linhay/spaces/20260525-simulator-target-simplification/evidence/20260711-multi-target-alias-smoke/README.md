# 20260711 Multi-target Alias Smoke

## 结论

真实多目标验收通过：

- iOS：两台 Booted Simulator，UDID 分别为 `83407554-53AB-45B4-A0C1-D59F34E26A67` 与 `F4E55B8E-0141-4C46-9965-263CCE782B5F`。
- Harmony：`127.0.0.1:5555`，Connected。
- 无 selector 执行 `device resolve --platform ios --scope simulator --ready` 返回 `ambiguous_target`，候选数为 2。
- iOS alias 解析后只对指定 UDID 启动 `com.neptunekit.tritonkit.demo`，见 `app-launch-ios.json`。
- Harmony alias 解析后完成 screenshot 与 `observe tree`，修复后 tree 返回 93 个节点，见 `observe-tree-harmony-after-fix.json`。

## 红绿证据

- `observe-tree-harmony.json`：修复前，不带 `--platform` 的 Harmony alias 被错误施加 iOS 过滤器，返回 `target_platform_mismatch`。
- `observe-tree-harmony-after-fix.json`：修复后由 alias 推断 Harmony，返回 `ok=true`、`platform=harmony`、`target=127.0.0.1:5555`。
- `resolve-ios-ambiguous.json`：证明多开 iOS 时不会静默误选。
- `resolve-ios.json`、`resolve-harmony.json`：证明 selector source 为 `alias` 且目标精确。

## 截图

- `20260711-cli-multi-target-ios-after-v01.png`
- `20260711-cli-multi-target-harmony-after-v01.jpeg`

两张截图均由 `triton device screenshot --device <alias>` 生成，机器可读输出分别见 `screenshot-ios.json` 与 `screenshot-harmony-jpeg.json`。

## 清理与边界

- 临时 alias：`triton-smoke-ios-20260711`、`triton-smoke-harmony-20260711`。
- `aliases-before.json` 与 `aliases-cleaned.json` 均为空，证明 smoke 未遗留 workspace alias。
- `--bundle` 反向过滤未实现，按路线裁决从本 space 范围删除。
- 全程先保存 `status`、`doctor`、`capabilities`、`schema-device`、`schema-app` 与 `plan`；未使用裸 `xcrun`、`hdc`、`adb` 或其他 fallback。
