# SP-237 · #222 Device Hub 后续审计

当前状态：已随PR #233合入远端main（`40850dde`），issue #222已completed关闭；现场复验范围见[远端处置](https://github.com/NeptuneKit/TritonKit/issues/222#issuecomment-6460615766)。 本批次未发布；[合并归档报告](../SP-241-open-issues-validation/plans/20261028-merge-closeout.md)为当前事实源。
## 状态和边界

2026-10-28 对 main `a0d187ac`、issue 本文及四条追加评论只读审计；不改产品、不运行设备、不声称新验收。原 chrome 依赖、HID authority 与 Xcode27.1 displays 兼容性已经由 SP-218/v0.2.33 覆盖。系统告警特定路径、多击/长按与跨工具链没有该发布的真实验证，不能一并声称完成。

## BDD / 结论

- Given 旧报告 no chrome bundle，Then 当前 tap/swipe 内置隔离 digitizer 不查 chrome/Baguette；guest Hub attached/unknown 仍明确拒绝。
- Given 显式 platform ios coordinate tap，Then 默认 AX，要求物理触控时 `--hid-only`；拒绝语义/embedded/WebView 混用，receipt 保留来源和 required verification。
- Given 后续 topology queryFailed，Then v0.2.33 已使用真实 `devicectl device info displays` 和完整 argv 绑定；不是允许未知 geometry。
- Given system alert 或多击/长按，Then 不用 embedded app tree 作为系统画面证据，也不宣称已有验证的 host 多击/长按入口；需要独立操作后置证据。

详见 [审计与回复草稿](plans/20261028-audit.md)。不自动回复或关闭远端；#224 剩余目标诊断修复在 SP-235。
