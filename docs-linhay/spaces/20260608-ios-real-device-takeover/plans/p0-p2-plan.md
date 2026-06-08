# iOS Real Device Takeover P0-P2 Plan

## P0：只读发现与诊断

目标：让 agent 可以安全判断真机是否可用，不执行安装或启动。

范围：

1. `DevicectlAdapter` command builder 与 JSON parser。
2. `triton device doctor --platform ios --scope real --json`。
3. `triton device list --platform ios --scope real --json`。
4. `triton device use/resolve/current` 支持 `kind=real-device`。
5. `triton device wait-ready --device <selector> --jsonl` 支持 connected/trusted/developer-mode/locked 状态轮询。
6. Schema、错误码、nextAction、fixtures、redaction。

红灯测试：

1. ready/offline/not trusted/locked/malformed devicectl JSON fixtures。
2. `--scope real` 不与 simulator target 混淆。
3. alias 指向离线真机时不能自动改选。
4. devicectl JSON/log 输出路径存在或是 symlink 时拒绝执行。

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command device --json
docs-linhay/scripts/check-docs.sh
```

## P1：安装、启动与 runtime ready

目标：真机 Debug App 能通过 Triton 完成 install、launch、open-url 和 embedded runtime ready 验证。

范围：

1. `triton app install --device <selector> --app <path.app> --json` 走 `devicectl device install app`。
2. `triton app launch --device <selector> --bundle-id <id> --json` 走 `devicectl device process launch`。
3. `triton app open-url <url> --device <selector> --bundle-id <id> --json` 走 launch `--payload-url`。
4. `--wait-ready` 串接现有 runtime status/wait。
5. devicectl action summary 显式导入 evidence。
6. 失败映射覆盖 app install/launch/runtime 三段。

红灯测试：

1. install/launch command builder argv。
2. install 成功 JSON -> normalized app action summary。
3. launch 成功 JSON -> pid/bundle id summary。
4. wait-ready 时 app launch 成功但 runtime 未连，返回 `runtime_not_connected`。
5. `--payload-url` 与 open-url schema 示例稳定。

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command app --json
.build/cli/debug/triton device doctor --platform ios --scope real --json
```

有真机时追加：

```bash
.build/cli/debug/triton device list --platform ios --scope real --json
.build/cli/debug/triton app install --device <alias> --app /tmp/Demo.app --json
.build/cli/debug/triton app launch --device <alias> --bundle-id <bundle-id> --wait-ready --json
```

## P2：Xcode build/test/run 与证据闭环

目标：从 repo 到真机 smoke 的完整 agent 路径可复跑。

范围：

1. `triton xcode use --device <selector>` 写入 `iphoneos` destination。
2. `triton xcode build --device <selector> --jsonl`。
3. `triton xcode run --device <selector> --jsonl`：build -> app path -> install -> launch -> optional runtime wait。
4. `triton xcode test --device <selector> --result-bundle <path> --jsonl` opt-in 支持。
5. `triton logs collect --device <selector> --bundle-id <id> --duration <seconds> --output <dir> --json`。
6. `triton smoke ios --device <selector> ...` 串起 build/install/launch/assert/evidence。

红灯测试：

1. Xcode defaults round-trip 支持 `device`、`sdk=iphoneos`、real destination。
2. signing/provisioning 常见失败映射为稳定错误码。
3. `xcode run --device` final summary 包含 device、app、bundle、runtime target binding。
4. logs artifact summary 不内联大日志。
5. evidence manifest primary artifacts 优先展示 xcode action summary、devicectl action、runtime snapshot。

验收：

```bash
swift test
swift build --package-path CLI --scratch-path .build/cli --product triton
.build/cli/debug/triton schema --command xcode --json
.build/cli/debug/triton schema --command logs --json
docs-linhay/scripts/verify.sh --local
```

有真机和可签名 Demo App 时追加：

```bash
.build/cli/debug/triton xcode use --workspace Demo.xcworkspace --scheme Demo --configuration Debug --device <alias> --json
.build/cli/debug/triton xcode run --device <alias> --jsonl
.build/cli/debug/triton smoke ios --device <alias> --bundle-id <bundle-id> --open-url example://debug --wait-text Ready --json
```

## 后续不进 P0-P2 的能力

1. 系统级 HID、Home、App Switcher、隐私弹窗自动化。
2. 真机屏幕级截图和录屏，除非后续确认官方 CLI 有稳定且隐私可控的机器接口。
3. LLDB attach / breakpoint / eval。
4. sysdiagnose、reboot、uninstall 等 destructive 或高风险动作。
5. 远端真机、设备云、CI farm、Web/Wails 管理页面。
