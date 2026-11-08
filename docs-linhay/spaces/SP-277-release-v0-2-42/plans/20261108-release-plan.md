# v0.2.42 发布计划与证据

1. SP276根/CLI完整测试及真实CLI fake-HDC白盒验收完成，产品候选精确PR CI与合后mainCI必须通过。
2. 旧版本对0.2.42失败已保留；版本升级后的一致性、release automation、skills/public commands、Web npm ci/build与docs门禁通过。
3. 本机标准Pod lint、完整local gate与远端标准Pod必须各自记录结果。合并候选后在clean发布clone复用缓存运行local gate；同一scratch串行。
4. 精确main与review diff核对，创建新tag，等待Release及tagCI；新鲜下载双架构/assets/checksum/skills核对后更新Homebrew与两个skills roots。
5. 从/tmp无root覆盖启动packaged Web，HTTP、complete readonly gesture拒绝与真实浏览器console/assets；本JSON读取切片安装CLI fake-HDC3/3。发布不替代人工IME/私有App/默认iPad验收。

共享19421当前PID37393，执行路径Cellar0.2.41；升级禁止清理该旧版本。34129/PID49812是本轮自有0.2.41 smoke，升级前停止。旧文档PID仅历史状态，不操作。


本机标准Pod lint失败：Xcode27.1拒绝iOS13 deployment target，原minimum不改。另行用临时XCODE_XCCONFIG_FILE/iOS15兼容lint退出0且明确TritonKit passed validation；不替代远端标准Pod。原日志保留，未推trunk。
