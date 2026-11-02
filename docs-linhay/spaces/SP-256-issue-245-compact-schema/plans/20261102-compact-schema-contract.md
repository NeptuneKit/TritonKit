# Compact leaf schema 契约

影响层为 CLI 只读 discovery；不访问 server、设备或 App，不改变执行命令的 parser/dispatch。新增 `triton schema --command act.type --compact --json`；未指定 compact 时沿用完整 schema response。

## 投影规则

- 显式指定可解析叶子；缺少 command、分组节点或未能解析的 option/output selector 返回单一 typed error 与完整 schema 恢复命令。不能把未解析引用静默删除。
- 从 root option/argument declarations 解析叶子所需引用，沿 ancestry 应用 override，叶子优先；合并 required、optional；selectorConstraints 保留每层 source 的独立约束。legacy 单列表与全 singleton 列表归一化 exactlyOneOf，complete alternatives 按 source 保留 exactlyOneOptionSet；歧义/空候选组 typed incomplete，不能把跨层 alternatives flatten 为单组。不携带兄弟 option/contract。
- 保留 root outputSemantics 原文及 failureShape；requirements 采用保守 root/ancestor OR，因为现有模型 false 与 none 没有“未声明”标记。未声明副作用输出 unknown，不据此授权自动重试。root/ancestor 的失败、恢复、artifact/event 元数据保留。output contracts 只选叶子引用。
- `test.run` 的权威 schema 补齐既有 parser 支持的 `--vlm-model-path` 与 `--vlm-allow-model-download`（默认 false）；测试仅 parse，不下载或执行模型。
- `act.type` 的权威 schema 增加 `<text>` 与 `--text` exactly-one 约束及 text-input 副作用，与既有 parser 一致。
- `projectionVersion` 区分投影协议；`cliVersion` 使用现有制品版本。`fingerprint` 是去掉 fingerprint 字段后的 sorted-key JSON SHA256，包含版本与完整投影内容。点式/空格式 command 规范化为同一 dot path。

## 验证边界

测试包括 act.type/test.run 参数、alias、继承 override、安全语义、缺失引用拒绝、默认 full 不变、parser opt-in 和确定性 hash。真实进程测量 UTF-8 bytes，test.run compact 小于 full 的 50%；字节减少不代表网络或动作执行耗时下降。最终主控执行完整 CLI 与必要 CI，设备场景不适用。
