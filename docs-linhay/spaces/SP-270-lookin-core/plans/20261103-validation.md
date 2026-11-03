# Lookin 核心能力验证

## Requested

将 Lookin 核心能力内置 TritonKit，沿用现有界面。交付 embedded runtime、CLI/HTTP、只读检查器；不依赖 LookinServer，不承诺完整 Lookin 功能对等。

## Observed

候选位于 `feat/SP-270-lookin-core`，基线 `origin/main@edffb45e79775ea69375fd7bdf9a99edccd600ad`。实现、SDK/CLI/Web 联合验证完成，未提交、未合并、未发布；主目录已有 WIP 未修改。

完整 CALayer 树、裸层属性、按需详情、solo/group 双截图、现有 typed patch 回读以及现有 Inspector 的只读 3D 模式已接通。契约见 [技术说明](../../../dev/20261103-lookin-core-inspection.md)，视觉记录见 [Web 验收](web-design.md)。

## Evidence

| 验证 | 结果与边界 |
| --- | --- |
| SDK macOS 全量 | 7 XCTest + 423 Swift Testing、0 失败；1 项真实 Bonjour 环境条件跳过。UIKit 分支不以此计验收。 |
| CLI 全量 | 162 XCTest + 1759 Swift Testing、188 suites、0 失败；3 项真实环境条件跳过。覆盖 details transport、schema、错误 JSON 和 inline PNG。 |
| Web 全量 | 174/174 通过、无跳过；显式使用本候选 CLI。生产 build 与 design:build 通过。 |
| iOS Debug App-hosted | 独立 iOS 27.0 Simulator，16 项通过，含 7 项 HierarchyCore：裸层树、非零 bounds 双图像素/恢复、失效 OID、像素预算、patch 回读、非 backing delegate、隐藏层部分成功。 |
| iOS Release App-hosted | 5 项通过；实际执行 Release 入口与直接截图 helper 不采集测试。 |
| 真实 CLI/HTTP/WS | 自有 fixture + 自有 127.0.0.1:19422 server，7 个真实 layer / 8 个 scene 节点；6 组 solo/group 均经现有 bridge 正确加载。 |
| details 真实 PNG | 父层 OID 12：solo 首像素 `[255,0,0,255]`，group 首像素 `[0,0,255,255]`，两图均 512×512；UIKit 测试另覆盖内点像素和原隐藏状态。 |
| 错误与属性 | 有效+失效 OID 返回 `partial=true`、`object_not_found`、exit 1；OID 0 返回单 JSON/exit 64；裸层 cornerRadius 修改后详情回读 7，再恢复 0。Release CLI 二进制也真实读取详情成功。 |
| evidence capture | `ok=true, partial=false`，无 error/skipped，含 hierarchy/screenshot/geometry 等 9 类 artifacts；原始 bundle 留本地 `.build/sp270-validation-host/live.tritonevidence`。 |
| 浏览器 | 正式组件消费真实 runtime 快照，12 PNG 全部 decode；双向选择、旋转、间距、相机重置通过。400/520px、200% zoom 无横向溢出，坏图回退和空态通过。真实素材验收 provider 为隔离只读 harness，第二 target 复用同快照仅验证身份切换；不宣称未隔离的正式桌面端到端验收。 |
| 本地总门禁 | `verify.sh --local` exit 0；通过临时 swift wrapper 使用 native/jobs 2，所有检查照常执行。`TRITON_VERIFY_XCODE=0` 跳过泛名称 destination，已由上面的专属 Simulator Debug/Release 与 fixture build 补验。 |
| CocoaPods 标准 lint | 失败：本机唯一 Xcode 27.1 接受 iOS 15…27.1，拒绝 podspec 原有 iOS 13。无 SDK 源码编译诊断；不能记标准 lint 通过。 |
| CocoaPods 工具链兼容 lint | `XCODE_XCCONFIG_FILE` 仅覆盖部署目标到 15.0 后，`pod lib lint TritonKit.podspec --allow-warnings --skip-tests` exit 0，明确 `TritonKit passed validation.`；证明单 Pod 编译，不替代 iOS 13 验证。podspec 未修改。 |

主要日志在 [validation](validation/)。具体命令：

```sh
swift test --build-system native --jobs 2 --no-parallel
swift test --package-path CLI --build-system native --jobs 2 --no-parallel
TRITONKIT_TRITON_BIN=<candidate-cli> npm test
python3 docs-linhay/spaces/SP-270-lookin-core/plans/generate-validation-host.py
xcodegen generate --spec .build/sp270-validation-host/project.json --project .build/sp270-validation-host
triton xcode test --project <generated-project> --scheme LookinCore --simulator <owned-simulator> --configuration Debug --jsonl
triton debug details --target <fixture-runtime> --port 19422 --oid 12 --screenshots both --json
```

可复跑宿主由 [生成器](generate-validation-host.py) 创建；不把验证宿主或合成资料加入正式包。`triton status/doctor/capabilities/schema/plan` 事实先于设备动作保存，原始设备清单包含其它工作负载而留在 `.build`；归档仅保留脱敏摘要。device-type inventory 在 schema 中未覆盖，唯一只读 fallback 为 `xcrun simctl list devicetypes --json`。

## Gaps 与 Fixes made

- SDK 原空详情数组由失败测试抓住；availability 测试另实际捕获 generic failure 缺 `partial` 与 screenshot capability 漏检，修为 typed envelope 与双 capability gate。
- CLI 首轮 baseline 编译期间 taxonomy 被改动，导致 `input file was modified during the build`；此轮不算行为红证据。旧 CLI 实际 `debug details` 返回 `unknown_option` / exit 64；之后冻结整个 module 再运行全量。
- CLI 首轮全量发现 public skill command snapshot 未登记 details，补齐后 1759 项通过。
- iOS 首次测试编译暴露 nested `#require` 宏递归，拆成 Data 与 UIImage 两步后真实执行通过。macOS 分支跳过不能发现此问题。
- 上传失败保留 PNG 但 scene 丢弃、隐藏层有属性却被标全失败、零尺寸祖先过滤后代、透明度优先级以及 solo inline 被误标子树，均已修复并补覆盖。
- docs 门禁发现日志名称含 `final`、路线入口未使用规范 space 标签，已改为可追踪日期/状态名与规范链接，没有放宽校验器。

## Remaining risk

1. iOS 13 的标准 CocoaPods lint 仍须使用支持该部署目标的工具链/CI 验证；当前仅完成 iOS 15 工具链兼容 lint。
2. 单次 `CALayer.render`/PNG 编码不可中断；2 秒是操作间预算。视频、Metal、远程渲染不保证内容完整；轴对齐分层投影不等于完整 transform3D 合成。
3. 本切片未做 Wails/原生桌面壳发布验收、完整 SwiftUI 语义树或任意对象调用控制台，也未整合回 main。

## 清理与沉淀

浏览器 taskSpace 已结束；仅停止本轮 19422/34127/34128 服务，未触碰共享 19421 服务。自有 Simulator 已 shutdown，保留专用实例和构建证据以便复跑。临时 Web harness 已删除。构建冻结经验写回 ops-governance，截图来源/部分成功/裸层身份规则写入技术说明与 EXPERIENCE；space/index/memory 同步，未自动创建 Git 提交。

## 自动流程接续（独立集成，尚未发布）

2026-11-03在`9578782a`基线上逐文件三方整合。原42源码/测试和2binary manifest重算全部一致；完整74文件快照保留在`archives/SP270-integration`。唯一产品交集Web/package.json保留0.2.40并合入新测试清单；共享日记/索引保留SP271/272条目，SP270占号stub改为完整权威记录。原始ignored证据仍位于原SP270工作区，不冒称集成区已重新运行。既有真实App-hosted与素材浏览器证据绑定原精确SDK/Web源码；联合候选检查、标准iOS13Pod和正式包验收待完成。

集成控制器另逐文件核对全部非CLI Sources、Package.swift及根包Swift测试205项，与已执行16 Debug/5 Release的原候选全部字节一致，绑定清单`archives/SP270-integration/sdk-fixture-source-binding.json`。因此明确复用该真实SDK验收，未称重新运行这些测试；正式安装CLI针对自有fixture的复验仍待发布。16张截图已复核，15张合成/自有fixture截图纳入；1张含公开范围未确认的既有mock业务名仅留本地，原图与全部原证据不改写。
