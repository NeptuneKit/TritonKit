# SP273 独立 CLI / HTTP 进程验收

最终候选：`candidate-040-v3/report.json`，8 CLI + 8 HTTP 共 16/16 PASS。两类进程和两个自有动态端口均已退出/拒绝连接，见 cleanup-verified.json。

二进制为源码 debug candidate，实际 `--version` = `0.1.0-dev`；目录名 candidate-040 不代表已安装发布 0.2.40。原二进制已复制到 candidate-binary/triton 后独立运行，未再依赖可变的 SP271 scratch。

- Binary SHA256: `2085a605c68562f14c326aa99ad05fc88be639f09e3e75d41c6ba80ca5de5dba`
- Script SHA256: `4b81db90f549912e8f2e722afb46a6d896c0a395508f61851e07ee0f881ef63b`
- build-binding.json 绑定原路径、mtime、两个源码清单 21 项全部匹配及聚焦 GREEN 日志；构建由其他负责人完成，本子任务未构建。

| 入口 | 场景 | 请求数 | 秒 | 结果 |
|---|---|---:|---:|---|
| cli | defaults | 0 | 0.139 | PASS |
| cli | configured-disabled | 0 | 0.103 | PASS |
| cli | enabled-llm | 1 | 0.242 | PASS |
| cli | enabled-both | 1 | 0.186 | PASS |
| cli | enabled-vlm-mock | 0 | 0.145 | PASS |
| cli | unauthorized | 1 | 0.132 | PASS |
| cli | disconnect | 1 | 0.124 | PASS |
| cli | slow-drip | 1 | 30.183 | PASS |
| http | defaults | 0 | 0.095 | PASS |
| http | configured-disabled | 0 | 0.015 | PASS |
| http | enabled-llm | 1 | 0.160 | PASS |
| http | enabled-both | 1 | 0.034 | PASS |
| http | enabled-vlm-mock | 0 | 0.027 | PASS |
| http | unauthorized | 1 | 0.004 | PASS |
| http | disconnect | 1 | 0.004 | PASS |
| http | slow-drip | 1 | 30.045 | PASS |

默认与仅配置两组 ai.llmEnabled/ai.vlmEnabled 均 false，零 HTTP。显式 LLM 单次访问指定 loopback `/v1/chat/completions`、模型 fixture；显式 VLM 只用 mock。401、断连、慢滴均 stable workspace_failed + 明确 LLM 原因 + 非空 hint，CLI exit1 / HTTP409，无备用模型调用。

## 首轮失败与修正

candidate-040 完整原始 16 案例和失败未改写。误将现有 workspace_failed 契约要求为新的 provider-specific code，并把 serve 启动时被 stub 阻断的 adb/hdc 只读 discovery 混入模型 helper 断言。核对源码/schema 后仅修 fixture：严格验证稳定 code、HTTP401/-1005/-1001 原因、hint 和退出/HTTP状态；marker 记录来源/argv，仅允许 serve `adb devices -l` 与 `hdc list targets -v`/plain 被阻断调用。修正记录 fixture-correction.json。v2 16/16 通过；v3 再以独立 copy 16/16 通过。未修改产品、未放宽 45 秒 watchdog 或 20 秒最低慢滴负载要求。

## 基线与证据边界

baseline-039 是真实安装 0.2.39 CLI 的 2/2 预期缺陷复现：未 enable 仍两 flag=true，完整配置产生一次请求。其报告保持原样。

v3 marker 仅包含 serve 的 adb devices -l / hdc list targets -v，fake 工具 exit97 阻断；没有 llama-server / ollama / triton-mlx-provider。该 marker 只证明指定 PATH/helper 入口，不证明宿主所有进程。整个流程 dry、不 observe-live、不 execute-actions、无设备动作、无模型下载、无真实模型/外部 API。无主服务 19421、Git 或构建操作。SDK/私有 App、低内存现场和任意未知子孙进程不在本验收范围。

已停止，移交主控整合与发布后按同脚本复验。
