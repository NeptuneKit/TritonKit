# SP-273 issue #274 显式启用推理

状态：实现与独立审阅通过，完整CLI回归通过，CLI/HTTP隔离验收通过；尚未提交/合并/发布。关联 [issue #274](https://github.com/NeptuneKit/TritonKit/issues/274)。

## 边界

影响 CLI workspace run、共享模型策略与 HTTP workspace run 契约；默认由外层 agent 推理。仅保存 LLM/VLM 配置不构成启用，直接专用推理命令的显式 provider 请求须单独说明。修复进入尚未打 tag 的 SP272 v0.2.40 候选，完成独立审阅、合并及必要回归后统一发布。

不认定用户报告的 llama-server 进程归属；不启动真实模型、下载权重或请求真实在线服务。低内存卡顿及原用户进程现场保留未验证；不会把隔离 transport/helper fixture 当成真实模型质量或资源验收。SP270 Lookin 另以独立集成分支审阅、验证和提交，不混入本 issue 差异；通过后统一进入0.2.40。

## BDD

- Given 默认设置或仅保存 provider 配置，When 常规 CLI/HTTP workspace 工作流，Then 不调用在线 API、不拉起本地 helper/下载/预热，基础结构化控制仍可用。
- Given 显式启用且有效 provider 配置，When 发起推理工作流，Then 使用指定 provider 并记录启用事实。
- Given 在线 provider 鉴权/超时/缺配置失败，When 显式推理，Then 有界机器可读失败且不启动本地 fallback。
- Given 显式本地 helper 请求，When helper 超时/失败，Then 有界失败；只通过受控无模型 fixture 验证调用边界。

## 验证

先补旧契约失败测试，再最小实现；覆盖 CLI argv、HTTP DTO、model loop、报告 enabled 字段、现有显式 provider 回归。主控完成完整 CLI、文档及正式安装版隔离进程验收。

独立审计追加实际有界性缺口：MLX helper 旧实现先等退出再读管道，可能堵塞或等待继承 pipe 的后代；在线 POST 仅空闲超时而无整体 deadline。复用既有有界 host runner 与共享 HTTP deadline，通过自结束/忽略 TERM/大输出 stub 和受控慢滴流验证；不加载真实模型，不扩大到杀未知后代。helper timeout 加既定 TERM/KILL 与 drain 收尾预算单独报告。

## 工作区

- branch: `feat/SP-273-issue-274-explicit-inference`
- worktree: `../TritonKit-worktrees/SP-273-issue-274-explicit-inference/`
- 基线：`9578782a7cbfd855228f8e996b07d93437725870`
- 既有 [SP-069](../20260621-local-mlx-vlm-provider/README.md) 与 [SP-272-release-v0-2-40](../SP-272-release-v0-2-40/README.md)。

## 已建立的旧版本反证

安装版0.2.39真实CLI在未显式enable时返回llmEnabled/vlmEnabled=true；仅配置在线provider即向受控loopback接口POST一次。marker未命中，仅证明受控helper未调用，不证明宿主所有进程。证据`archives/SP273/process-fixture/baseline-039/report.json`，持久脚本[隔离验收](plans/inference-fixture.py)。源码候选CLI/HTTP各8项已通过，正式安装版待发布后复验。

## 当前回归与审阅

完整CLI：162 XCTest + 1770 Swift Testing / 188 suites通过，3项既有真实环境条件skip；这不替代设备真验。Workspace聚焦86项/11 suites，deadline/VLM聚焦28项/7 suites有重叠，不相加为总量。文档、public skill commands/package与diff检查通过。

独立[产品审阅](plans/20261103-independent-review.md)未发现已证实P1/P2；[有界执行报告](plans/20261103-inference-deadline.md)保留可靠RED、首次fixture不足与精确预算。生产30秒HTTP总deadline已由真实慢滴fixture验证；模型质量、低内存卡顿与原llama-server归属未验。[源码候选CLI/HTTP验收](plans/20261103-cli-http-acceptance.md)16/16通过，实际二进制版本0.1.0-dev；正式安装版待发布后复验。
