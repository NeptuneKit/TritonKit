# 20260520 Harmony Emulator 技术实现评估

## 背景更新

上游 `harmony-next.skills` 已在 release `v1.3.9` 中包含 issue `#10` 的新语义：

1. skill 不做授权或人工确认拦截。
2. 用户默认拥有完整执行权限。
3. policy 只表达执行模式、产物目录、timeout 和脱敏契约。
4. `blocked` 只用于缺少 target、artifactDir、脱敏策略、timeout、审计命令记录等客观运行配置。
5. riskLevel 用于审计、报告和调度，不作为自动化停止条件。

因此 TritonKit 的 Harmony adapter 不能继承 `requiresConfirmation` 这类旧模型，必须改为“平台中立 host execution + policy/config validation + audit output”。

## 当前代码形态

### 已有基础

- `Sources/TritonKitCLI/main.swift` 已有 host-side Apple Simulator 命令入口：`sim list/boot/shutdown/screenshot`、`app open-url/container/prefs`。
- `Sources/TritonKitShared/TKHostAdapterModels.swift` 已有 `TKHostCommand`、`TKSimctlCommand`、`TKHostSimulatorTarget`、`TKSimctlDeviceListParser`、preferences plist 解码模型。
- `Tests/TritonKitSharedTests/TKHostAdapterModelsTests.swift` 已覆盖 simctl argv、设备列表解析和 preferences plist 解码。
- CLI schema、capabilities、evidence、capture、replay 已经存在，适合把 host-side 能力继续纳入机器可读契约。

### 主要阻塞

1. `TKHostCommand.requiresConfirmation` 仍是旧人工确认语义；Harmony v1.3.9 要求移除授权/确认 gate。
2. `runHostCommand(_:)` 当前硬编码 `/usr/bin/xcrun`，无法执行 `hdc`、DevEco `Emulator` 或其他 host tool。
3. host command runner 当前没有 timeout、stdout/stderr 截断、JSONL progress、环境记录、artifactDir 校验。
4. Apple simulator 命令和通用 host execution 混在 CLI 单文件中，继续扩展 Harmony 会让 `main.swift` 更难维护。
5. evidence artifact 目前只有 `kind/path/contentType/bytes/freshness`，还缺少 `riskLevel/policy/redactionStatus/sourceCommand` 这类 host-side 审计字段。

## 技术结论

推荐先做一层平台中立 Host Adapter Core，再接 Apple 和 Harmony 两个 platform adapter。

```text
TritonKitCLI command
  -> Host target resolver
  -> Platform adapter: apple-simctl / harmony-hdc / harmony-emulator
  -> Host process runner
  -> Normalized JSON / JSONL result
  -> evidence / capture / replay / schema
```

不推荐直接在 CLI 里加 `hdc` 命令分支。原因：

- 会复制现有 Apple-only runner 的硬编码问题。
- 无法统一 timeout、artifactDir、脱敏、sourceCommand、riskLevel。
- 后续 `.tritonplan` 混排 Apple/Harmony/runtime step 时会出现三套结果语义。

## 核心模型调整

### 1. 替换 `requiresConfirmation`

建议将 `TKHostCommand` 从：

```swift
requiresConfirmation: Bool
```

调整为：

```swift
riskLevel: TKHostRiskLevel
requiredConfig: Set<TKHostRequiredConfig>
defaultTimeout: TimeInterval
capturesArtifacts: Bool
sensitiveOutput: Bool
```

建议枚举：

```swift
enum TKHostRiskLevel: String, Codable {
    case readonly
    case evidence
    case automation
    case diagnostic
    case breakGlass = "break-glass"
    case unknown
}

enum TKHostRequiredConfig: String, Codable {
    case target
    case artifactDir
    case redactionPolicy
    case timeout
    case auditRecord
}
```

执行前只校验客观运行配置。缺配置时返回：

```json
{
  "ok": false,
  "error": {
    "code": "blocked_missing_config",
    "missingConfig": ["target", "artifactDir"],
    "requiredMode": "evidence"
  }
}
```

### 2. 增加 Host Execution Policy

policy 来源按优先级：

1. CLI 参数：`--policy automation`
2. 环境变量：`TRITON_HOST_POLICY=automation` 或兼容 `HARMONY_NEXT_AUTOMATION_POLICY`
3. repo-local config：`.triton-host-policy.json`
4. 默认：`readonly`

policy 不表达权限，只表达本次 run 的执行模式和记录契约：

```json
{
  "mode": "automation",
  "artifactDir": "docs-linhay/spaces/<space>/screenshots/20260520/harmony",
  "redactionPolicy": "summary",
  "timeoutSeconds": 30,
  "audit": true
}
```

### 3. Host process runner 协议化

新增共享或 CLI 内部协议：

```swift
protocol TKHostProcessRunning {
    func run(_ command: TKHostCommand, policy: TKHostExecutionPolicy) throws -> TKHostCommandResult
}
```

首期实现：

- `TKFoundationHostProcessRunner`：使用 `Process`。
- 支持 executable path，不再固定 `/usr/bin/xcrun`。
- 支持 timeout，超时 kill 并返回 `host_command_timeout`。
- stdout/stderr 做最大字节截断，保留 `truncated=true`。
- 结果包含 `sourceCommand`，但敏感参数要脱敏。

## Harmony Adapter P0 设计

### 目标发现

命令：

```text
triton device doctor --platform harmony --json
triton device list --platform harmony --json
triton device use --platform harmony --target 127.0.0.1:10100 --json
triton device wait-ready --platform harmony --target 127.0.0.1:10100 --jsonl
```

底层：

```text
Emulator -version
Emulator -list
Emulator -list -details
hdc list targets -v
hdc -t <target> shell param get bootevent.boot.completed
```

新增模型：

```swift
struct TKHarmonyTarget: Codable, Equatable {
    let id: String              // harmony:127.0.0.1:10100
    let target: String          // 127.0.0.1:10100
    let state: String           // Connected / Offline / Unknown
    let transport: String       // hdc
    let isConnected: Bool
    let source: String          // hdc
}
```

解析策略：

- 只把 `Connected` 作为默认候选。
- 多个 `Connected` 返回 `ambiguous_target`。
- `Offline` 进入列表但不进入默认选择。

### App inspect/launch

命令：

```text
triton app inspect --platform harmony --target <target> --bundle <bundleName> --json
triton app launch --platform harmony --target <target> --bundle <bundleName> --ability <abilityName> --json
```

底层：

```text
hdc -t <target> shell bm dump -n <bundleName>
hdc -t <target> shell aa start -b <bundleName> -a <abilityName>
```

实现要点：

- `inspect` 首期可以做弱解析：提取 `bundleName`、`mainAbility/mainElementName/abilityInfos[].name` 候选，保留原始摘要但不回显完整 dump。
- `launch` 只表示提交启动请求成功，业务状态仍通过 `find/wait/assert` 验证。

### UI tree 与输入

命令：

```text
triton ax --platform harmony --target <target> --json
triton find "<text>" --platform harmony --target <target> --json
triton tap "<text>" --platform harmony --target <target> --json
triton swipe --platform harmony --target <target> --from x1,y1 --to x2,y2 --json
triton type "<text>" --platform harmony --target <target> --json
triton press Back --platform harmony --target <target> --json
```

底层：

```text
hdc -t <target> shell uitest dumpLayout -p <path> -a
hdc -t <target> shell uitest uiInput click <x> <y>
hdc -t <target> shell uitest uiInput swipe <x1> <y1> <x2> <y2>
hdc -t <target> shell uitest uiInput text <escaped-text>
hdc -t <target> shell uitest uiInput keyEvent Back
```

实现要点：

- `tap "<text>"` 必须先从 layout 节点 bounds 计算中心点；禁止没有坐标来源的盲点。
- 文本输入只做参数数组，不拼 shell 字符串；必要时集中做 `uitest uiInput text` 转义。
- 每次输入后重新 dumpLayout，保持 agent 可观察。
- Harmony layout 应转换成现有 `TKAXNode` 或新增 platform-neutral `TKHostUINode`，再由 `find/tap/assert` 共享匹配逻辑。

## Evidence / Capture 调整

`capture/evidence --platform harmony` 应输出：

```json
{
  "platform": "harmony",
  "target": "harmony:127.0.0.1:10100",
  "policy": "automation",
  "artifacts": [
    {
      "kind": "harmony.layout",
      "path": ".../layout.json",
      "riskLevel": "evidence",
      "redactionStatus": "summary",
      "sourceCommand": "hdc -t <target> shell uitest dumpLayout ..."
    }
  ]
}
```

建议扩展 `TKEvidenceArtifact`，新增可选字段，保持旧 evidence manifest 兼容：

- `platform`
- `riskLevel`
- `policy`
- `redactionStatus`
- `sourceCommand`
- `target`

## CLI 命名建议

短期保留现有：

- `triton sim ...`：Apple Simulator 专属 alias。
- `triton app ...`：扩展 `--platform apple|harmony`，默认 `apple` 兼容现有行为。

新增跨平台入口：

- `triton device doctor/list/use/wait-ready --platform <platform>`
- `triton host run` 不作为首期公开入口，避免 agent 绕开 schema 直接跑任意命令。

原因：`device` 是 Harmony 和 Apple 可共享的 target 发现入口；`sim` 保持现有 Apple 用户习惯。

## 测试策略

### P0 单元测试

先补失败测试，再实现：

1. `TKHostCommand` 不再暴露 `requiresConfirmation`。
2. `TKHostExecutionPolicy` 从 CLI/env/config 解析，优先级稳定。
3. 缺 target/artifactDir/timeout 时返回 `blocked_missing_config`。
4. `TKHarmonyHDCCommand` argv 稳定，文本输入不拼接 shell 字符串。
5. `TKHdcTargetListParser` 能解析 `Connected`、`Offline` 和多 target。
6. `TKHarmonyBootCompletedParser` 只接受 `true` 作为 ready。
7. `TKEvidenceArtifact` 新字段可选，不破坏旧 JSON。

### CLI smoke

不依赖真实 DevEco：

- 用 fake executable 脚本输出固定 `hdc list targets -v`。
- `triton device list --platform harmony --hdc <fake> --json` 输出稳定 JSON。
- 多 Connected target 返回 `ambiguous_target`。
- 缺 artifactDir 的 evidence mode 返回 `blocked_missing_config`。

### 真实环境验证

需要本机 DevEco / Emulator 后再做：

- `device doctor/list/wait-ready`
- `app inspect/launch`
- `ax/find/tap/type/press`
- `capture --platform harmony --policy automation`

真实验证产物归档到本 space 的 `screenshots/` 或 `capture/` 子目录，不使用 `latest/final` 命名。

## 分期实施

### Step 1：Host Core 重构

- 移除 `requiresConfirmation`。
- 新增 `riskLevel/requiredConfig/policy`。
- runner 支持 executable path、timeout、stdout/stderr 限制和 sourceCommand。
- Apple simctl 现有测试更新为 riskLevel 语义。

### Step 2：Harmony P0 只读 adapter

- DevEco/HDC path discovery。
- `device doctor/list/wait-ready --platform harmony`。
- schema/capabilities 暴露 Harmony P0。

### Step 3：App 与 UI 基础动作

- `app inspect/launch --platform harmony`。
- `ax/find/tap/type/press --platform harmony`。
- layout -> host UI node -> find/tap 复用匹配。

### Step 4：Evidence / Replay 集成

- `capture/evidence --platform harmony`。
- `.tritonplan` 支持 `platform`、`target`、`policy`。
- artifact manifest 写入 riskLevel/policy/redactionStatus/sourceCommand。

## 风险与缓解

1. **DevEco/HDC 输出不稳定**：所有 parser 都要保留原始摘要和 parser version，失败返回 `unsupported_tool_output`。
2. **命令无限等待**：所有 host command 必须带 timeout；日志流默认 bounded，长流用 JSONL event。
3. **文本输入注入**：禁止拼 shell 字符串；所有命令用 argv token，文本集中转义。
4. **main.swift 继续膨胀**：新增 host adapter 文件拆分，后续再从 monolithic CLI 中迁出。
5. **Apple 旧模型污染 Harmony**：`requiresConfirmation` 必须先下线，break-glass 只作为 riskLevel。

## 推荐下一步

先实现 Step 1 + Step 2，不直接做 UI 输入。这样可以最小成本验证：

- 新 policy 语义可落地。
- HDC target discovery 能稳定机器可读。
- Host runner 能支持非 xcrun 工具和 timeout。
- `schema/capabilities` 可以让 agent 发现 Harmony adapter 能力。
