# 建议提供可复制的 HarmonyOS NEXT 最小测试工程模板

Status: resolved by `harmony-next` skill `v1.3.7`; see `references/quickStart/ets/minimal-project-scaffold.md` and `references/templates/empty-ability-app/`.

## 背景

在 TritonKit 评估 HarmonyOS NEXT / DevEco Emulator 接入时，需要新建一个最小 Harmony 测试工程，用来验证 DEBUG-only embedded collector 的 JSON 契约、后续 HDC 安装启动、`uitest dumpLayout`、截图和日志采集链路。

当前 `harmony-next.skills` 已提供：

- `quickStart/ets/创建一个新工程.md`：说明如何在 DevEco Studio 中通过 `Application > Empty Ability` 创建工程。
- `JsEtsAPIReference/guides/module.json5配置文件.md`：说明 `module.json5`。
- DevEco / Emulator / HDC / uitest 自动化 playbook。

但没有提供可直接复制到仓库中的最小工程 scaffold，例如完整的：

- `oh-package.json5`
- `build-profile.json5`
- `hvigorfile.ts`
- `AppScope/app.json5`
- `entry/src/main/module.json5`
- `entry/src/main/ets/entryability/EntryAbility.ets`
- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/resources/...`

## 期望

建议在 `harmony-next.skills` 中补充一个可复制的最小工程模板或 scaffold 指南，供 AI agent 在没有人工打开 DevEco Studio 向导时创建测试工程。

理想形态可以是：

1. `references/templates/empty-ability-app/`：可直接复制的最小 Empty Ability 工程。
2. 或 `references/quickStart/ets/minimal-project-scaffold.md`：列出每个必需文件的最小内容。
3. 补充一段命令行验证说明：如何用本地 DevEco / hvigor / ohpm 对该模板做静态校验或构建。

## 验收建议

- AI agent 能按文档在任意 repo 下生成一个最小 Harmony App 测试工程。
- 工程包含可打开的 Empty Ability 页面。
- 工程能用于 HDC / Emulator 自动化 smoke：安装、启动、`uitest dumpLayout`。
- 文档明确 API / SDK 版本边界，例如 Compatible SDK、model、bundleName、module name。

## 使用场景

TritonKit 这类跨平台自动化工具需要在仓库内维护小型 fixture 工程，用来验证：

- Harmony host-side adapter。
- embedded DEBUG-only collector。
- App 内页面状态、ArkUI/AX-like snapshot、geometry、screenshot metadata、redaction status。

如果 skill 直接提供最小 scaffold，可以减少 agent 从其他本机工程复制配置时引入不稳定差异。
