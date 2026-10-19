# 2026-10-19 参考资料有限集成

基线为真实main `d51403a6`；源主目录`codex/wip-main-before-sp209@0a0aec02`只读，保留main现有SP-209与v0.2.30发布历史。只按以下manifest提取参考追踪资料，共享索引、memory与ops规则按main增补，不回灌旧产品。

当前SP-210/SP-212为implementing，当前聊天主控负责SP-211/SP-213 integration_in_progress。历史模型接口失败是历史证据，不再代表当前执行阻塞；没有创建桌面thread，不伪造ID。

## 精确提取manifest

- `docs-linhay/dev/20261014-reference-project-updates.md`
- `docs-linhay/dev/ictrl-reference-tracking.md`
- `docs-linhay/dev/mobile-mcp-reference.md`
- `docs-linhay/dev/reference-project-adoption-workflow.md`
- `docs-linhay/memory/2026-10-17.md`
- `docs-linhay/memory/2026-10-18.md`
- `docs-linhay/memory/2026-10-19.md`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/README.md`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/plans/20261016-adoption-workflow.md`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/plans/20261017-check-summary.json`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/plans/20261018-check-summary.json`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/plans/20261019-check-summary.json`
- `docs-linhay/spaces/SP-193-ictrl-reference-tracking/plans/upstream-state.json`
- `docs-linhay/spaces/SP-194-reference-project-updates/README.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/README.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-agents-revyl.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-ai-phone-review.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-ai-phone-review.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-dispatch.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-observations.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-reference-update-report.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-research.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-revyl-review.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-revyl-review.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261017-sim-runtime.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-agents-revyl.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-dispatch.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-ictrl-check-summary.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-observations.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-reference-update-report.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-research.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261018-sim-runtime.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-agents-revyl.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-dispatch.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-observations.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-reference-update-report.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-research.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/20261019-sim-runtime.md`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/adoption-state.json`
- `docs-linhay/spaces/SP-207-reference-adoption-pipeline/plans/reference-state.json`
- `docs-linhay/spaces/SP-210-simulator-ax-geometry/README.md`
- `docs-linhay/spaces/SP-210-simulator-ax-geometry/plans/20261017-current-gap.json`
- `docs-linhay/spaces/SP-211-reference-adoption-integration/README.md`
- `docs-linhay/spaces/SP-211-reference-adoption-integration/plans/20261017-handoff.md`
- `docs-linhay/spaces/SP-212-mobile-mcp-android-contracts/README.md`
- `docs-linhay/spaces/SP-213-mobile-mcp-contracts-integration/README.md`

共享人工合并：INDEX、spaces README、MEMORY、EXPERIENCE、ops governance skill。产品验证和最终合并SHA由主控在候选冻结后补齐。

## 文档门禁

`check-docs.sh`通过：213 spaces、28治理测试；`verify.sh --ci-docs`通过（含13打包与9发布契约测试）；`git diff --check`通过。首次发现共享索引重复SP-207链接，已改为保留main原行并移除重复追加行后复跑通过。未运行构建或产品测试，联合候选由主控另验。
