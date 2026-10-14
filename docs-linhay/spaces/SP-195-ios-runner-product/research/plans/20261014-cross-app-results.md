# 2026-10-14：多 App 真机实验结果

沿用用户选定的有线 iPhone 13 Pro Max（iOS 26.6.2），Xcode 27.1。fixture、系统计算器、设置、Safari 均由独立 Runner 控制，系统 App 未嵌入 SDK。实验留在 SP-193 独立 worktree，未进入产品 CLI/HTTP 或根 SwiftPM。

## 场景结果

| App / 场景 | 结果 | 实际证据 |
| --- | --- | --- |
| fixture 初始动作 | 通过 | 同一会话计数 0→1，固定 identifier 查询后置状态 |
| Calculator 跨 App 激活 | 通过 | Calculator state=4，fixture state=3；Runner 自报 UIKit state=2 |
| Calculator 计算与去重 | 通过 | fresh inspect 后逐项点击 AllClear、Seven、Add、Eight、Equals；AX 算式 7+8、结果 15，PNG 目视确认；重复同请求 ID 的 Equals 后仍为 15 |
| Settings 滚动与导航 | 通过 | General 初次不可点击，返回 cross_app_not_hittable；scroll 后重新 inspect、tap；新页面有 BackButton |
| Settings 返回 | 通过 | 第三轮 fresh inspect 后使用 BackButton 返回，新 AX 再次含首页 General 按钮 |
| Safari 激活与界面读取 | 通过 | state=4，读取实际地址栏 TabBarItemTitle / URL；限额 AX 返回成功 |
| Safari 固定网站导航 / 输入 | 未通过 | 第三轮地址栏 tap 后返回 cross_app_focus，未清空、未 typeText、未提交 example.com；页面加载、网页滚动均未验收 |
| 多次切回 fixture | 通过（AX 状态） | 第三轮 Safari、Settings 后切回 fixture，counterLabel=1；再切 Calculator、返回 fixture，counterLabel 仍为 1 |
| 正常结束与拒绝后存活 | 通过 | Safari 焦点拒绝后 health、Settings 返回和 fixture 查询仍工作；stop ack，testServe 179.109s、零失败、xcodebuild exit=0 |
| 最后一次标记 fixture 的截图 | 捕获成功，App 画面归属未通过 | endpoint 返回 PNG、state=4，但目视是 App Switcher 中的 Calculator；不能把请求 app 元数据当成 PNG 画面归属证明 |

Calculator 真实业务结果在第二轮通过；第三轮只验证再次激活与查询，未重做计算。因此最后一个 testServe PASS 不代表所有场景全部通过。

## 失败与修复记录

1. 首版 inspect 使用 query.count 与 element(boundBy:index)，页面变化后 Settings / Safari 索引失效，XCTest 记 failure。Simulator 和真机均复现。修复为每 type 固定 accessibility-bound 元素集合、exists 检查；这些 public 查询仍不是原子 AX 快照。
2. Calculator 数字键是 XCUIElementTypeKey，而非 Button；补入 Key 后读取 20 个按键，计算得以验证。
3. Settings / Safari 的完整查询超过 host 18s / 连接 20s，HTTP 返回 unknown，稍后原 receipt 中 ok=true。仅查询原 receipt，没有自动重发未知结果动作。inspect 达到预算即停止后续 type 遍历，并报告 truncated / totalUnknown；预算仅约束返回条目，不保证 XCTest 内部扫描成本。
4. Safari 地址栏在 tap 后改变元素形态，原 locator 失效导致第二轮 XCTest failure。修复为 focus 后重新定位可编辑字段、清空后再次核对。第三轮未再发生该 XCTest failure，但公开焦点验证返回 cross_app_focus，故导航依然未通过。

cross_app_focus 当前不能区分多焦点、候选数不唯一、键盘 AX 未出现等 guard 分支。后续最小诊断应记录无 UI 值的候选计数、focusedCount、keyboardExists 和采样时间；本轮不推断具体原因，也不放宽验证强行输入。拒绝前已经 tap 地址栏，不能宣称完全没有 UI 副作用。

## 会话与退出

| 会话 | testServe | 实际 host exit | 说明 |
| --- | --- | --- | --- |
| Simulator cross-01 | 失败，110.868s | 65 | Settings 索引失效；不记 Calculator / Safari 验收通过 |
| 真机 cross-01 | 失败，235.110s | -15 | Safari 索引失效；方法失败后 host 等诊断，仅终止本期核实的进程组 |
| 真机 cross-02 | 失败，233.437s | -15 | 计算器和设置场景已有后置证据，随后 Safari 旧 locator 失效；仅终止本期 host |
| 真机 cross-03 | 通过，179.109s，零失败 | 0 | Safari 输入明确拒绝；之后 Settings 返回、fixture 状态和正常 stop 通过 |

Simulator 初测失败后未重跑完整修复版；本轮新增成功场景来自上述真机，不能外推 Simulator 多 App 全覆盖。

## 验证、隐私与回收

- 独立离线测试 52 条：Swift protocol 9、Host client/USB 38、Experiments 5，全部通过。真机三次签名 build-for-testing 均 exit=0；Simulator 初版 build exit=0。离线测试不替代真实 UI 后置状态。
- PNG 是 XCUIScreen.main 的全屏截图；目标前台状态、AX 和画面归属可能存在时序差异，需要视觉核对。本轮系统画面含私人 UI 或个性化画面，只保留 ignored 私有原件，没有新增公开图片。最后截图归属不匹配也明确保留。
- 原始日志、AX、网址、token、设备身份、签名信息及截图只留在权限受控 ignored .build；公开结果仅含固定测试算式与已审核的元信息。
- 本期测试进程已退出、USB forwarder 已停止、专用 Simulator 已通过 triton sim shutdown 关闭。研究 App 留在手机，设置项未修改；计算器保留本轮测试结果。
- 产品集成、任意第三方 App、锁屏、断 USB、重启、30 分钟资源曲线、无宿主冷启动仍未验收。本轮 verify.sh --local、--ci-docs、独立 check-docs.sh 与 diff 检查通过（根包 264 tests / 34 suites），确切私有值扫描无泄露；详细结果见 [机器可读摘要](./20261014-cross-app-summary.json)。

## 对 TritonKit 的借鉴

独立 Runner provider 的跨进程控制可行，正式入口仍应由 host CLI/HTTP 管理会话。通用控件类型不能只覆盖 Button；页面变化后必须重新定位；unknown 要先查 receipt 和业务后置状态；截图需要独立验证画面归属。常驻、输入焦点与复杂网页仍需独立验收，不能从计算器成功推广到所有 App。
