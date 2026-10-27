# mobile-next/mobile-mcp 2026-10-27只读评估

完整增量审阅：通过；结论：observe；main `cfda992467fc1ed19ef0c577577c313d79314069`。

2提交/8文件：install命令通过add-mcp检测全局MCP客户端并upsert配置；TTY交互选择，--yes或非TTY默认全部，懒加载ESM；新增依赖与node16模块配置及文档。SP-200明确排除标准MCP接入，Triton CLI采用Swift/ArgumentParser+Hummingbird而非MCP server，不存在此安装入口需求；不得为追平上游扩张到自动修改用户客户端配置。SP-212前台activity/shell字面量机制已在main，不重复采用。

## BDD验收边界

- Given当前产品排除标准MCP接入，When观察install命令，Then保持observe，不新增客户端配置写入或依赖安装。
- GivenSP-212已合入main，When复核foreground和inputText实现，Then活动身份可信解析与shell字面量编码仍存在，不重复建立采用项。
- Given未来另行授权MCP配置安装，When非TTY或多客户端执行，Then须先定义显式目标、dry-run、配置保留、部分失败与单JSON契约；不可直接照搬非TTY自动写全部行为。

## 未验边界

- add-mcp依赖仅审阅manifest/锁定版本和调用点；未获取其包源码、用户客户端配置或执行安装。
- 无上游测试文件变化；没有把上游声明当成本地运行验收。

比较与逐commit分页证据见同目录JSON；Release全文已对照已有分页，许可全文hash匹配。未执行第三方代码、安装依赖、设备动作、git写入或checkpoint推进。
