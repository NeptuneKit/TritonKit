# #251 parser JSON 验收

Given 显式机器输出请求，When ArgumentParser 在执行前拒绝参数，Then stdout 恰好一个合法 JSON：`ok=false`、`action=cli.parse`、`commandPath`（只含注册命令）、`error.code`、静态安全 message、`error.retryable=false`、`error.details`（kind/argumentNames/count）、schema/help recovery。exit 保持64，stderr为空。

先RED再GREEN：`swift test --package-path CLI --build-system native --jobs 2 --no-parallel --filter JSONParserFailureTests`。真实子进程使用同一测试构建目录的triton，有15秒上限和独立文件收集stdout/stderr，避免pipe阻塞；不查PATH旧版。由主控串行安排Swift槽，未执行前不记通过。

场景：sim boot缺udid；issue wait多余参数；未知flag含秘密；非法port含秘密；缺port值；显式format json及等号形式；JSON+非法format；help成功；非法format单独文本fallback；终止符后的--json不启用JSON；runtime schema未知命令仍保留既有typed envelope及exit1。冲突与自定义validate用真实parser fixture额外校验，不执行设备。

安全边界：ArgumentParser公开接口没有typed内部ParserError；只对公开诊断的固定类别前缀作保守识别，不序列化原始诊断、未知参数名、值或整个argv。不识别的校验错误返回通用argument_validation_failed。字段名只能来自当前命令静态help的受信任定义；无法精确归属时返回空名单，不推测。依赖升级需重跑真实parser/进程测试。

非法format本身无法确定JSON意图时沿用原文本诊断；如同时存在独立`--json`则使用安全JSON。重复format以最后一次为准，`--json`优先于format。JSON探测仅处理`--`前选项；不扩充成功命令接受的参数，不重写原argv，不重试失败命令。
