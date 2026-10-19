# RevylAI/revyl-cli 增量补审

结论：限定适用性审阅 complete=true。完整覆盖 16 提交的查询与 245 条 commit-file 清单（161 个路径），不是全仓审计，也不宣称 433849 bytes 测试全部人工逐行阅读。没有证据足以新增当前 TritonKit 本机 CLI/HTTP 实现任务；checkpoint 由主控结合原报告裁决。

固定上游 HEAD 为 `86de7c9797f98060cf465792367b3a662cd59cf4`，本地比较对象为 main `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`。未使用当前 WIP HEAD 代替 main。原证据在 `../agents-revyl/RevylAI__revyl-cli/`，补证据全部位于本目录。

## 覆盖与方法

所有 16 提交分页完整，其中 15c4bb 有两页。配置、Web、hotreload、MCP、docs 与 generated 共 87 条记录按不超过约 400 行小页补读完整文本 patch，原 aggregate 截断不能算阅读的缺口已补。other 76 条记录完整阅读新增/删除两面，client/workflow settings/时长/launch env/report summary 等关键 patch 另行全文阅读；未变化 context 不声称逐行重复审计。前 agent 已读主要 HEAD 源码的记录作为继承证据，不冒称本补审又读全文件。

测试组 82 条按逐项清单裁决：30 条完整读取变更文本，16 条 pyc 只验证身份，2 条共享 compiler fixture 预期投影明确排除人工逐行审阅，34 条云 Web/workflow/hosted 插件或重复测试只索引后排除。测试组误纳的 `cmd/revyl/test.go` 与 `internal/schema/yaml_test_schema.go` 是产品源码，已单独完整补读，内容为云 Web 平台与 YAML 规格扩展。相关关键阅读含 action timing、private text、token、diagnostics、typed error、relay cleanup、readiness、导航、launch-env 与 native normalization。

相关断言确认源码的设计意图：每物理请求一次、grounding 失败不降级输入、applied/uncertain 不自动重放、stale token 要求新观察、anchor 绑定 session 且文件0600、secret-env 不回显/不发送变量名、safe allowlist 不泄露任意错误体、时长兄弟字段独立过滤、relay 握手失败清理连接。这里只读测试与实现，不代表执行通过。

36 条无文本 patch 均有可追溯处置。32 个 pyc commit-file blob 均 base64 解码并核对 Git blob SHA1、声明字节大小及 SHA256，可关联两个 `.py` 来源路径；未执行或反编译，不能据此证明二进制行为。补取 15c4bb 缺少的两个 pyc 与 openapi blob 后闭合。

OpenAPI 对 4 次变更及首个 parent 共 5 个固定 blob 完整递归结构比较，变化数分别为 5、42、3、3。非 Web 变化完整语义读取：runtime checker 去重 summary/stack/frame、core-data/unclassified crash、customer image UUID/相对offset/architecture，以及 Capy proof harness。42 项 Web 结构值不逐行人工审计，通过结构路径、手写实现与 generated DTO 完整 patch 核对后按产品范围排除；不是漏掉相关本机机制。生成 DTO、union marshal/discriminator、allowlist 和 uv.lock 版本 patch 均已完整阅读。

Release 查询保存89条，最新稳定非draft为 v0.1.167（2026-10-16T06:44:13Z），完整读取其 body 与15项资产元数据；没有下载或运行。HEAD版本0.1.170不冒称已发布。README/规格变更全文已读；旧README未变部分由原阅读证据继承，不重复全文审计。

## 适用性裁决

云 Web build、sign-in JWS、viewer、exploration、workflow 与 hosted Claude/Grok/Capy 均观察，不自动引入本地产品控制面。screen token、unknown/no replay、stdin 私密输入已有本地契约依据；main 的 action execution 源码完整只读核对确认 unknown/not_started 不能变成验证成功。上游 runtime checker 在本仓增量中只有云报告DTO与展示，缺少本地采集/解析证明，不能把它标作可直接采用的 sanitizer 能力。env prefix 与 native recipe 按平台修正可记录思想，架构不同尚未证明本地缺口。

主体 LICENSE 官方端点404；README MIT badge不足以证明授权。两份插件README的MIT仅限其声明范围，不外推主体。

## 未知与验证边界

范围内无剩余必读项；上游云后端、真实设备/服务行为与全仓许可证仍未知。未执行上游、设备、依赖安装或 Git 写入。生成数据与排除测试的精确列表见 `change-reading-inventory.json`；机器结果见 `review.json`。身份与结构证据见 `binary-classification.json`、`openapi-structural-diff.json`。没有修改共享state/checkpoint；本轮证据完整性修正由root写回原权威资料，无需新增重复经验文件。
