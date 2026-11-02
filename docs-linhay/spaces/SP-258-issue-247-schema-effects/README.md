# SP-258-issue-247-schema-effects

状态：真实既有 binary RED 已记录，最小实现完成，等待串行 Swift 验证。关联 GitHub [#247](https://github.com/NeptuneKit/TritonKit/issues/247)，issue 保持开放。

## 边界与 BDD

影响层为 shared schema wire model 与 CLI 元数据。审计 act/app/sim/build 全部一层操作；缺失声明初始化或旧 JSON 解码为 unknown，只有显式审计的 reserved sim.type 保留 none。查询、输入、生命周期、文件落盘与构建分别声明潜在效果；混合命令提供带 scope 的条件元数据，未知参数不匹配只读条件。full/compact 与 JSON roundtrip 保留条件。BDD、字段理由及兼容边界见 [方案](plans/20261102-effects-contract.md)。

不改变 parser、执行确认、重试或动作授权。无需人工验收；只运行 schema 查询、parse-only 与模型回归，不操作设备或私有项目。

## 证据与接替

既有 SP256 已验证 binary 的 act.tap/app.launch/sim.boot/build.harmony 查询仍返回 none；断言 exit 1 已保存在同级 archives/SP258/effects-red.log 与四份 before JSON。新测试 SchemaEffectsTests 共 5 个场景，尚未编译运行；此时不宣称 GREEN。

分支 feat/SP-258-issue-247-schema-effects；worktree ../TritonKit-worktrees/SP-258-issue-247-schema-effects。主控串行分配 Swift 槽与 Git 写操作。shared 模型变更要求完整 root/CLI 回归；主控负责独立审阅、CI、集成与发布。未重复实施 #245，仅按授权最小透传新增安全字段。
