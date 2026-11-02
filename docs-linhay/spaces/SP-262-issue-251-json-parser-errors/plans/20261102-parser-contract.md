# #251 parser JSON 验收

Given 显式机器输出请求，When ArgumentParser 在执行前拒绝参数，Then stdout 恰好一个合法 JSON：`ok=false`、`action=cli.parse`、`commandPath`（只含注册命令）、`error.code`、静态安全 message、`error.retryable=false`、`error.details`（kind/argumentNames/count）、schema/help recovery。exit 保持64，stderr为空。

先RED再GREEN：`swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter JSONParserFailureTests`。真实子进程使用同一测试构建目录的triton，有15秒上限和独立文件收集stdout/stderr，避免pipe阻塞；不查PATH旧版。由主控串行安排Swift槽，未执行前不记通过。

场景：sim boot缺udid；issue wait多余参数；未知flag含秘密；非法port含秘密；缺port值；显式format json及等号形式；JSON+非法format；help成功；非法format单独文本fallback；终止符后的--json不启用JSON；runtime schema未知命令仍保留既有typed envelope及exit1。冲突与自定义validate用真实parser fixture额外校验，不执行设备。

安全边界：ArgumentParser公开接口没有typed内部ParserError；只对公开诊断的固定类别前缀作保守识别，不序列化原始诊断、未知参数名、值或整个argv。不识别的校验错误返回通用argument_validation_failed。字段名只能来自当前命令静态help的受信任定义；无法精确归属时返回空名单，不推测。依赖升级需重跑真实parser/进程测试。

非法format本身无法确定JSON意图时沿用原文本诊断；如同时存在独立`--json`则使用安全JSON。重复format以最后一次为准，`--json`优先于format。JSON探测仅处理`--`前选项；不扩充成功命令接受的参数，不重写原argv，不重试失败命令。

## 整合 argv 验收中的测试夹具修正

2026-11-02，主控使用实际整合 binary 发现 `sim boot --SECRET_251 --json` 同时缺少必填 UDID，ArgumentParser 优先报告 `missing_argument`，原 unknown-option 测试的预期错误。因此只将该用例补为 `sim boot fixture-udid --SECRET_251 --json`，单独触发未知选项；合成 UDID 不表示真实设备，解析失败必须发生在执行前。生产分类及优先级未改。本次子任务仅修改测试与此记录，未构建或运行测试；GREEN 由主控串行复验后记录，不把夹具修正本身当通过。

## 完整 CLI 回归发现与修正

主控组合全量实际执行1717 tests、记录14 issues，原始日志为联合工作区归档的 `integrated-cli-full.log`。其中旧CLIHelpTests的 `state route --json` 仍断言stderr人类提示，与显式JSON契约冲突；同时新JSON路径丢失了原静态迁移提示。这两项不能通过删除断言解决：保留不带JSON的人类提示测试全部断言，新增JSON exit64/空stderr/单envelope/值脱敏断言，并把受信任retired-root映射提示以可选 `error.hint` 写入JSON和schema，不改变原错误分类优先级。

该次回归另发现新进程测试将 `--test-bundle-path` 错当bundle目录，实际传入 `.xctest/Contents/MacOS/...` executable，因而寻找错误的 `Contents/MacOS/triton`。修正为向上查找 `.xctest` 祖先后选择其同级 `triton`，兼容macOS bundle及Linux `.xctest` 文件；新增纯路径回归，不复制binary、不回退PATH或其他scratch。以上为真实失败后的候选修正，尚未运行新build，需主控focused与完整CLI复验后才记录GREEN。
