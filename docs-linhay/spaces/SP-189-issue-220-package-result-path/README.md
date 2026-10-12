# SP-189 — Issue #220 package-relative xcresult path

## Scope

Fix `triton xcode test --package ... --result-bundle <relative>` so xcodebuild and inline xcresult parsing resolve the bundle against the package working directory.

## BDD

- Given a package action runs xcodebuild from the package directory, when a relative result bundle is supplied, then the command and parser use the same package-resolved filesystem path.
- Given an absolute result bundle or a non-package action, then the path remains unchanged.

## 验证

- `swift test --package-path CLI --filter XcodeCommandTests.packageRelativeResultBundleUsesPackageWorkingDirectory --no-parallel`

本次未执行真实 Xcode 测试。注入式回归模拟成功构建实际创建 bundle，再让 inline parser 读取同一目录，并核对成功计数与摘要；真实 XCTest 兼容性不由 fixture 代证。

2026-10-12：XcodeCommandTests 与 package pipeline 共 49 tests 通过；补充路径 variants 后 2 个 package tests 通过。覆盖 package dir/Package.swift、绝对/相对路径、空路径、默认 DerivedData、落盘与 parser、计数/summary 一致性。修正 cache 元数据按 package cwd 解析；非 package 行为不变。注入 parser 的参数仅加到 test，archive/export 不变。
