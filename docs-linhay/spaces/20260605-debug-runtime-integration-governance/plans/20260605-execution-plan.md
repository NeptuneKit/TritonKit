# Debug Runtime Integration Governance 执行计划

## 执行原则

1. BDD/TDD 先行：先让测试和门禁表达期望，再改实现。
2. 小步提交：文档接入面、SPM 宏实现、验证门禁可拆分提交。
3. 不混入当前工作区已有 CLI/Host 未提交改动。
4. 不破坏内部 `TritonKitShared` module 边界。
5. 用户接入面只暴露 `TritonKit`。

## Phase 1：固化用户接入面只写 TritonKit

### 目标

取消对外 README / public skills 中用户显式 `pod 'TritonKitShared'` 的步骤。

### 任务

1. README CocoaPods 示例只保留 `pod 'TritonKit'`。
2. `tritonkit-dev-feedback` 和 `tritonkit-real-project-regression` 同步只写 `pod 'TritonKit'`。
3. `docs-linhay/dev/20260519-cocoapods-support.md` 说明 `TritonKitShared` 是传递依赖。
4. `docs-linhay/dev/20260519-ios-integration-guide.md` 同步用户接入口径。
5. `verify-ios-debug-isolation.sh` 禁止 README / public skills 出现用户显式 `pod 'TritonKitShared'`。

### 验证

```bash
docs-linhay/scripts/verify-ios-debug-isolation.sh
docs-linhay/scripts/check-docs.sh
git diff --check
```

### 状态

- 已完成并通过 `verify-ios-debug-isolation.sh`、`check-docs.sh`、`git diff --check`。

## Phase 2：引入 Lookin 风格 SPM Debug compile flag

### 目标

由 `Package.swift` 控制 TritonKit runtime Debug-only 启用条件，而不是在 runtime 源码里直接依赖裸 `#if DEBUG`。

### 任务

1. 在 `Package.swift` 的 `TritonKit` target 增加：

   ```swift
   swiftSettings: [
       .define("TRITONKIT_RUNTIME_ENABLED", .when(configuration: .debug))
   ]
   ```

2. `Sources/TritonKit/TritonKit.swift` 改为：

   ```swift
   public static var isRuntimeEnabled: Bool {
       #if TRITONKIT_RUNTIME_ENABLED
       true
       #else
       false
       #endif
   }
   ```

3. `Tests/TritonKitTests/TKPlatformFallbackTests.swift` 测试条件同步为：

   ```swift
   #if TRITONKIT_RUNTIME_ENABLED
   #expect(TritonKit.isRuntimeEnabled)
   #else
   #expect(!TritonKit.isRuntimeEnabled)
   #endif
   ```

4. `verify-ios-debug-isolation.sh` 改为校验：
   - `Package.swift` 包含 `TRITONKIT_RUNTIME_ENABLED` Debug define；
   - runtime 使用 `#if TRITONKIT_RUNTIME_ENABLED`；
   - 不再允许 `isRuntimeEnabled` 直接绑定裸 `#if DEBUG`。

### 验证

```bash
docs-linhay/scripts/verify-ios-debug-isolation.sh
swift test
swift test -c release
swift build -c release --target TritonKit
```

## Phase 3：文档口径修正 SwiftPM 能力边界

### 目标

准确说明 SwiftPM 能做与不能做的边界。

### 文案要点

- SwiftPM 支持按 configuration 设置 build settings / compile conditions。
- TritonKit 使用 `TRITONKIT_RUNTIME_ENABLED` 在 Debug package build 中启用 runtime。
- SwiftPM 不支持 CocoaPods-style configuration-scoped product dependency。
- 若生产 Release target 必须完全不链接 TritonKit，使用独立 Debug-only App target / scheme。
- CocoaPods 用户只写 `pod 'TritonKit'`，`TritonKitShared` 由 podspec 传递解析。

### 修改文件

- `README.md`
- `TritonKit.skills/tritonkit-dev-feedback/SKILL.md`
- `TritonKit.skills/tritonkit-real-project-regression/SKILL.md`
- `docs-linhay/dev/20260519-debug-only-pm-runtime.md`
- `docs-linhay/dev/20260519-cocoapods-support.md`
- `docs-linhay/dev/20260519-ios-integration-guide.md`

### 验证

```bash
docs-linhay/scripts/verify-ios-debug-isolation.sh
docs-linhay/scripts/check-docs.sh
git diff --check
```

## Phase 4：完整本地门禁

### 快速门禁

```bash
docs-linhay/scripts/verify-ios-debug-isolation.sh
docs-linhay/scripts/verify-spm-dependency-boundary.sh
swift test
swift test -c release
swift build -c release --target TritonKit
docs-linhay/scripts/check-docs.sh
git diff --check
```

### 完整门禁（时间允许）

```bash
docs-linhay/scripts/verify.sh --local
```

## Phase 5：提交与收尾

### 推荐提交拆分

1. `docs: simplify TritonKit pod integration`
   - Phase 1 文档和门禁。
2. `fix: gate runtime with package debug flag`
   - Phase 2 runtime / Package.swift / tests。
3. `docs: clarify SwiftPM debug integration boundary`
   - Phase 3 文档口径。

### Memory / 文档记录

每次合并前更新：

- `docs-linhay/memory/2026-06-05.md` 或对应日期日志。
- 执行 `docs-linhay/scripts/check-docs.sh`。

## 风险与回滚

1. **Xcode SwiftPM configuration 传播差异**：若 `.when(configuration: .debug)` 在 Xcode package integration 中表现与 `swift build` 不一致，需要补真实 Xcode sample 验证。
2. **外部用户直接 import TritonKitShared**：本期不删除 product，因此不 breaking；只是用户文档不再要求显式接入。
3. **CI 时间增加**：新增 Release test / build 若进入默认门禁，需观察耗时；必要时仅放入 targeted script，不扩大 docs-only CI。
4. **当前工作区已有无关改动**：提交时必须 pathspec / patch stage，避免混入 CLI/Host 改动。

## 执行记录

### 2026-06-05

- Phase 1 已完成：用户 README / public skill Podfile 示例只显式添加 `TritonKit`，`TritonKitShared` 保留为内部传递依赖。
- Phase 2 已完成：`Package.swift` 为 `TritonKit` 与 `TritonKitTests` 增加 `TRITONKIT_RUNTIME_ENABLED` Debug define；runtime 与测试切换到包内宏。
- Phase 3 已完成：README、public skills、debug-only runtime dev doc、iOS integration guide、session distillation doc 已修正 SwiftPM 能力边界口径。
- Phase 4 快速门禁已完成：`verify-ios-debug-isolation.sh`、`verify-spm-dependency-boundary.sh`、`swift test`、`swift test -c release`、`swift build -c release --target TritonKit`、`check-docs.sh`、`git diff --check` 均通过。
- Phase 4 完整本地门禁已完成：`docs-linhay/scripts/verify.sh --local` 通过；其中 Xcode iOS Simulator Debug build 输出包含 `-DTRITONKIT_RUNTIME_ENABLED`，验证 Xcode SwiftPM Debug configuration 也会传播该 compile flag。
