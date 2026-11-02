# SP-254-simulator-dtuhid-transport — Simulator DTUHID transport

状态：候选实现与离线CLI验证完成，待SP-255主控复核/集成；文档门禁受分支公共索引缺登记阻断。影响CLI host隔离helper；不修改embedded/Web/真机。

来源：[Loupe固定增量](https://github.com/heoblitz/Loupe/commit/180c60584867500b93b43ca6c8b556995bf8be7b)，MIT全文已核；idb协议来源已固定SHA并核MIT全文，完整通知随CLI native-hid资源携带。基线main44e81f5d仅legacy client。

## BDD与验收

- 服务可用且无事件barrier应答后才同连接发送typed down/move/up，完成barrier有界；consumed不是业务成功。
- 只有明确unsupported可走legacy；连接/未知lookup/超时/发送失败不fallback、不重放输入；错误单JSON。
- 坐标、目标、display、Resize拒绝沿用原策略；partial/cancel副作用保持unknown，不扩大secondary/真机。
- 离线失败测试→最小实现→focused/完整CLI→主控diff复核及合后门禁；真实设备未授权、未执行，不能据fixture声称实际兼容。

执行：SP-254-simulator-dtuhid-transport；主控：SP-255-dtuhid-integration，复用当前长期聊天。证据归plans；主控负责本地合并、证据归档、清理及执行聊天关闭，不push/tag/release。

## 当前候选与交接

- [实施契约、许可与验收边界](plans/20261102-transport-contract.md)。实现为 modern-first DTUHID + strict unsupported-only legacy；modern 不预先要求 IOHID/Indigo legacy 符号。保留 helper 的目标/booted、geometry、Resize、ownership 与发送后检查。
- Device Hub `dtuhidd.active=1`/unknown 仍拒绝，不能把新增 transport 称为 claimed Device Hub 输入接管。现代 `target=0` 不是显示绑定证明。
- 无事件 barrier 初始化/结束各至多4秒；真实XPC匿名本机peer覆盖有序收发、pending取消和超时后迟到回包。发送失败 session 永久poison，只留一次同连接 terminal-up 清理，不重试down/move/finish、不fallback。
- 公共 `TKInputResult` 不扩字段；source/strategy/required verification 保留，message中的backend仅是诊断文本，不是独立机器字段。doctor只检查框架/endpoint前提，available/inputDispatchVerified仍为false，不发送设备barrier或输入。
- focused `42 tests / 7 suites` 通过（含自有匿名XPC peer，非设备）。完整CLI状态与冻结SHA见下方验证交接记录；只在本地commit，不合main、不push。
- 原始 red/green/full 和来源hash保存在 sibling `archives/SP-254-simulator-dtuhid-transport`；无依赖安装/下载、上游代码执行、设备或xcodebuild操作。复制现有本机依赖缓存不产生锁文件/依赖变更。
- 公共索引、memory与skill沉淀、SP-207登记、SP-255主控验收/合并/清理由主控负责，本worktree不写这些共享文件。

## 验证交接记录（2026-11-02）

| 检查 | 结果 | 证据 / 边界 |
| --- | --- | --- |
| 首轮RED | 预期失败，exit 1 | `red.log`：新transport/wire类型不存在；`red-4.log`：发送失败后仍可move/new-down的3条断言失败 |
| helper / peer RED | 预期失败，exit 1 | `red-helper.log`、`red-peer.log`：缺注入执行函数/连接初始化面 |
| focused | 通过，exit 0 | `focused-2.log`：42 tests / 7 suites，含3项匿名本机XPC callback测试 |
| 完整CLI | 通过，exit 0 | `full.log`：1677 tests / 178 suites；`swift test --package-path CLI --no-parallel --disable-automatic-resolution --skip-update` |
| 单JSON参数拒绝 | 通过，命令预期exit 1 | `invalid-target.stdout.json`、`invalid-request.stdout.json`：validation_failed，Python完整JSON解码成功；无目标I/O |
| docs / ci-docs | 失败，exit 1 | `docs.log`、`ci-docs.log`：`space index must contain exactly one link for SP-254-simulator-dtuhid-transport`；公共登记由主控独占，执行分支基线未纳入，未越权修改 |
| diff whitespace | 通过，exit 0 | 冻结前检查tracked及staged完整候选 |
| 根包 / --local / 发布 / 真机与Simulator实测 | 未执行 | 本切片只要求CLI focused/full，主控负责整合门禁；不安装依赖、不调用xcodebuild/设备，不以匿名XPC或fixture替代真实兼容 |

候选基线 `44e81f5d333ba842051579639d3834981e7b2340`；最终本地提交SHA、完整patch与size/hash清单由 sibling evidence 的 `candidate.json` / `candidate.patch` / `evidence-manifest.json` 绑定，防止文档自指SHA。源码文件实际在根 `Sources/TritonKitCLI/`（`CLI/Sources/TritonKitCLI`为既有symlink）。未改变依赖、锁文件或生成物。

经验检查完成：本轮poison缺陷及已验证修复沉淀至本space契约/测试。只读独立审查无当前单手势helper阻断问题，session正常up后应立即finish，不作多手势复用；公共长期资料由主控按最终整合结论写回。
