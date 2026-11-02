# 2026-11-02 #5 Harmony role 验收

## 原因

Harmony `Wait.run` 接收 `role` 后未传入 `waitForHarmonyText`，后者按纯文本匹配，导致错角色也 `matched=true`。此前通用 wait 支持 role 的结论不能证明 Harmony host 分支正确。

## 证据状态

RED 已执行：warm CLI SHA256 `795e5d6428e0096b8eb3d48e8188a2357a5d7fc4c8a90e8323ee191cfe1d5082`，12 个真实进程场景中 4 个违反预期：`--text`/`--exists` 错误 role 返回成功、同文案选到 Text、`--gone` 不按 role 判断。无 role、正确 role 和缺文本对照通过。

候选：只向 Harmony helper 传递 role，同节点文本精确匹配+原生 type 去空白后大小写不敏感比较，保留无 role 行为；新测试覆盖匹配、缺 type/bounds、无语义别名、等待正反向。GREEN 与最终整合验收待主控串行 build；不得把新测试存在当作已通过。原始日志位于 `.triton/sp267-validation/`，保留合成数据，不访问真实设备。

## 独立审阅 P2：空 role 的缺失误判

审阅发现初始候选把空 role 当作永不匹配，导致 `--gone` 可把无效条件误认为不存在。补充 BDD 要求空字符串、空白（包括 tab/newline）先拒绝，文本存在与否均不能使非法 role 成功。

接替 RED：`.triton/sp267-validation/red-empty-role-takeover/report.json`；旧 CLI SHA256 `1501aeb93c7cc53c7551c20ccd6f2b9d9f9118311f1292000890f7f2205acf5a`。18 个进程场景中 10 个失败：原角色约束 4 个，新增 `--text` / `--exists` / `--gone` × 空/空白 role 6 个全部失败，实际 backend 调用 3–7 次，未输出预期 validation envelope。旧二进制与原 RED 的 SHA 不同，分别保留，不冒称同候选。

最小补丁：统一 role normalization，空值抛专用验证错误；命令层在目标 discovery 前转单个 `validation_failed` envelope；直接 helper 在布局捕获前同样拒绝。未调整 deadline。新增单测覆盖 3 selectors × 3 空白值的零 backend，以及 matcher/helper 的零 capture；既有真实 CLI fixture 保留 18 场景。

GREEN 待主控 serial build + `swift test --package-path CLI --no-parallel --filter HarmonyWaitRoleTests` 和 fixture 复跑。子任务按限制未 build、未 Git 写入、未接触真实设备。经验：否定条件（gone）必须先验证 selector，有效零匹配与非法条件不可等价；保存在本记录供主控汇入权威经验。

整合 SP266 总 deadline 后，角色语义 fixture 使用 3s discovery+layout 预算，避免旧 0.9s 将 Python fixture 启动误计成角色判定失败；期望匹配/超时、同节点 bounds 与空白角色零 backend 断言不变。此脚本验证角色行为，不用作性能阈值。

首次主控组合编译失败：throwing matcher 在 #require 宏内缺少内层 try，修正测试表达式后复跑；日志 `archives/SP264/issue5-combined-green-v2.log` 保留。该编译错误不计产品 RED。

组合 Swift GREEN：角色、deadline 与错误分类三套共 24 项通过，保留 `role` 与 `startedAt` 同时传播、空白角色在 discovery 前拒绝；日志 `archives/SP264/issue5-combined-green-v3.log`。独立复审未发现剩余 P1/P2。

实际 fake-HDC CLI 18 场景全部通过（`.triton/sp267-combined-cli-green/report.json`，binary SHA-256 `64a6f1e8b7686c88f828004bb06d1375bca16d82a14c8cab43a41e74fcf689f7`），含三种 selector 的空/空白role零backend、同节点角色与gone正反对照。仅合成HDC，不扩大为真实设备UI验收。
