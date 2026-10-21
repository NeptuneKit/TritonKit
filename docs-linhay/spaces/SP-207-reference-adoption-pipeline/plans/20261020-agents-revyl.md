# 2026-10-20 agents/revyl 只读监测

影响层：参考研究；对照实际 main `f82872e2fa457431ee7cbc7df2bafecea7ca6f1c`。只写本目录；未运行第三方源码/设备/产品写操作/依赖安装/新会话。SP210、SP212已本地主线集成；Simulator AX devicePointSize 已拒绝缺失几何并调用校验转换，不再报告393×852/scale3旧兜底缺口。

每仓官方GitHub metadata确定默认分支、固定HEAD；Release完整分页，含prerelease并排除draft。许可证从固定HEAD官方端点取全文/hash；无正文严格partial，纠正昨日absence被当complete的口径。变化仓全部commit详情分页保留，源码抓取有界收敛，未完成全部patch/source逐项人工审阅，保留旧成功点。

|仓库|HEAD|Release|完整性|裁决|
|---|---|---|---|---|
|[getsentry/MobileBuildMCP](https://github.com/getsentry/MobileBuildMCP/tree/d13ff0c707b0681769cf31da0eb42c4f94ceafff)|d13ff0c707b0|v2.7.1|complete|covered|
|[awizemann/harness](https://github.com/awizemann/harness/tree/3f58c077ded131cca71d75efb05c5d325f0ed18f)|3f58c077ded1|v0.8.4|complete|covered|
|[dongxinsuperman/ai-phone](https://github.com/dongxinsuperman/ai-phone/tree/d339057bc64aa85002570765e2a20d45e0391bae)|d339057bc64a|v0.8.0|complete|adopt|
|[karminski/eyes-on-my-phone](https://github.com/karminski/eyes-on-my-phone/tree/eef71926e613c3242643923bb21c92beab439990)|eef71926e613|none|partial|covered|
|[RevylAI/revyl-cli](https://github.com/RevylAI/revyl-cli/tree/122fb01b191590384909b23884ed5119f1eff2c0)|122fb01b1915|v0.1.178|partial|observe|
|[RevylAI/app-explorer](https://github.com/RevylAI/app-explorer/tree/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e)|b3edc443dbfb|none|partial|reject|
|[RevylAI/greenlight](https://github.com/RevylAI/greenlight/tree/fcb36e395bd4ae20448f2535382baecba9396fd9)|fcb36e395bd4|v0.2.0|complete|reject|
|[RevylAI/mobile-devtools](https://github.com/RevylAI/mobile-devtools/tree/efc1dae5da089ec08108a39f1ead39324c11b410)|efc1dae5da08|none|partial|reject|
|[RevylAI/mobile-pr-reviewer](https://github.com/RevylAI/mobile-pr-reviewer/tree/ba1250c72f56a08f3718aefc82dc911c1b3a2f23)|ba1250c72f56|none|partial|reject|
|[RevylAI/visual-regression](https://github.com/RevylAI/visual-regression/tree/2758e8a88f4efb3a251b675e0984c091bf8abeb8)|2758e8a88f4e|none|partial|reject|
|[RevylAI/figma-design-checker](https://github.com/RevylAI/figma-design-checker/tree/8b4e5cea045dcff5c30aa723b923e514d2cdc07a)|8b4e5cea045d|none|partial|reject|
|[RevylAI/CogniSim](https://github.com/RevylAI/CogniSim/tree/3d8902e011981b93cb0ebfafba1794eab93b053e)|3d8902e01198|none|complete|reject|

## getsentry/MobileBuildMCP
HEAD/Release无新增；沿用既有CLI/HTTP接管与观察边界，不声称功能完全等价。SP210/SP212已经本地主线交付。
固定来源：[HEAD](https://github.com/getsentry/MobileBuildMCP/commit/d13ff0c707b0681769cf31da0eb42c4f94ceafff)；[增量](https://github.com/getsentry/MobileBuildMCP/compare/d13ff0c707b0681769cf31da0eb42c4f94ceafff...d13ff0c707b0681769cf31da0eb42c4f94ceafff)。
许可证：[固定全文](https://github.com/getsentry/MobileBuildMCP/blob/d13ff0c707b0681769cf31da0eb42c4f94ceafff/LICENSE)；SHA256 `fef28fc4165c72b1f0e4ce94654ba44ad7ff7d5d2538b3d01e66e9cc5be3c4f6`。
最新非draft Release：[固定tag](https://github.com/getsentry/MobileBuildMCP/releases/tag/v2.7.1)，prerelease=False。

## awizemann/harness
HEAD/Release无新增；沿用既有CLI/HTTP接管与观察边界，不声称功能完全等价。SP210/SP212已经本地主线交付。
固定来源：[HEAD](https://github.com/awizemann/harness/commit/3f58c077ded131cca71d75efb05c5d325f0ed18f)；[增量](https://github.com/awizemann/harness/compare/3f58c077ded131cca71d75efb05c5d325f0ed18f...3f58c077ded131cca71d75efb05c5d325f0ed18f)。
许可证：[固定全文](https://github.com/awizemann/harness/blob/3f58c077ded131cca71d75efb05c5d325f0ed18f/LICENSE)；SHA256 `e92a5a769096faed8e22dea8d940ce64a6a00638f0f0a4f74a056eb61c52549c`。
最新非draft Release：[固定tag](https://github.com/awizemann/harness/releases/tag/v0.8.4)，prerelease=False。

## dongxinsuperman/ai-phone
6提交：现有Ark线路DeepSeek兼容、三次XML格式重生成/有效视觉历史、Harmony VM端口租约及折叠启动诊断。VLM协议属于上游agent；VM资源池/预留属于上游管理器，当前Triton本机接管未采用该云VM控制面。SP210几何fail-closed已本地主线集成，不重复旧缺口。上游配对评测与测试自述未本地复验。
固定来源：[HEAD](https://github.com/dongxinsuperman/ai-phone/commit/d339057bc64aa85002570765e2a20d45e0391bae)；[增量](https://github.com/dongxinsuperman/ai-phone/compare/4cac05b50b6acdee0b5157f2a089c15de8668cea...d339057bc64aa85002570765e2a20d45e0391bae)。
许可证：[固定全文](https://github.com/dongxinsuperman/ai-phone/blob/d339057bc64aa85002570765e2a20d45e0391bae/LICENSE)；SHA256 `b825925aa35feb626875db9db2afc4f71e8cf0abeb1f1bcecfa23efa307a17ce`。
最新非draft Release：[固定tag](https://github.com/dongxinsuperman/ai-phone/releases/tag/v0.8.0)，prerelease=False。

## karminski/eyes-on-my-phone
HEAD/Release无新增；沿用既有CLI/HTTP接管与观察边界，不声称功能完全等价。SP210/SP212已经本地主线交付。
固定来源：[HEAD](https://github.com/karminski/eyes-on-my-phone/commit/eef71926e613c3242643923bb21c92beab439990)；[增量](https://github.com/karminski/eyes-on-my-phone/compare/eef71926e613c3242643923bb21c92beab439990...eef71926e613c3242643923bb21c92beab439990)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/revyl-cli
8提交/168比较文件：v0.1.178、Web登录契约、git branch/build选择上下文、workflow轮询fallback与script_timeout报告。专有托管服务契约和MCP/Web会话不进入当前Triton边界；无仓级许可且增量源码复核partial，不复制、不建立新采用任务。
固定来源：[HEAD](https://github.com/RevylAI/revyl-cli/commit/122fb01b191590384909b23884ed5119f1eff2c0)；[增量](https://github.com/RevylAI/revyl-cli/compare/53a9e876207bd9813b4ba53b5a9a7a68be9f22d6...122fb01b191590384909b23884ed5119f1eff2c0)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。
最新非draft Release：[固定tag](https://github.com/RevylAI/revyl-cli/releases/tag/v0.1.178)，prerelease=False。

## RevylAI/app-explorer
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/app-explorer/commit/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e)；[增量](https://github.com/RevylAI/app-explorer/compare/b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e...b3edc443dbfbd8fe84b0fb0bc7c3190cb233c41e)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/greenlight
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/greenlight/commit/fcb36e395bd4ae20448f2535382baecba9396fd9)；[增量](https://github.com/RevylAI/greenlight/compare/fcb36e395bd4ae20448f2535382baecba9396fd9...fcb36e395bd4ae20448f2535382baecba9396fd9)。
许可证：[固定全文](https://github.com/RevylAI/greenlight/blob/fcb36e395bd4ae20448f2535382baecba9396fd9/LICENSE)；SHA256 `960890e59731cd6468788d6045407429c1c6ff1e1508d1c8bd77dd0b1a5807ca`。
最新非draft Release：[固定tag](https://github.com/RevylAI/greenlight/releases/tag/v0.2.0)，prerelease=False。

## RevylAI/mobile-devtools
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/mobile-devtools/commit/efc1dae5da089ec08108a39f1ead39324c11b410)；[增量](https://github.com/RevylAI/mobile-devtools/compare/efc1dae5da089ec08108a39f1ead39324c11b410...efc1dae5da089ec08108a39f1ead39324c11b410)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/mobile-pr-reviewer
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/mobile-pr-reviewer/commit/ba1250c72f56a08f3718aefc82dc911c1b3a2f23)；[增量](https://github.com/RevylAI/mobile-pr-reviewer/compare/ba1250c72f56a08f3718aefc82dc911c1b3a2f23...ba1250c72f56a08f3718aefc82dc911c1b3a2f23)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/visual-regression
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/visual-regression/commit/2758e8a88f4efb3a251b675e0984c091bf8abeb8)；[增量](https://github.com/RevylAI/visual-regression/compare/2758e8a88f4efb3a251b675e0984c091bf8abeb8...2758e8a88f4efb3a251b675e0984c091bf8abeb8)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/figma-design-checker
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/figma-design-checker/commit/8b4e5cea045dcff5c30aa723b923e514d2cdc07a)；[增量](https://github.com/RevylAI/figma-design-checker/compare/8b4e5cea045dcff5c30aa723b923e514d2cdc07a...8b4e5cea045dcff5c30aa723b923e514d2cdc07a)。
仓级许可证正文未取得；官方404原始响应见license.json.error，不能认定复制授权或完整检查。

## RevylAI/CogniSim
本轮未见HEAD增量；Revyl专有云服务/设计与PR工作流不纳入本机CLI/HTTP产品面，许可缺失时不复制。
固定来源：[HEAD](https://github.com/RevylAI/CogniSim/commit/3d8902e011981b93cb0ebfafba1794eab93b053e)；[增量](https://github.com/RevylAI/CogniSim/compare/3d8902e011981b93cb0ebfafba1794eab93b053e...3d8902e011981b93cb0ebfafba1794eab93b053e)。
许可证：[固定全文](https://github.com/RevylAI/CogniSim/blob/3d8902e011981b93cb0ebfafba1794eab93b053e/LICENSE)；SHA256 `0b62f99f70ef4368aa74efec94d64c4dca5f31d7f5eb8261f4166160fe1ee93d`。

经验检查：本轮发现许可缺失完整性口径需由root回写原权威资料；本agent无共享文档写入权。原始证据和partial边界已记入results；不推进任何checkpoint。Swift/产品测试不适用于纯只读监测；JSON与证据计数本地校验。

## 补审闭环

ai-phone 6提交全部patch与23个最终固定HEAD变更源码/测试已补齐；`supplement-source-index.json`为逐文件读取索引，全部成功，无缺失文件。人工核对了DeepSeek采样兼容、三次同图XML语法重生成、无效输出不驱逐有效视觉历史、提示词回退/恢复关系、VM旧租约与新unused reservation分离、折叠初始化预算/连续尺寸确认以及fport清理隔离fixture。该仓改为complete；不代表运行上游测试或设备验收。

新增可纳入切片：HDC forward teardown归属复核。上游d339057改为在分配锁中读取当前fport listing，按target/local/remote/forward方向筛选，拒绝缓存端口或他人归属。真实main `CLIHostHarmonyArkWebRuntime.swift:171,265`直接按本次缓存端口rm，相关测试只覆盖命令/清理失败，未覆盖他人target/端口重分配。BDD和文件面见results.assessment；仅采用安全机制，不采用云VM控制面。上游关于HDC全局语义的实机主张未经本轮验证，实施时先核官方契约与fixture。MIT全文已保存。

Revyl固定HEAD核心10文件已补读：git branch探测绑定项目目录与CI/提交身份、显式选择优先、Git 5秒预算和64KiB输出上限；workflow fallback来源与app/build/branch身份在SSE、轮询、旧/缺最终报告间保留。Triton暂无同类托管branch-build/workflow产品模型，观察机制，不扩大云控制面。其余非核心168文件未全部源码复核、root许可仍404，保持partial。

此补审替代前述ai-phone整体partial与“无adopt”初稿判断；SP210几何和SP212 Android契约仍已覆盖，不重复立项。
