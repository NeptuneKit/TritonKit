# 实现与验证计划

1. 根因：`handleAllAttrGroups` 将 registry 对象直接 cast 为 CALayer，UIView oid 提前返回空数组；builder 已使用 `as? UILabel`，子类识别并非根因。
2. 请求路径兼容 UIView/CALayer，MainActor 内解析对象与采集 UIKit 属性。
3. Foundation helper 有界枚举 attributed runs，UIKit helper 只序列化公开 UIFont/UIColor 属性；既有 group/section/attribute DTO 不变。
4. UILabel group 保留既有 text/font_size/lines；text 使用最多 4096 UTF-16 单位的预览（可能在组合字素内截断，但不截断 surrogate pair），明确 text_truncated/text_utf16_limit；新增字体、颜色和 coverage/truncation 元数据；run 以独立 section 表达，不重复正文。无效 pointSize 不编码为有效字号，使用 font_status=invalid_point_size。
5. 有效样式指公开 UILabel/NSAttributedString 指定及继承样式，不承诺 layout 后自动缩小字号、glyph fallback、私有绘制效果。
6. 先添加测试并记录失败，再实现，使用独立 `.build/issue211` scratch 测试；主控串行执行 iOS 真实验证和总门禁。

Apple 本地参考：UIKit/UILabel/attributedText（赋值会更新 label 起始位置样式）和 UIColor.resolvedColor(with:)（按指定 trait 解析）；未调用私有 API。

## 验证记录（2026-09-08）

- RED：`swift test --scratch-path .build/issue211 --filter TKAttributedTextRunsTests` 因未实现 `TKAttributedTextRuns` 失败；兼容性追加场景因未实现 `TKTextAttributePreview` 失败。
- GREEN：同一 focused 命令 4 tests / 1 suite 通过，覆盖 UTF-16、多 run/length 上限、空输入和预览 surrogate 边界。
- FULL：`swift test --scratch-path .build/issue211`，macOS 267 tests / 33 suites 通过。
- `git diff --check` 通过。
- `docs-linhay/scripts/check-docs.sh` 当前只报 SP-174 缺少 index 唯一链接；公共 INDEX/README 由主控负责，集成后重跑。
- UIKit 的 4 tests 尚待主控在专用模拟器运行，macOS 编译排除这些测试，不能作为其通过证据。可复跑入口：`triton xcode test --package <worktree> --scheme TritonKit-Package --destination 'platform=iOS Simulator,id=<dedicated-simulator>' --only-testing TritonKitTests/TKLabelAttributeGroupsTests --result-bundle <unique-result>.xcresult --json`。先遵守 Triton-first 状态/schema/plan 记录；主控负责设备和服务串行执行。
- 本 issue 不新增依赖、锁文件、生成产物或 Web/Wails 控制面。样式为公开属性快照，不承诺 glyph 实际 fallback、自动缩小字号或 UILabel 子类的私有绘制效果。

## UIKit 首轮失败与 fixture 修正

主控在 iOS 26.5 专用模拟器实际运行 4 tests：3 passed / 1 failed。失败项为动态色测试的两个严格断言：默认颜色得到 black，run 得到 blue，均表明 provider 收到非 dark trait。旧 fixture 只对游离 UILabel 设置 override，没有建立 UIWindow trait 继承环境，也未验证 label 的实际 trait；生产实现已经明确调用 `resolvedColor(with: label.traitCollection)`。

修正只作用测试：建立 UIWindow/root UIViewController、在 window 设置 dark、附着 label 并 layout；采集前要求 label.window 与实际 dark trait 都成立。随后特意在 ambient light trait 下采集，仍要求默认色 white、attributed run red，验证读取目标视图 trait 而非环境 current。未放宽颜色断言或修改生产解析逻辑。修正后待主控集中复跑 UIKit；macOS focused collector 4/4 通过不能替代此验证。
