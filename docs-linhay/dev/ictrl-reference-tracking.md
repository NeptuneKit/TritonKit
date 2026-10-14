# iCTRL 长期参考与更新追踪

- 上游：[OpenMinis/iCTRL](https://github.com/OpenMinis/iCTRL)。
- 决策：正式列为 TritonKit 长期参考项目，自 2026-10-14 起持续追踪。
- 追踪事实源：[SP-193](../spaces/SP-193-ictrl-reference-tracking/README.md)；检查点：[upstream-state.json](../spaces/SP-193-ictrl-reference-tracking/plans/upstream-state.json)。
- 已有借鉴工作：[SP-192](../spaces/SP-192-ictrl-adoption-feasibility/README.md) 与 [技术接入边界](./20261014-ictrl-agent-feedback-adoption.md)。

## 上游基线

2026-10-14 通过 GitHub 官方仓库页面及 API 核对：默认分支 `main`，HEAD [99dbfecdb39836ba26a0b2b0dcfde90f705a6835](https://github.com/OpenMinis/iCTRL/commit/99dbfecdb39836ba26a0b2b0dcfde90f705a6835)，最新稳定 Release [v1.97.1](https://github.com/OpenMinis/iCTRL/releases/tag/v1.97.1)，2026-10-13 发布；许可证 [Apache-2.0](https://github.com/OpenMinis/iCTRL/blob/main/LICENSE)，仓库未归档。

v1.97.1 修复 host app 的配对文件选择器不能选取 XML plist 的问题；Release notes 明确 Runner 无功能变化。本次与 SP-192 使用相同 SHA，尚无新增机制差异。

## 参考价值与边界

iCTRL 以长期运行的 XCUITest Runner 提供 agent 可发现的 HTTP JSON-RPC 自动化。重点持续比较：

| 上游方向 | TritonKit 关注点 |
| --- | --- |
| live ref、可见性、歧义提示 | SP-192 alias 新鲜度与实时身份校验 |
| 有界 UI snapshot | 跨平台节点、深度、子节点和 deadline 预算 |
| Vision OCR 与动作反馈 | candidateOnly、坐标来源、视觉稳定和业务验证边界 |
| 独立诊断、占用请求、熔断 | unknown 不重放、诊断不等待 UI |
| 自描述 skill/schema、错误 hint | CLI/HTTP 机器可读契约与下一步提示 |
| Runner/DDI、签名与配对安全 | 独立接管路线的兼容条件和安全变化 |

上游性能数字属于其自述，不代表 TritonKit 本地测量。参考登记不引入第三方运行时依赖；不复制私有 XCTest API 到 embedded SDK，不扩展默认远端控制面，不自动采用 Runner/DDI 或签名能力。

## 追踪流程

自动化 `ictrl` 绑定当前聊天，每天北京时间 10:00 查询 GitHub 默认分支、Release 和许可证，与最后成功检查点比较。增量摘要保存到 SP-193 `plans/`，包含旧/新 SHA 和 tag、原始链接、事实、与 SP-192 的关系及可借鉴价值；重大结论同步本档案和每日 memory。摘要成功保存后才更新检查点；读取失败不推进状态。无变化保持安静，有值得借鉴的更新、安全/兼容性变化或首次/变化故障及恢复时通知，重复变化和不变故障去重。后续实现独立立项，提交与远端写入沿用 AGENTS 授权规则。
