# SP-278 · 2026-11-09 验收报告

## 结论与阶段

本报告记录13:02追加提交/合并/推送授权之前的首版验收；后续整合与CI结果不改写这些原始测试事实，另见space当前状态。

实现完成，当前 DSH profile 已安装并生效；源代码与文档留在独立 worktree，尚未提交、合并或发布。主目录既有WIP不变。完整文档门禁受现有占号登记缺口影响，不能宣称全仓门禁全绿。

- 候选基线：`main@d94213c4e4cf8e23cdaa3b79c9edbd182ca4c4ae`；分支 `feat/SP-278-dsh-plugin`。
- 最终包：`@neptunekit/dsh-tritonkit-host@0.1.0`，`DSH/host.js` 入口。
- DSH 实例：当前 Desktop URL `http://127.0.0.1:61887`，内置 `0.2.2-rc.1`；另一个shell的 `dsh 0.2.1-rc.2` 不作本次兼容证据。
- CLI：已安装 `triton 0.2.42`。未修改/重建Swift核心，不将安装二进制当作本工作树源码构建。

## Requested / Observed

请求：将本项目制作为 DSH 插件。

交付：Host-only Cordis bundle，包含四个工具、严格配置/argv校验、Full access权限检查、跨session串行、有界输出/超时与进程范围清理、中英metadata及原创图标。不引入另一套Web控制面，不提供任意shell/argv，不自动启服务或执行设备动作。

## 测试与反证

- 首次测试在无实现时报 `ERR_MODULE_NOT_FOUND`，exit1；之后补实现。
- 准备期间降权负例、动态目标及UInt参数负例先失败，再补生产边界与回归通过。
- 独立只读CLI审计及插件审查共两轮；第二轮发现3项P1、3项P2，均由主控修复并补测：spawn前重查权限/缺失session拒绝；range quiescence；动态默认目标；队列deadline/及时取消；oid parser；异常时payload保留。
- 最终 Node 内置测试 **29/29通过**，无跳过；证据：[Node测试日志](20261109-node-tests.log)。`node --check` 两个runtime文件通过；`check-agent-experience.py`通过、`test-agent-experience.py` **28/28通过**；`git diff --check`通过。
- 初次保存测试日志时plans目录尚未存在，tee失败导致整条命令exit1；未把它当完整链通过。创建报告目录后重新运行全部29测试、语法/经验/diff检查并成功保存，以上结论绑定后一次完整命令。
- 自动测试使用fake Service，不能替代真实设备mutation、宿主异常进程或每个provider验收。

## 真实安装与工具调用

1. 初次开发包安装后暴露严格后端非适用字段占位问题。未放宽参数校验，增加已知可选字段null契约；通过plugin_manager移除旧开发包后，以最终Host包及新模块入口安装。旧包不再留在profile。
2. 最终安装：`application=applied`、`changed=true`、warnings为空；不含build scripts或版本豁免。pnpm输出通用peer提示，管理结果没有本包激活警告；未借机升级依赖或工具链。
3. Config Inspect解析到最终packageDir和entry `include:tritonkit`。`status: absent`是没有Config schema，不是未启用。
4. 已安装工具 `triton_query(version, optional=null)`：success=true、version=0.2.42、exitCode=0、cleanup=confirmed。
5. 已安装工具 `triton_schema(command=version)`：success=true、schemaVersion=1、exit0、cleanup=confirmed；正确接受原生schema没有ok字段。
6. 已安装工具 `triton_query(status, optional=null)`：success=true、serverReachable=true、exit0、cleanup=confirmed；未新启服务，仅读取已有服务。
7. 已安装工具 `triton_schema(command=not-a-real-command-sp278)`：success=false、payload.error.code=unknown_command_schema、exit1、cleanup=confirmed；保留原生单envelope与恢复建议，不执行建议。

## 展示与打包

- 中英locale和包内原创三叉戟SVG已静态校验；包声明exports/files完整，零外部运行依赖。
- 实际GUI地址在独立验收浏览器中返回 `dsh web authentication required`。未读取用户token/cookie或改认证，因此实际插件面板的中英展示/图标渲染未验，不能由静态资源检查推导视觉成功。自有浏览器页已关闭。
- 本地最终tarball（不随Git源码提交）`DSH/dist/neptunekit-dsh-tritonkit-host-0.1.0.tgz`：11877字节，SHA-256 `235a83a36f53c294a857a7f30a0c06739d849b5464a6d308485c0c76bec6b152`。归档恰含8个预期文件，不含测试、dist、内部skills或设备数据；SVG XML解析通过。完整runtime/资源hash见[包验收清单](20261109-package-verification.json)。
- 安装验收使用本地link来源；tarball文件面/hash已检验，但没有另建profile重复安装tarball。本地link来源仍需保留。
- 新增四工具契约的序列化大小有16KiB上限测试，不额外注入system prompt；未实际测量模型首轮prompt token增量，不能将字节预算当token基准。

## 文档门禁与未执行项

- 本候选的基线只登记SP-001～255，而已有其他注册worktree占号至277；本轮使用278，不复用编号、不复制其他WIP或修改连续编号门禁。
- `verify.sh --ci-docs`：CI scope classifier通过，随后docs structure以exit1停止；`check-docs.sh`单独执行同样exit1，诊断均为 `space registry IDs must be contiguous from SP-001: SP-278-dsh-plugin`。证据：[ci-docs日志](20261109-ci-docs.log)、[结构日志](20261109-docs-structure.log)。该候选已满足本space唯一链接与登记要求；未通过的是255到278之间的历史并行占号整合，不降低校验。其后独立经验检查和diff检查已通过。
- 未运行全量Swift/CLI测试、release build、完整 `--local`、iOS/Android/Harmony真实动作矩阵、CLI update/install/Runner生命周期：本轮无Swift/CLI实现改动，且不授权触碰当前App，仅验证新Node插件与已安装CLI只读接线。
- 未发布npm或GitHub资产，未commit/merge/push/tag/release，未改变已有服务/设备状态。

## 经验与下一步

经验已经写入 [集成契约](../../../dev/dsh-plugin-integration.md)、[经验索引](../../../memory/EXPERIENCE.md)和[当日记录](../../../memory/2026-11-09.md)。后续若用户需要，按明确目标另做真实设备动作验收；集成到main时先协调256～277登记与原目录WIP，不整分支回灌。
