# SP-190 — 线上 issues 修复集成

## 范围

2026-10-12 初始队列为 #214–#220，影响 CLI、host adapter、shared contract 与文档。隔离 worktree 分项实现，集成分支复核并串行验证；不改变 Web/Wails 业务控制面，不发布版本。

## BDD 与验收

- #214：拒绝未获证明的缓存删除，inspect/dry-run 给出精确安全边界；仍 OPEN，等待外部构建互斥协议。
- #215：显式 Simulator host swipe 无需 embedded server，结果仅证明输入提交。
- #216：reserved text command 的 help/schema/capabilities 一致，不把 pasteboard 写入当作粘贴或保存。
- #217：run 构建失败必须非零退出且不安装/启动，JSON/JSONL 最终摘要保持一致。
- #218：所选工具链/device HID 兼容性独立呈现，不把 inventory/class probe 当作实际触摸验证。
- #219：仅显式 generic iOS build 允许无设备 SDK 编译；run/test/明确 device selector 保持保护。
- #220：package 相对 xcresult 与 DerivedData 的执行、观测、解析路径一致。

## 交付门禁

各 issue focused tests、集成完整 CLI（--no-parallel）、本地门禁、文档与 whitespace 校验。真实设备动作无验收证据时明确保留边界，不冒称 fixture 是真实输入。

## 线上状态

见 [初始队列](plans/20261012-initial-issues.json)。远端尚未写入；push/PR/关闭 issue 等待用户明确授权。主工作区保留原状。

## 集成验收结果

- 完整 CLI：1189 tests / 108 suites + 26 XCTest 通过；根包：264 + 50 Swift Testing 与 7 XCTest 通过。
- 本地门禁通过：Release CLI 构建、CLI smoke、Harmony host smoke、iOS runtime observe smoke、依赖边界/Debug 隔离、文档与 diff 检查；可选 iOS Simulator SDK build 显式跳过，未作真实输入/SDK 编译声明。
- `verify.sh --ci-docs` 通过，190/190 space 已登记。
- 所选 Simulator 只读 HID probe 真实执行成功，框架兼容但 input 未验证；[脱敏摘要](plans/20261012-selected-hid-probe.json)。
- 详见 [交付评审](plans/20261012-integration-review.md)，以及 [提交前线上复查](plans/20261012-pre-publish-issues.json)。#214–#220 仍 OPEN，远端操作待授权。

## v0.2.25 发布推进

用户已明确授权合并 main、提交、推送、发版、回复和关闭。已合并验证后的集成分支；CLI/Web/public skills/CocoaPods spec 对齐 v0.2.25，发布门禁及线上 CI 验证后发布。#215～220 按已声明范围回复关闭；#214 仅安全止损，保留 OPEN。
