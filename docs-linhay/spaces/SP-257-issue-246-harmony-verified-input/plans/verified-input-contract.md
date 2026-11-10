# Native Harmony verified input contract

## 影响层与调用

仅 CLI host Harmony opt-in 路径：

```sh
triton act type --platform harmony --device <owned-target> --verify --selector id:editor --text 'value' --expect-value 'value' --timeout 10 --json
```

`--expect-value` 是最终完整文本，可为空；输入与预期值不输出。`--verify` 不能与 WebView、oid、exact、secure 或其它平台混用；expect-value/timeout 不能单独开启。默认旧输入路径保持 transport receipt，WebView selector 含义不变。

## 行为边界

1. `id:` 唯一性从完整有界原始 dump 计算，10 MiB、10,000 traversal items、64 depth 超限拒绝，不能用截断样本声称唯一。text 保留空串和空白，boolean 仅严格 bool/true/false。
2. 仅 visible/enabled TextArea 或明确 password=false 的 TextInput。TextArea 原生组件无密码模式，可在未提供 password marker 时进入；任一 secure/password marker为真或未知、password inputType、全掩码值都拒绝。未知text/focus/bounds在发送前拒绝。
3. 未聚焦时重新读取同一身份和中心几何，最多 tap 一次；只读轮询实际 focused=true 后才提交。身份含 stable id、type 与供应方提供的 accessibilityId/hashcode。树与动作间存在宿主 UI 非原子变化窗口，不能声称平台原子锁定。
4. text仅提交一次，使用单引号远端shell字面量并escape单引号，NUL拒绝；没有自动清空、重复输入或切换backend。进入send后异常一律unknown。
5. 发送后同identity有界读取原始text，必须精确相等；`submitted` 与 `match` 分离。match仅证明读取时的后置条件，尤其expected已等于初始值时不能证明由此次输入导致。
6. 同一总deadline覆盖目标枚举、读取、聚焦、发送、校验；每个底层命令（hdc枚举、dump、recv、click、text）启动前检查剩余预算，进程执行超时上限为剩余预算；宿主进程runner自身结束/pipe drain有既有收尾边界。文件读取/JSON解析不可抢占，前后检查deadline，迟到结果不通过且不再发送动作；这不是实时硬终止保证。临时本地layout在读后删除，JSON/text输出不包含原始进程错误、输入、expected或selector。

## 输出

单一 `HarmonyVerifiedInputResult`：`ok`、`submission=not-sent|submitted|unknown`、`focus=unknown|not-focused|confirmed`、`verification=match|mismatch|timeout|unavailable`、typed `code`、`durations`（已进入phase秒数）、`polls`、`redacted=true`、后置条件边界note。失败退出非零，不包装第二份JSON。CLI schema `host.harmony-verified-text-input` 对齐。

## 验证与未知

候选已准备注入测试与自有 ArkUI fixture；Swift构建由主控分配串行时段，真实HVD由主控独占操作。未执行的测试与现场不视为通过。真实input支持的字符范围、实际password字段与节点身份稳定性必须通过fixture验证后回写；shell quoting单测不能替代设备文本能力验收。

## 经验

共享Harmony summary会trim text且不暴露password，因此不能拿展示DTO作精确值证据；本CLI使用raw decoder且不改共享SDK。纯命令成功不证明输入字段变化，未知发送不得用重试消除不确定性。来源命中 `docs-linhay/memory/EXPERIENCE.md` 的legacy文本输入与ArkWeb未知送达边界；共享经验入口由主控整合时回写。

主控已保存实际安装版 v0.2.38 前态命令：新增完整 verified argv 返回 exit 64 / unknown flag。此为真实前态契约 RED，不能代替后续 runtime 的业务负例或设备验收；证据在主控最新巡查目录 `issue246-baseline-verify.{json,stderr}`。未使用缺 symbol 编译失败或模拟替身冒充旧行为。

2026-11-02主控自有 API22 HVD实采：空TextArea `editor` 为 visible/enabled=true、focused=false、text/originalText空串，`accessibilityId=22`、`hashcode=33:22`；没有password键。密码模式的空TextInput同样完全没有password/isPassword/inputType键。因此普通TextInput与空密码字段不能从该平台dump区分，未知安全类型TextInput必须拒绝；不能因为空文本无掩码而猜测安全。

首次候选 `swift test --package-path CLI --scratch-path .build/sp257-cli --build-system native --jobs 2 --no-parallel --filter HarmonyVerifiedInput` 已通过16项/3 suites；日志 `.triton/sp257-validation/focused.log`。该结果尚未包含随后发现的“末次capture超时掩盖已观察mismatch”修订，后续需重跑绑定最终差异。

## 本地候选验证（2026-11-02）

- 初版16项focused通过后，主控指出末次capture超时会抹掉已观察到的mismatch；先仅添加 `lastMismatchSurvivesReadDeadline`，同实现出现2个真实行为断言失败（verification被改timeout、code被改input_timeout），`.triton/sp257-validation/mismatch-deadline-red.log` exit1。
- 最小修复：deadline/底层timeout不抹掉已有mismatch，以独立 `timedOut=true` 表示预算耗尽；从未观察到错误值时仍verification=timeout。增补API22实采TextArea/空密码TextInput回归与type叶子timeout=10 override。
- 最终 `--filter HarmonyVerifiedInput`：18项/4 suites通过，`.triton/sp257-validation/final-focused.log` exit0。该计数不与初版16项相加。
- 实际候选CLI执行7组无设备副作用负例（secure/exact/webview/非法timeout/缺expected/未verify/hdc枚举失败）：均非零、单一JSON、not-sent、stdout/stderr无输入或预期哨兵值；`.triton/sp257-validation/cli-failure-json.json`。
- `git diff --check`通过。5个产品/测试文件和binary SHA256保存在 `.triton/sp257-validation/candidate-sha256.json`，binary SHA256 `d255cabf84bb0c3ec8663976b9fca9b1d26bdaca3756e28df5f106913ede4bf3`。
- fixture真实编译和HVD场景由主控继续，见主控维护的 [acceptance](acceptance.md)；设备弹窗不等于文本输入完成。全量回归、主线整合、远端CI和发布尚未由本worker执行。


## 本轮范围退出（2026-11-02）

真实normal在公开ArkUI `enableKeyboardOnFocus(false)` 下仍触发输入法许可。主控取消且未接受条款，没有证明自主完成输入与回读。按用户“只做agent能独立处理并完成验证”规则，#246候选不进入本轮合并/发布，保留源码与真实证据；不要求用户执行人工步骤、不以local tests代替现场。

仅继续收口已知纯代码缺陷：legacy `harmonyTargets` 在verbose空列表后的plain fallback会吞timeout，导致verified路径误报target_unavailable。修复限定CLI verified专用wrapper，legacy/helper/shared SDK均不修改；先准备底层timeout与deadline耗尽两个注入反例，待主控串行测试时段验证。

枚举缺陷已完成局部RED→GREEN：`HarmonyVerifiedInputEnumerationTests` 在原样提取的旧逻辑下2项测试/2个断言失败（`.triton/sp257-validation/enumeration-timeout-red.log`，exit1）；专用wrapper在legacy fallback外保存并重抛底层HostCommandRunError.timeout或本地deadline timeout，legacy/helper/shared SDK未改。修复后全部20项/5 suites通过（`.triton/sp257-validation/enumeration-fixed-focused.log`，exit0），`git diff --check`通过。最新文件/binary SHA256见`.triton/sp257-validation/candidate-enumeration-fixed-sha256.json`；旧manifest仍保留。本轮仍排除合并/发布，不因局部纯代码修复和测试通过改变现场未验收结论。
