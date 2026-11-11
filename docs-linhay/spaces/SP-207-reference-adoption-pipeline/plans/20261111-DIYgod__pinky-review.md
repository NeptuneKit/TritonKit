# Pinky 正式登记补查 · 2026-11-11

结论：SP279 已明确登记为正式参考项目，SP207 漏登记应补为 canonical `DIYgod/pinky`、classification `registered_reference`。这不是偶然clone候选，也不等于已经采用。基线为SP279静态研究 `209aa9e4b2ff1fd81edec3c393a64b21b79162fb` / `v2026.1109.16`；其范围是当时入口、设计、MCP、审批、网关、许可与构建配置静态读取，不是全部历史的完整增量检查点，checkpoint保持null。

官方metadata成功：默认main，当前HEAD `3248613b11cb77b263f2a4282209ef9ab79254e7`，latest非draft `v2026.1111.16`；release完整分页2页105项，基线后56个非draft release已归档。Apache-2.0全文hash `c95bae1d1ce0235ecccd3560b772ec1efb97f348a79f0fbe0a634f0c2ccefe2c` 与研究一致。

增量321 commits已用4页compare完整读取；首响应files恰300，不能作为完整文件清单。已采集206份非截断递归树，尚未完成所有parent差异、路径筛选和完整blob/text。按主控要求停止自有collector，未请求二进制/身份材料；没有执行上游代码/依赖/设备。Release重点读到预算/timeout、conversation隔离、resume grace、schema和输入回读等变化，其余完整语义审阅未闭合。保持partial，不能推进checkpoint。

SP279报告、正式深度报告和机制评估仍在；`docs-linhay/references/pinky` 当前不存在，actual main树亦无此入口。历史clone非shallow、固定tag/SHA核验成功是当时事实；当前原clone不可用、丢失原因unknown，不能冒充仍可复核。文件副本在review-local-docs，基线说明见review-local-baseline.json。

SP280/281已经承接ActionContext/admission/receipt与证据，不重复排期；历史研究的“建议下一步”不能作为当前未实现清单。新增Simulator/Emulator、45s预算、MCP数组schema、同名agent多conversation隔离等只是本轮待审线索；未核对完整源代码不判定Triton同源缺陷，也不创建采用项。真机、独立原型、WDA/DDI、签名和UI扩张仍需相应授权。

经验检查完成：登记/基线/读取/采用独立表达，历史读取成功与当前资料可用性分开。无新增仓内规则。
