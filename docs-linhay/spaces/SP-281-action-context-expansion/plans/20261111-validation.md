# SP-281 P0/P1 — main 验收记录（2026-11-11）

## 结论与候选

本轮按用户授权直接在 `main` 串行开发，未创建 branch/worktree。基线 `607410fb3d44bfe02274c13822170c3015c63a99`；开工工作区干净。当前交付为 **P0/P1 生产 shared receipt 与动作 evidence**，不是 P2–P6 全量路线完成。未提交、推送或发布。

独立只读复审确认前述问题已修复，未发现本 P0/P1 范围新增阻断；复审不替代运行验证。

## 实现与兼容

- 两类动作保持旧 JSON 字段，并增加同类型 `actionReceipt: TKActionReceipt`。
- device.action 的生产成功路径调用共享 coordinator.receipt；提交后异常和 stale generation 使用绑定原 action 的独立 uncertain receipt，不去 invalidate 新 generation。
- Apple runner 使用同一 shared receipt 导出，旧的 auditPath/sourceCommand 只留兼容 stdout/私有 audit，不再整体复制到标准 artifact。
- host returned nonzero 与 thrown nonzero 均非成功；timeout 不丢 action/admission identity，不重放。
- double-tap 第二次失败不擦除第一次可能已送达的事实；首个 launch failure 才是 not_started/false。
- iOS nested error、ok+error 矛盾、blocked/not_started/unknown 等状态不提升执行成功；任意非结构化状态文本不进入 shared receipt。
- iOS submitted-only/pending 延续“已接受”的退出语义，executed 仍 unknown，不宣称业务完成。
- HTTP lease conflict 原 error code/currentOwner/leaseReason 保持；无 provider 调用。有证据模式记录 blocked/not_started，未伪造 admission。
- evidence-dir 为 opt-in，使用现有 CLI/HTTP JSON 模型，不新增 remote admission 或 Web/Wails 控制面。

## 证据落盘合同

执行前以 mkdirat 排他 claim 新 0700 根；父/root symlink、已有目录和不安全路径拒绝。文件用目录 FD + O_NOFOLLOW/O_EXCL 写入 0600 产物；路径被替换则拒绝完成。

目录包含：

```text
<fresh-root>/
  run/meta.json
  run/events.jsonl
  run/action-receipt.json
  manifest.json
```

receipt 为白名单 DTO，标准 artifact 不包含输入、原始 stdout/stderr/provider message、私有 sourceCommand 或 auditPath。meta/events 回读、exact bytes 比对和标准 parser 验证后，manifest 记录三类 artifact 的 bytes/SHA-256。

manifest staging 文件完整写入/fsync 后才通过排他 link 发布，最后作为完成标记。已有 manifest 碰撞不得覆盖。root fsync 失败时只撤回本次发布的同 inode marker。没有有效 manifest 的目录属于失败诊断，盘内 written 意图字段和 completed 事件不能单独证明持久化成功。

- manifest.ok：证据包是否完整；动作失败也可以完整记录。
- run verdict + receipt：动作是否完成、送达是否已知、后置是否验证。
- requested evidence failed：provider事实保留，stdout evidencePersistence=failed，CLI非零，不因证据失败重发动作。
- runner 原 audit 失败即使外部导出成功，failureCode/terminalStatus仍保留 runner_audit_failed，run verdict不能变success；已验证输入的delivery/postcondition也不能被抹除。

## Red → Green 证据

首次新增4项测试全部失败，共5个issue，真实抓住：

1. returned exit 7 被当 ok:true；
2. timeout 抛出后没有 bound receipt；
3. evidence-dir 参数未接入；
4. 缺少已有证据根拒绝入口。

随后新增测试覆盖：partial double-tap、首个launch failure、nested/contradictory iOS、receipt与manifest碰撞、父链接拒绝、HTTP租约原始异常、JSON单envelope/ExitCode、audit failure和不可信status文本。没有通过弱化断言或删除旧测试换绿色。

## 当前冻结实现验证

| 检查 | 真实结果 |
| --- | --- |
| 完整 CLI：`swift test --package-path CLI --no-parallel` | XCTest 166 项通过；Swift Testing 1853 项 / 203 suites 通过，exit 0 |
| `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` | exit 0；依赖边界、iOS DEBUG隔离、root、release构建、smoke、docs、diff通过 |
| root（上述local内） | runtime 130 项 / 26 suites；shared 313 项 / 45 suites，均通过 |
| Release CLI build + CLI/Harmony/iOS observe smoke | 通过；host/observe smoke是本地只读/fixture合同，不代替真实设备动作 |
| `docs-linhay/scripts/verify.sh --ci-docs` | exit 0；经验路由、文档、版本/skills/发布契约通过 |
| Simulator build | 显式 `TRITON_VERIFY_XCODE=0` 跳过，未计为通过 |
| 新增场景 | 14项 receipt/evidence用例进入完整CLI；原runner16项及DeviceActions8项仍通过 |
| 真实设备、remote、approval UI、签名/DDI、发布/安装 | 未执行，不用fixture替代 |

日志保存在本机 ignored `.triton/sp281/20261111-p0p1/`，`custody.json` 记录日志size/hash与14个本轮实现/测试文件hash。原始日志含本地测试路径，不进入公开归档。最终源文件hash复核必须与冻结候选一致。

## 共享 main 的其它 WIP

执行期间另一任务创建 SP-283（Homebrew公开资产门禁）和 SP-284（只读Simulator依赖诊断），并修改其独立文件面。本轮不触碰这些实现、测试或workflow，不提交它们。全仓docs一度因缺少新space入口而失败；依据其已存在README仅补真实“执行中”登记和计数，没有复制其它任务验收声明。补齐路线总览入口后local/docs整链恢复通过。

## 范围与风险

- 默认store是单调用或显式共享store的进程内范围，不是跨CLI进程授权、全局幂等、排他目标锁或Stop barrier。
- opt-in lease HTTP check→provider不是原子提交，不能声称消除TOCTOU。
- observationID/geometry只绑定输入事实；未自动重读设备树，不宣称UI当前新鲜。
- raw日志/原provider envelope不导入标准包；兼容stdout仍保留原provider错误，公开反馈前另行脱敏。
- hash是内容自洽，不是签名/不可抵赖；manifest原子发布不宣称应对同用户恶意进程的OS隔离。
- P2其它action、P3approval、P4remote、P5resume、P6真实设备保持后续独立范围。

## 沉淀

权威合同已更新至 `docs-linhay/dev/ai-cli-readable-control.md`、README、三个public skills参考入口及EXPERIENCE索引。重点检查点是 returned/throw 一致处理、nested错误不得假成功、证据原子完成标记与capture/action verdict分离；本轮不新增重复skill。
