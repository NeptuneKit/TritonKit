# 20260623 Open Issues 89-91

## 背景

本轮处理 GitHub open issues #89、#90、#91，范围限定为 Triton CLI/Schema 的机器可读契约与本机 host adapter 行为，不恢复 Web/Wails 控制面。

## 验收场景

### #89 server_unavailable recovery plan

- Given agent 请求 triton plan open-url --json 且本地 runtime server 不可达
- When plan 返回 mode=bootstrap
- Then steps[] 给出启动 server、等待 target、诊断的恢复步骤
- And afterRecoverySteps[] 保留原始 open-url / wait / assert / evidence 目标步骤
- And primaryNextAction 仍指向启动 server，不让 agent 跳过恢复

### #90 Harmony list-emitted id install

- Given triton device list --platform harmony --json 产出 harmony:<hdc-target> id
- When agent 把该 id 传给 triton app install --device harmony:<hdc-target> --hap <path> --json
- Then selector 解析到同一个 raw HDC target
- And install command 使用 hdc -t <hdc-target> install -r <path>

### #91 iOS Simulator tap discovery

- Given 当前 Xcode simctl io help 不提供稳定 tap primitive
- When agent 读取 triton schema --command sim --json 或 triton sim --help
- Then 默认发现面不暴露可执行 iOS simulator host tap
- And 显式调用残留命令时仍返回 unsupported_host_input，不伪造成功

## 非目标

- 不新增私有 HID / SimulatorKit 输入实现。
- 不新增 Web/Wails 控制入口。
- 不关闭未验证或本轮范围外 issue。
