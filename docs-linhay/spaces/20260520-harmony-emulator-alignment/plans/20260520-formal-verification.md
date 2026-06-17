# 20260520 Harmony Emulator Alignment Formal Verification

## 目标

验证 `docs-linhay/spaces/20260520-harmony-emulator-alignment` 的 P0 执行结果是否满足当前可交付范围：

1. Host Adapter Core 已移除交互式 `requiresConfirmation` gate，改用 risk/policy/config/audit 语义。
2. Harmony P0 CLI 暴露 `device doctor/list/use/wait-ready --platform harmony`。
3. `schema` / `capabilities` 能被 AI agent 发现。
4. 无真实 DevEco target 时仍返回稳定 JSON，而不是依赖人读输出。
5. 本机 DevEco / HDC 只读探测可用；若没有 Connected target，真实 `wait-ready` 不作为本轮通过条件。

## 验证环境

- 日期：2026-05-20
- 仓库：`/Users/linhey/Desktop/linhay-open-sources/TritonKit`
- DevEco Emulator：`/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator`
- DevEco HDC：`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`
- PATH HDC：`/Users/linhey/harmonyOS-command-line-tools/bin/hdc`
- fake HDC：`docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh`

## 命令结果

### 仓库门禁

命令：

```bash
docs-linhay/scripts/verify.sh --local
```

结果：通过。

覆盖：

- Swift tests：59 个测试通过。
- Release CLI build：通过。
- Release CLI smoke：通过。
- iOS Simulator build：通过。
- docs-linhay 结构检查：通过。
- Git diff whitespace check：通过。

### 真实 DevEco / HDC 只读探测

命令：

```bash
.build/debug/triton device doctor \
  --platform harmony \
  --hdc /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  --emulator /Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator \
  --json
```

结果：通过。

关键输出：

- `ok=true`
- `hdc.versionSummary="Ver: 3.2.0c"`
- `emulator.versionSummary="HarmonyOS Emulator :6.0.2.200"`
- `artifactsSaved=false`
- `sourceCommand` 分别记录 `hdc -v` 与 `Emulator -version`

命令：

```bash
.build/debug/triton device list \
  --platform harmony \
  --hdc /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc \
  --json
```

结果：通过，返回空 target 列表。

关键输出：

- `ok=true`
- `targets=[]`
- `sourceCommand="/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets -v"`

命令：

```bash
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -list
/Applications/DevEco-Studio.app/Contents/tools/emulator/Emulator -list -details
```

结果：通过。

关键输出：

- HVD 列表包含 `Codex Test Phone` 与 `Pura 90 Pro Max`。
- 两个 HVD 均显示 `isRunning=false`。
- 系统镜像为 HarmonyOS 6.0.2，API 22。

结论：真实 DevEco / Emulator / HDC 已可探测，但当前没有运行中的 Connected HDC target。因此本轮不执行真实 `device wait-ready --target ...`。

### fake HDC 契约验证

命令：

```bash
.build/debug/triton device use \
  --platform harmony \
  --hdc docs-linhay/spaces/20260520-harmony-emulator-alignment/fake-hdc-smoke.sh \
  --json
```

结果：预期失败，通过。

关键输出：

- `ok=false`
- `error.code="ambiguous_target"`
- candidates 提示包含 `127.0.0.1:10100` 与 `FMR0224C03001399`

命令：

```bash
.build/debug/triton schema --command device --json
.build/debug/triton capabilities --json
```

结果：通过。

关键输出：

- `schema.commands[].name="device"`
- `providedCapabilities=["host-device","harmony-device"]`
- `capabilities` 包含：
  - `host-device`
  - `harmony-device-doctor`
  - `harmony-device-list`
  - `harmony-device-wait-ready`

## Prompt-to-Artifact Checklist

| 要求 | 证据 | 结论 |
| --- | --- | --- |
| P0 只读发现 DevEco/HDC 能力 | `device doctor` 真实 HDC + Emulator 输出版本摘要 | 通过 |
| 列出 HDC target，Offline 不进入默认候选 | fake HDC parser 测试；真实 `device list` 返回 `targets=[]` | 通过 |
| 多 Connected target 返回 `ambiguous_target` | fake HDC `device use` 返回 `error.code=ambiguous_target` | 通过 |
| 等待 ready 只接受 boot completed true | `TKHarmonyBootCompletedParser` 单元测试；fake `wait-ready` 已在 P0 执行记录通过 | 通过 |
| schema/capabilities 暴露 Harmony P0 | `schema --command device` 与 `capabilities --json` | 通过 |
| 不保存真实 UI/layout/log/device 文件 | 真实 `device doctor` 返回 `artifactsSaved=false`；本轮未执行截图、layout、日志、file recv | 通过 |
| 不使用交互式确认 gate | `rg requiresConfirmation Sources Tests` 无结果；测试覆盖 risk/config/policy | 通过 |
| 文档与 memory 同步 | 本报告、memory 写回、`文档门禁` | 通过 |
| 真实 target `wait-ready` | 当前 `targets=[]`，无 Connected HDC target | 未执行，非 P0 通过条件 |

## 结论

P0 正式验证通过。

当前已经验证到三层：

1. 代码与模型层：Swift tests 覆盖 Host Core、Harmony HDC command、target parser、boot parser、evidence manifest。
2. CLI 契约层：schema/capabilities/fake HDC smoke 覆盖 P0 命令与错误码。
3. 本机真实工具层：DevEco Emulator 与 HDC 可被 Triton 只读探测，HVD 可枚举。

限制：当前没有运行中的 Harmony HDC target，因此未做真实 `wait-ready`、App inspect/launch、UI tree/input、screenshot/log/capture。下一轮若要进入 P1/P2，应先启动明确 HVD，并用 `--target` 固定 HDC target 后继续验证。

## 2026-05-21 全面测试补充

### 目标增量

在 P0 正式验证基础上，补齐真实 Harmony target、DEBUG-only collector fixture、真实 UI 输入、截图/layout 证据和 CI validate 门禁：

1. `harmony-next` skill 已提供可复制 Empty Ability scaffold，并可用于新建 Harmony smoke fixture。
2. Harmony DEBUG-only collector 契约在 Swift shared model 与 ArkTS fixture 中保持一致。
3. 真实 DevEco Emulator target 可安装、启动 fixture，并通过 `uitest dumpLayout` / `screenCap` 采集证据。
4. 真实 UI 输入使用 layout bounds 推导坐标，而不是桌面盲点。
5. `triton device wait-ready --platform harmony` 能解析真实 `hdc list targets -v` verbose 输出。
6. 仓库 `--local` 与 `--ci-validate` 两级门禁均通过。

### 新增命令结果

命令：

```bash
docs-linhay/spaces/20260520-harmony-emulator-alignment/fixtures/harmony-collector-smoke/verify-local.sh
```

结果：通过，生成 `entry/build/default/outputs/default/entry-default-unsigned.hap`。

命令：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets -v
```

结果：通过。

关键输出：

- `127.0.0.1:10100 TCP Connected localhost`

命令：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 install docs-linhay/spaces/20260520-harmony-emulator-alignment/fixtures/harmony-collector-smoke/entry/build/default/outputs/default/entry-default-unsigned.hap
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell aa start -b com.neptunekit.tritonkit.collectorsmoke -a EntryAbility
```

结果：通过。

命令：

```bash
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell uitest dumpLayout -p /data/local/tmp/triton_collector_before_v02.json -a
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell uitest screenCap -p /data/local/tmp/triton_collector_before_v02.png
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell uitest uiInput click 654 2087
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell uitest dumpLayout -p /data/local/tmp/triton_collector_after_v02.json -a
/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc -t 127.0.0.1:10100 shell uitest screenCap -p /data/local/tmp/triton_collector_after_v02.png
```

结果：通过。

关键输出：

- before layout 包含 `Triton Collector Ready`、`tapCount=0`、`harmony|embedded-websocket|enabled=true`、`app-info,view-snapshot,accessibility,geometry,screenshot-metadata`、`releaseEnabled=false|capabilities=0|screenshots=false`。
- `smoke-increment` bounds 为 `[368,2017][940,2157]`，点击中心点 `654,2087`。
- after layout 包含 `Triton Collector Tapped` 与 `tapCount=1`。
- screenshots PNG 分辨率为 `1308 x 2880`。

命令：

```bash
.build/debug/triton device wait-ready --platform harmony --target 127.0.0.1:10100 --timeout 10 --json
```

结果：通过。

关键输出：

- `ok=true`
- `ready=true`
- `target.transport="TCP"`
- `target.state="Connected"`

命令：

```bash
docs-linhay/scripts/verify.sh --local
docs-linhay/scripts/verify.sh --ci-validate
```

结果：均通过。

覆盖：

- `--local`：Swift tests 64 个测试、release CLI build、release CLI smoke、iOS Simulator build、docs structure、Git diff whitespace check。
- `--ci-validate`：Swift tests 64 个测试、`TritonKitShared.podspec` lint、`TritonKit.podspec` lint、Homebrew formula template、version stamping scripts、release automation contract。

### 新增证据归档

第二轮真实 smoke 证据位于 `docs-linhay/spaces/20260520-harmony-emulator-alignment/screenshots/20260521/harmony/`：

- `20260521-harmony-collector-layout-before-v02.json`
- `20260521-harmony-collector-screen-before-v02.png`
- `20260521-harmony-collector-layout-after-v02.json`
- `20260521-harmony-collector-screen-after-v02.png`

### 更新后的 Prompt-to-Artifact Checklist

| 要求 | 证据 | 结论 |
| --- | --- | --- |
| `harmony-next` 提供测试工程 scaffold | skill `v1.3.7`，fixture 基于 `references/templates/empty-ability-app/` | 通过 |
| DEBUG collector manifest 可发现 | Swift `TKHarmonyCollectorModelsTests`；before/after layout 中 `collector-debug-manifest` | 通过 |
| Release collector no-op | Swift release manifest 测试；layout 中 `releaseEnabled=false|capabilities=0|screenshots=false` | 通过 |
| snapshot 截图不内联正文 | Swift screenshot metadata 测试；ArkTS fixture 输出 `dataRef=artifacts/harmony-collector-smoke.png` | 通过 |
| 真实 HDC target 可解析 verbose 输出 | `hdc list targets -v` 与 `triton device wait-ready` 输出 `transport=TCP/state=Connected` | 通过 |
| 真实 App 可安装和启动 | `hdc install` 与 `aa start` 均成功 | 通过 |
| 真实 UI 树可采集 | before/after `uitest dumpLayout` JSON 已归档 | 通过 |
| 真实截图可采集 | before/after `screenCap` PNG 已归档，分辨率 `1308 x 2880` | 通过 |
| 真实 UI 输入不依赖桌面盲点 | 点击坐标来自 `smoke-increment` layout bounds 中心点 | 通过 |
| 仓库本地门禁 | `docs-linhay/scripts/verify.sh --local` | 通过 |
| CI validate 门禁 | `docs-linhay/scripts/verify.sh --ci-validate` | 通过 |
| 文档与 memory 同步 | README、formal verification、memory 更新；`文档门禁` 与 `历史检索` 验证 | 通过 |

### 更新后的结论

Harmony P0 + DEBUG-only collector smoke 的当前全面测试通过。原 P0 限制中“没有运行中的 Harmony HDC target，未做真实 wait-ready/UI/screenshot”已被本次补测覆盖。

仍未进入承诺范围的是 P2/P3 能力：`triton capture/evidence --platform harmony`、`logs tail --platform harmony`、HVD 生命周期管理和 `.tritonplan` Harmony step 回放。这些属于后续功能开发，不是本轮 DEBUG-only collector smoke 的完成条件。
