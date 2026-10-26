# SP-224 — 宿主输出收尾主控验收

范围仅SP-223宿主进程I/O收尾；不扩大旧SP-222。影响CLI内部runner与错误/证据完整性。

## BDD与验收

复核SP-223正式旧代码红测试、实际候选diff/源码hash、三runner的继承FD、尾字节、截断与非零语义；不能只凭原函数probe替代生产测试。主控独立focused/完整CLI，必要root/local门禁，docs-only/check-docs/diff；真实设备/远端运行未执行单独保留。通过后才交root在干净main预检合并，再跑合后门禁、回写采用登记并归档清理。

## 文件面

只写本SP-224目录审查/验收资料，不改SP-223实现或共享索引/state/memory；需要修复发回执行。共享scratch串行。不得stash、远端写、设备/依赖/签名/DDI。新会话和后续派发必须显式model=gpt-6.1-sol，无回退。

## 当前阶段

待执行冻结候选和真实主控会话创建，不能标已验收。

真实thread `01a1773d-8556-7a01-a885-a0f5d0c68a6d`，显式gpt-6.1-sol；同级worktree/feat分支已建，已分派，尚未验收/合并。
