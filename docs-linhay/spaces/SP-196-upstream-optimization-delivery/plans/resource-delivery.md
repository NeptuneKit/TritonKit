# Simulator Resource 上游保护交付

影响层：macOS CLI resource catalog、plan、apply、verify、restore；不扩其它 Apple 平台、HTTP、Web 或 shared 公共模型。

## BDD 与验收

- Given stock/ci/custom profile，When plan/apply/verify，Then 三条路径使用相同 label 计算；assistantd/gamed/sharingd 只能启用，保留 widgets 必须同时保留 navd。
- Given 旧版本禁用受保护服务，When apply，Then 修复服务；verify 对残留 protected disablement 或不应禁用的 managed labels 失败。
- Given shutdown 离线覆盖文件含用户自定义 label，When apply，Then 仅修改 managed delta，用户条目保持。
- Given receipt 与现有状态发生用户改动，When restore，Then 只撤回仍等于 applied 的 receipt-owned delta，不改用户后续 override，不重新禁用 protected 服务。
- Given 非法 UUID、receipt、符号链接或超预算文件，Then 在副作用之前拒绝；命令失败及读回不一致不得报告成功。

顺序：先失败测试，再最小实现与 focused 回归。测试隔离 scratch `.build/sp196-resource`，无设备动作。

上游固定来源：[simslim profiles.go 6518ba7e](https://github.com/MobAI-App/simslim/blob/6518ba7eab1123d7e1d7797b0e05f51043b42a5b/profiles.go)。MIT notice 保留；feature labels 保留受保护 label 用于 doctor 诊断。

## 已实现

- pin 完整上游 SHA `6518ba7eab1123d7e1d7797b0e05f51043b42a5b`，受保护服务只保留 repair allowlist 与原因；widgets category/feature 都加入 navd。
- plan 真实 resolve stock/ci/custom，输出 desired labels、catalog commit、protected reasons；apply、verify 复用同一 category exception 算法。
- apply 修复旧 protected disablement 并执行 managed enable/disable delta；online 和 shutdown offline 都保持用户非管理 labels；shutdown 路径不再提前调用 spawn 查询。
- verify 精确比较 managed disabled 集，拒绝额外禁用的 protected/kept 服务。
- restore 校验 UUID、receipt target一致与 managed allowlist；只恢复 receipt delta 且当前状态仍与applied一致的labels，用户移除显式enabled条目也保持；protected服务绝不重新disable。每个mutation检查exit并独立读回。
- receipt/profile读取限1MiB，逐层 nofollow descriptor、owned regular single-link file及读前后稳定性检查。offline plist读取同样有界，boolean类型严格、拒绝symlink、同FD目录原子写。

## 验证进度与限制

- CLI首次失败测试命令：`swift test --package-path CLI --scratch-path .build/sp196-resource --no-parallel --filter 'SimulatorResource(Catalog|Mutation)Tests'`。在共享代码未冻结期间遇到其它轨道 Xcodebuild 参数兼容错误，未执行到测试。
- 追加一次独立 baseline catalog 红测（从 HEAD 提取，仅写入ignored scratch）：明确退出1，证实旧protected服务与widgets/navd行为错误；当前catalog相同场景绿测退出0。
- 两次全包增量编译先后遇到其它轨道 private Xcode helper 与尚未发布 resize source；已通知所有者，不跨文件修改。
- 最终focused测试结果待本轮编译补记。无真实Simulator操作；内存、XCUITest启动时间和日志洪泛改善仍需主控独立新建Simulator实测。
- shared receipt未存全量显式Bool/缺省状态：无法区分用户再次写同一个Bool。恢复只保守撤回已记录、仍匹配的delta；没有label集的历史receipt安全no-op，不凭category猜测恢复。离线文件发布的稳定性不是多进程compare-and-swap；需要保持设备动作串行。
- 其它Apple平台例外未纳入；未移动tag、push或commit。

## 本轨道收口（2026-10-14）

实现与测试源码冻结。第三次focused命令仍在其它轨道追加resize screenshot hook期间编译失败：`CLIHostHarmonyRuntime.swift:415` / `CLIHostRuntime.swift:122` 未找到 `resizeAwareSimulatorScreenshotCommand`（日志 `/tmp/sp196-resource-green3.log`）。主控已接管源码冻结后的统一full/focused回归，本轨道不继续抢占全包编译。

`git diff --check`（本轨道源文件、测试与交付文档）通过。尚未宣称完整CLI测试或真实Simulator效果通过。最终回归应包含 `SimulatorResource.*Tests`，涵盖catalog、command parser、inspection、state parser、receipt安全读取、online/offline mutation和保守restore。

## 集成回归反馈修复

主控完整CLI回归发现offline merge fixture报`invalidReceipt`。真实managed `com.apple.apsd`选择合法；纯实际source executable复现证明根因是macOS Foundation对temporaryDirectory调用`resolvingSymlinksInPath`仍保留`/var/folders` alias，生产逐层nofollow正确拒绝`/var`符号链接。仅fixture在创建临时目录后用`realpath`获取physical path，再注入root；未放宽生产allowlist/nofollow。纯executable修后disable→enable→readback通过，fixture增加unknown true与explicit false保持断言。主控继续统一focused/full测试；这条教训属于fixture路径真实性，不把实用户路径在生产里自动canonicalize来绕过安全门禁。

## iOS 27 状态实测发现与解析修复

主控在独占目标执行 resource status，CLI 返回 `malformedOutput`；记录的底层 `launchctl print-disabled system` 输出退出0，首尾标记包含tab缩进，closing brace为`\t}`。现有parser只整体trim，footer的行内leading tab仍在，误拒绝合法输出。私有raw证据为`.triton/sp196-validation/resource-raw.stdout`；不把目标标识或私有设备原始日志放入public资料。

先把同一17条enabled entries的输出加入`SimulatorResourceStateTests`，并在独立`.build/sp196-resource/parser-fixture` executable中提取实际parser执行：修前退出1，`FAIL real indented fixture: malformedOutput`。最小修复仅对header/footer各自trim whitespace，entry regex、重复label拒绝和truncated-output拒绝均不变。修后同一raw退出0，额外严格内容/重复label/合法boolean检查通过。新增测试还覆盖两种wrapper周围的空白，以及非法header/footer尾随内容。

验证命令：`swiftc .build/sp196-resource/parser-fixture/main.swift -o .build/sp196-resource/parser-fixture/run`，然后`.build/sp196-resource/parser-fixture/run .triton/sp196-validation/resource-raw.stdout`。此纯parser红绿验证不占用主控shared scratch、不启动设备或完整package；新增XCTest由主控统一回归。尚未重新执行真实CLI status，也未进行resource apply/restore，不据parser修复宣称实际mutation成功。

## 主控最终验证

主控最终回归：CLI XCTest41/Swift1323通过。专用iOS27 Simulator photos-only plan/apply/verify/restore全exit0；前后disabledLabels相同。真实输出缩进已纳入回归；未量化内存收益。私有证据`.triton/sp196-validation/resource-*.json`。
