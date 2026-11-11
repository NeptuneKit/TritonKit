# SP-284 — Simulator 服务依赖只读诊断

## 来源与边界

采用 [simslim 固定增量](https://github.com/MobAI-App/simslim/compare/d594c230fe9ed5080189b0ce76afabda6104bae0...7e374b3839d49608a681d1f8b9ca0dd83d35189e) 的 MDM、App Clips 和辅助功能资源服务依赖映射，MIT 全文已核验。当前 main `607410fb` 的 features/doctor 对这些名称返回 unknownFeature。

影响 CLI 只读 features/doctor。只增加诊断条目及 `managedByProfiles=false` 说明，不扩展 categories、managedLabels、ci/stock 默认禁用集合，不采用全设备 preboot watch。基础 catalogCommit 保持旧固定版本，新增诊断来源单独注明。上游内存数字未经本地验证。

## BDD

- Given mdm/app-clips/accessibility-assets，When 查询 features，Then 返回固定依赖与只读管理边界。
- Given 对应服务 override=true，When doctor，Then 返回该禁用依赖；false/缺项保持现有 service-overrides-only 语义，不宣称业务可用。
- Given 新诊断服务，When 计算 desired/delta 或选择 keep，Then 既有 mutation 范围不扩张，不接受未管理服务写入。
- Given 未知 feature 或读取失败，Then 保留错误，不产生设备写入。

## 验收

已在当前main串行提交14574a7b并通过提交后完整CLI/local；先失败测试，证据见 `plans/20261111-validation.md`。未执行真实 Simulator、设备操作或上游代码。SP-281 WIP 保持原样，测试结果绑定实际候选文件。
