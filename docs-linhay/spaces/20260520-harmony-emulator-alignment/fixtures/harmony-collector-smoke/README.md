# TritonKit Harmony Collector Smoke

该目录基于 `harmony-next` skill 的 `references/templates/empty-ability-app/`，用于验证 TritonKit Harmony DEBUG-only collector JSON 契约和后续 HDC / `uitest` smoke。

来源边界：

- Scaffold 来源：`/Users/linhey/Desktop/linhay-open-sources/harmony-next.skills/harmony-next/references/templates/empty-ability-app/`
- 指南来源：`/Users/linhey/Desktop/linhay-open-sources/harmony-next.skills/harmony-next/references/quickStart/ets/minimal-project-scaffold.md`
- 本 fixture 不携带签名材料、IDE 缓存、个人证书或本机绝对签名路径。

默认参数：

| 字段 | 值 |
| --- | --- |
| bundleName | `com.neptunekit.tritonkit.collectorsmoke` |
| moduleName | `entry` |
| abilityName | `EntryAbility` |
| Compatible SDK | `5.0.0(12)` |
| targetSdkVersion | `5.0.0(12)` |
| modelVersion | `5.0.0` |
| runtimeOS | `HarmonyOS` |
| deviceTypes | `phone`, `tablet`, `2in1` |

## Collector smoke 信号

`entry/src/main/ets/triton/TritonCollectorContract.ets` 固化与 Swift `TKHarmonyCollector*` 模型一致的最小 ArkTS 契约：

- DEBUG manifest：`platform=harmony`、`transport=embedded-websocket`、`enabled=true`
- capabilities：`app-info`、`view-snapshot`、`accessibility`、`geometry`、`screenshot-metadata`
- Release no-op：`enabled=false`、capabilities 为空、`allowScreenshots=false`
- snapshot metadata：bundle、ability、route、screenshot format、artifact `dataRef`、redaction status

页面稳定文本 / 节点 ID：

| 文本或 ID | 用途 |
| --- | --- |
| `Triton Collector Ready` | 初始页面加载断言 |
| `Triton Collector Tapped` | 点击后页面状态断言 |
| `smoke-title` | 标题节点 |
| `smoke-counter` | 点击计数 |
| `smoke-increment` | 点击按钮 |
| `collector-debug-manifest` | DEBUG manifest 摘要 |
| `collector-capabilities` | capabilities 摘要 |
| `collector-release-noop` | Release no-op 摘要 |
| `collector-snapshot-metadata` | snapshot metadata 摘要 |

## 基本校验

推荐直接运行：

```bash
./verify-local.sh
```

脚本会执行 `ohpm install`、`hvigorw --mode module -p module=entry@default assembleHap`，并输出生成的 unsigned HAP 路径。

等价手动命令：

```bash
cd <copied-project>
/Applications/DevEco-Studio.app/Contents/tools/ohpm/bin/ohpm install
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw --mode module -p module=entry@default assembleHap
```

SDK 版本适配验证：

- 模板默认 SDK 为 `5.0.0(12)`；目标环境需要其他 SDK 时，在复制出的 fixture 内覆盖 `compatibleSdkVersion` 和 `targetSdkVersion`。
- HarmonyOS 6.0.2 / API 22 对应 `6.0.2(22)`。
- 构建时 `DEVECO_SDK_HOME` 指向 SDK 根目录，例如 `/Applications/DevEco-Studio.app/Contents/sdk`，不要指向 `sdk/default`。
- API 22 需要保留 app `icon`、Ability `icon`、`startWindowIcon` 和 `AppScope/resources/base/media/app_icon.png`。

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode module -p module=entry@default assembleHap
```

HDC / Emulator smoke：

```bash
HDC="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc"
TARGET="127.0.0.1:10100"
BUNDLE="com.neptunekit.tritonkit.collectorsmoke"
ABILITY="EntryAbility"
HAP="$(find entry/build -name '*.hap' | head -1)"

"$HDC" -t "$TARGET" install "$HAP"
"$HDC" -t "$TARGET" shell aa start -b "$BUNDLE" -a "$ABILITY"
"$HDC" -t "$TARGET" shell uitest dumpLayout -p /dev/null -a
"$HDC" -t "$TARGET" shell uitest screenCap -p /dev/null
```

交互 smoke：

1. 从 `dumpLayout` 找到 `smoke-increment` 的 `bounds`。
2. 用 `uitest uiInput click <center-x> <center-y>` 点击按钮。
3. 重新 `dumpLayout`，断言 `tapCount=1` 和 `Triton Collector Tapped`。

不同 DevEco/Hvigor 版本的输出路径可能不同。若找不到 HAP，先执行：

```bash
find entry/build -name '*.hap' -print
```
