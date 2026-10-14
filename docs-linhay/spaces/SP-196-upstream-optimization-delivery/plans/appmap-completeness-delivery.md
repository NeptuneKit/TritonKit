# SP-196 AppMap / 测试执行完整性

## Requested / BDD

- 空 suite 在创建 flow/evidence 前失败，不产生 passed 或 executor 调用。
- screens/transitions/paths 按 stable ID 排序，默认100项、最大1000项，offset分页有总数和续页指针，保留 evidenceRefs。
- 全 optional 失败/blocked 或空 normalized override 的 test run 为 blocked/no_successful_steps；至少一个 primitive通过时保留 optional失败不阻塞原语义。

## Observed

listing 无输出边界；suite.failedCount==0 将零结果判 passed；test runtime 默认为passed，optional失败全部continue。

## Fixes

- `map screens|transitions|paths` 接受 `--offset`（默认0、非负）和 `--limit`（默认100、1...1000）。非法页在map发现前返回 `invalid_app_map_page`。
- 保留原 screenCount/transitionCount/pathCount 为总数，增加 totalCount/returnedCount/truncated/nextOffset；truncated为returnedCount<totalCount（包括offset略过前缀），nextOffset单独表达续页，无剩余项时省略。返回数组按stable ID排序，完整保留实体和evidenceRefs。显式静态viewer导出读取全量，避免CLI默认页截断导出内容。
- 空suite在创建flow/evidence前返回 `empty_app_map_suite`。
- run仅在至少一个primitive.status=passed时允许passed；全optional失败/blocked及空override返回blocked、failure.type=`no_successful_steps`。mandatory失败保持原失败类型，已有成功primitive+optional失败继续保留passed。run.finished携带final failure；report.failure优先使用最终run.finished.failure，缺失时保留first failure.recorded兼容原optional失败报告。
- 将既有AppMap DTO与小辅助函数、TestRun DTO与小证据helper机械移出超1500行旧文件；Runtime分别约1400/1460行，未重构执行器。

## Evidence

新增AppMapCompletenessTests：分页顺序/续页/evidenceRefs、105 screen默认100项上限、非法参数优先失败、empty suite无输出目录无executor调用、全optionalfailed/blocked、空override。既有AppMapPathGraphTests/TestRunExecutionTests覆盖正常suite与optional失败继续执行。

owned源parse与diff--check通过。首次测试先写、CLI red构建被同批尚未定义typed-prefs接口拦截；实现后focused CLI build被共享selection private访问拦截（已通知主控，未改他人文件）。初期两次暂态构建日志保存在 `.triton/sp196-framebuffer/appmap-red.log` 与 `appmap-tests.log`。

主控随后全CLI运行1318项测试：本轨道 AppMapCompletenessTests 8项、AppMapPathGraphTests 10项、TestRunExecutionTests 10项全部通过（分别0.079/0.173/0.055秒）；同次 FramebufferHelperTests 11项也通过（2.335秒）。记录在 `.triton/sp196-validation/cli-full.log`。该次全CLI其余轨道/既有环境共44issues，由主控继续修复，不把本轨道通过等同整个门禁通过。

## Gaps / Remaining risk

只使用本地fixture与fake executor，不操作设备/服务。分页限制输出条目，不保证读取全量map时的内存或磁盘总量；offset不是事务快照，调用间map变化会影响页内容。分页DTO新字段为当前输出，未迁移旧存储的list-response缓存。

## 主控最终验证

主控最终CLI完整回归通过，分页/empty suite/finished failure/no_successful_steps场景无失败。
