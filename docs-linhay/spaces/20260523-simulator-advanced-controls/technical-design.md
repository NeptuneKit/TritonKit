# Simulator Advanced Controls Technical Design

## 设计结论

这一轮不再扩展新的业务控制面，而是把 `simctl` 已有的 simulator maintenance 能力，以最小封装补进 `triton sim`。

优先原则：

1. 保持 `sim` namespace 的 host-side 定位。
2. 命令输入输出都走 JSON / JSONL。
3. 高风险操作继续要求 policy gate 或明确参数。
4. 能复用 `TKSimctlCommand` 的，就不要再引入 shell 拼接。

## 首批命令

### Status bar

```bash
triton sim status-bar list --simulator booted --json
triton sim status-bar clear --simulator booted --json
triton sim status-bar override --simulator booted --time "2026-05-23T10:00:00Z" --battery-level 80 --json
```

### Privacy

```bash
triton sim privacy grant location com.example.app --simulator booted --json
triton sim privacy revoke photos com.example.app --simulator booted --json
triton sim privacy reset all --simulator booted --json
```

### Location

```bash
triton sim location list --simulator booted --json
triton sim location set 37.7749,-122.4194 --simulator booted --json
triton sim location clear --simulator booted --json
triton sim location run <scenario> --simulator booted --json
triton sim location start --simulator booted --json
```

### UI

```bash
triton sim ui appearance dark --simulator booted --json
triton sim ui increase-contrast enabled --simulator booted --json
triton sim ui content-size accessibility-large --simulator booted --json
```

### Pasteboard

```bash
triton sim pasteboard set "hello" --simulator booted --json
triton sim pasteboard get --simulator booted --json
triton sim pasteboard sync host device --simulator booted --json
```

### Push

```bash
triton sim push --bundle-id com.example.app --payload /tmp/push.json --simulator booted --json
```

### Diagnostics / runtime

```bash
triton sim diagnose --output /tmp/sim-diagnostics --json
triton sim logverbose booted enable --json
triton sim runtime list --json
triton sim runtime verify com.apple.CoreSimulator.SimRuntime.iOS-26-5 --json
```

### Video

```bash
triton sim record --output /tmp/sim.mov --duration 10 --codec hevc --json
```

### Bounded logs

```bash
triton sim logs --output /tmp/sim.ndjson --duration 5 --style ndjson --json
triton sim logs --output /tmp/app.ndjson --duration 5 --predicate 'subsystem == "com.example.app"' --json
```

### Xctrace / coverage artifacts

```bash
triton xctrace record --template "Time Profiler" --device <udid> --time-limit 5s --output /tmp/app.trace --json
triton coverage report --xcresult /tmp/app.xcresult --output /tmp/coverage.json --json
triton coverage report --xcresult /tmp/app.xcresult --target App --output /tmp/coverage-files.json --json
```

这两个命令属于 host-side Xcode artifact 能力，不放进 `triton sim`。trace 和 coverage JSON 可能很大，CLI envelope 只返回 artifact path / bytes / truncation / sourceCommand，不内嵌完整内容。

### Phase 3 simulator maintenance

```bash
triton sim pair <watch-udid> <phone-udid> --json
triton sim unpair <pair-uuid> --json
triton sim clone <udid> "Clone for Smoke" --json
triton sim erase <udid> --confirm --json
triton sim upgrade <udid> <runtime-id> --json
triton sim runtime list --json
triton sim runtime verify <runtime-id> --json
triton sim runtime add /tmp/iOSSimulatorRuntime.dmg --json
triton sim runtime delete all --dry-run --json
triton sim runtime delete <runtime-id> --confirm --json
triton sim runtime unmount <runtime-id> --json
triton sim runtime scan-and-mount --json
triton sim runtime match list --json
triton sim runtime match set iphoneos26.5 23F77 --json
triton sim runtime match set iphoneos26.5 --default --json
triton sim runtime dyld-cache update <runtime-id> --json
triton sim runtime dyld-cache remove <runtime-id> --confirm --json
triton sim personalization personalize <runtime-id> --json
triton sim personalization remove-manifest manifest.plist --confirm --json
triton sim personalization remove-all-manifests --confirm --json
triton sim personalization remove-personalization <id> --confirm --json
triton sim personalization revoke-manifests --confirm --json
triton sim personalization scan-and-personalize --json
```

破坏性命令必须显式 `--confirm`，而 `runtime delete` 允许先用 `--dry-run` 复跑输出。`erase`、`runtime dyld-cache remove` 和 `personalization remove-*` 都应返回 machine-readable confirmation gate failure，而不是默默执行。

## 数据模型

### Shared host command support

`TKHostCommand` 需要支持可选 stdin payload，这样 `pbcopy` / 类似写入型命令可以保留机器可读控制面，而不是回退到 shell pipe。

### Output shape

首期可以复用 `HostActionOutput` 作为通用 envelope；对 list/get 类命令可再补一个窄 DTO，避免把敏感内容和执行摘要混在一起。

建议的错误码：

| Code | 含义 |
| --- | --- |
| `simulator_not_found` | 指定 simulator 不存在 |
| `status_bar_override_failed` | status bar override 命令失败 |
| `invalid_location_value` | location 参数非法 |
| `invalid_privacy_service` | privacy service 不支持 |
| `invalid_ui_value` | UI option/value 非法 |
| `pasteboard_operation_failed` | pasteboard 命令失败 |
| `push_payload_invalid` | push payload 不合法或超限 |
| `sim_diagnose_failed` | diagnostics collection 失败 |
| `sim_logverbose_failed` | verbose logging 切换失败 |
| `runtime_list_failed` | runtime list 失败 |
| `runtime_verify_failed` | runtime verify 失败 |
| `sim_pair_failed` | pair 失败 |
| `sim_unpair_failed` | unpair 失败 |
| `sim_clone_failed` | clone 失败 |
| `sim_erase_failed` | erase 失败 |
| `sim_upgrade_failed` | upgrade 失败 |
| `runtime_add_failed` | runtime add 失败 |
| `runtime_delete_failed` | runtime delete 失败 |
| `runtime_unmount_failed` | runtime unmount 失败 |
| `runtime_scan_and_mount_failed` | runtime scan-and-mount 失败 |
| `runtime_match_failed` | runtime match 失败 |
| `runtime_dyld_cache_failed` | runtime dyld cache 失败 |
| `sim_personalization_failed` | personalization 失败 |
| `sim_record_failed` | video recording 失败 |
| `sim_logs_failed` | bounded log capture 失败 |

## 测试策略

1. `TKSimctlCommand` builders 的 argv 测试。
2. `runHostCommand` stdin 支持测试。
3. `sim` 命令参数解析测试。
4. status bar / privacy / location / ui / pasteboard / push / diagnostics / runtime / video / logs 的成功与失败 envelope 测试。
5. schema 暴露测试。
6. Phase 3 maintenance 的 confirm / dry-run policy gate 测试。

## 交付顺序

1. `status bar`
2. `privacy`
3. `location`
4. `ui`
5. `pasteboard`
6. `push`
7. `diagnose / logverbose / runtime list-verify`
8. `logs / xctrace / coverage`
9. `pair / unpair / clone / erase / upgrade / runtime maintenance / personalization`
