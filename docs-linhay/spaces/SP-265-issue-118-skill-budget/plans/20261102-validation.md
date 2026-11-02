# 2026-11-02 验证

基线 main `572b4afb0881aa61d5f68e3b801c0aeb9e3fe1f3`。先增加字节/行数/单行预算和路由完整性测试，保存旧入口失败，再拆分并复验。原始日志保留 `.build/sp265/`。

## 结果

- RED：`layout-red.log` 保留 8 项中的旧入口真实失败；超过 8192 UTF-8 字节及单行 600 字符预算。此为文档读取体积问题，不是运行时间基准。
- GREEN：新入口 49 行、4784 UTF-8 字节；10 项布局测试、公开 skill 全套 31 项 Python 测试、实际打包/版本 stamp/安装验证及 iOS DEBUG isolation 通过。`layout-green-v2.log`、`skill-package-v2.log`、`debug-isolation.log`。
- 详细块搬移清单见 [SHA-256 清单](20261102-moved-blocks.json)。6 个新主题参考与 3 个原有参考承载原专用正文；只修正搬移后跨 skill 的相对链接。核心流程重写为精简入口，同时明确 open/closed 去重、失败后不盲重放及验收边界。
- 打包在 stamp 后、tar 之前校验字节、行数、最长行、13 个显式路由存在性及长段落重复回灌；解包后再验证。版本戳不会绕过预算，中文短行膨胀反例会拒绝且不生成 tar。
- `verify.sh --ci-docs` 与 `check-docs.sh` 当前退出 1，唯一已报原因是 SP-265 尚未在共享索引登记。主控负责登记后重跑，执行者未改共享索引/memory；不是 docs gate 通过。
- `git diff --check` 通过。无 Swift、锁文件或生成产物变更；未占用设备、未运行共享构建、未提交或推送。
- 主控协调的 #5 role 同节点匹配与 #147 discovery+condition 总 deadline 说明加入 host 参考。这两段是联合候选说明，需与其实现测试一起验收，不以本次文档门禁替代行为测试。

## 可复用经验

公开 skill 入口必须同时约束 UTF-8 字节、行数和最长行；行数不能通过压成长句代替上下文预算。细节保持在按需参考，搬移保留内容与安全边界；发布打包和解包后的实际入口均走同一门禁。该方法由 `verify-public-skill-layout.py` 与测试固化；主控整合时在原发布治理入口/经验索引记录，不新增重复经验文件。
