# Issue 68: Harmony app target failure should not report success

## 背景

真实 Harmony 设备通过 `triton device screenshot --device harmony-real:<id>` 能成功截图，但同一个 redacted device id 用于 `triton app launch/open-url --platform harmony --device harmony-real:<id>` 时，HDC 实际执行输出为：

```text
[Fail]Not match target founded, check connect-key please
```

现象上 JSON 仍返回 `ok:true` / `hostAction.ok:true`，agent 会误以为 App 生命周期动作已提交成功。

## 目标

1. Harmony app lifecycle 命令必须沿用与 screenshot 一致的 target-resolution 结果，真实设备执行命令使用 HDC 可识别的 raw target，公开 JSON 继续只暴露 redacted target。
2. 当 HDC stdout 或 stderr 包含 `[Fail]` 这类语义失败时，即便进程退出码为 0，也必须返回失败 envelope，不能输出 `ok:true`。

## 范围

- 覆盖 `triton app launch/open-url --platform harmony --device harmony-real:<id>` 的 host action 失败判定。
- 不新增 Web/Wails 入口。
- 不触碰真实设备、不调用裸 `hdc` 做副作用验证；本轮用 fixture/单元测试锁定 CLI host runtime 语义。

## BDD 场景

### 场景 1：真实 Harmony 设备 app launch 使用 raw HDC target

Given `device list/resolve` 返回一个真实 Harmony target，其公开 id 为 `harmony-real:<hash>`，raw target 为 `HDCREAL001`  
When agent 以 `--device harmony-real:<hash> --platform harmony` 规划 app launch/open-url  
Then 生成的 HDC 命令必须使用 `-t HDCREAL001`  
And JSON 中的公开 target / sourceCommand 不泄露 raw target。

### 场景 2：HDC stdout 含 `[Fail]` 时 app launch 返回失败

Given HDC 进程退出码为 0  
And stdout 为 `[Fail]Not match target founded, check connect-key please`  
When Triton 执行 Harmony app launch/open-url 的 host command  
Then CLI 必须进入 `failHostCommand` 失败路径  
And JSON envelope 必须为 `ok:false`  
And 错误码应落到 app launch/open-url 对应的 host action failure，而不是 `ok:true`。

## 验收

- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue68 --filter AppOpenURLFlowTests`。
- 通过：`swift test --package-path CLI --scratch-path .build/cli-issue68 --filter SimulatorAdvancedControlsTests`。
- 待运行：`git diff --check` 与 `docs-linhay/scripts/check-docs.sh`。
- 只提交 issue #68 相关代码与文档，不 push、不 merge、不关闭 issue。
