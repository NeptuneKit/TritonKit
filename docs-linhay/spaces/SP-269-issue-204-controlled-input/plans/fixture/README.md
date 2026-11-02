# Controlled-input acceptance fixture source

本目录只保存自有 iOS App-host 的 7 个小型可复现源文件；先复制到仓库外独立目录，再生成离线 React bundle 和 Xcode 工程。不要把 bundle、Generated、xcodeproj、DerivedData 或 xcresult 写进本目录。

App、XCTest 与 JSX 的行为源码逐字节等同于原 SP269 第 7 例候选。可移植副本只改变 `project.yml` 的 package 路径与 `build.cjs` 的依赖路径绑定；打包器会创建自己的 Resources/Fixture 输出目录。两者都要求显式 `TRITONKIT_REPO`。XcodeGen 2.46.0 的 `generate --help` 提供 `--no-env`（默认启用环境展开）；本次已实际生成外部工程并断言 package `relativePath` 等于指定 checkout，没有残留环境占位符。不要传 `--no-env`。

## 仓库外重建

选择已有维护授权、包含目标 SDK 候选及已安装 Web dependencies 的 checkout；不安装网络依赖，不使用 CDN。React/react-dom 固定 `19.2.7`、esbuild 固定 `0.27.7`，脚本遇到版本漂移即失败。

```sh
export TRITONKIT_REPO='/absolute/path/to/verified/TritonKit'
export TRITON_FIXTURE_HOST='/absolute/path/to/fresh-external-host'
mkdir "$TRITON_FIXTURE_HOST"
cp -R "$TRITONKIT_REPO/docs-linhay/spaces/SP-269-issue-204-controlled-input/plans/fixture/." "$TRITON_FIXTURE_HOST/"
cd "$TRITON_FIXTURE_HOST"
node FixtureSource/build.cjs
xcodegen generate --spec project.yml
```

`Resources/Fixture/BUILD_INFO.json` 记录实际输入及制品 hash。此次可移植副本在外部同级目录重建得到 614379 字节 bundle，与原第 7 例候选的 SHA256 完全相同：`b483f31c14d992501d50431fbc4a5803bc17843dfa102e40afa66c4587d44765`。esbuild 非 minify 输出包含依赖源路径注释；不同目录布局可能改变这些注释及 bundle hash，不能将不同 hash 冒称原二进制。保留实际 manifest 并区分路径变化、依赖变化与行为源码变化。打包脚本本身的 hash 因环境绑定修改而变化，这是明确的可移植副本差异。

fixture 的 deployment target 为 iOS 17，目的是对齐当前 XCTest dylib 需求；不改变 TritonKit SDK 产品最低版本。JS target 仍为 safari16。App bundle 为 `com.neptunekit.acceptance.webview204`，scheme 为 `ControlledInputAcceptanceHost`。

## Triton-first 与验收

由主控先核对设备归属和活动任务，串行保存当前 binary version、status、doctor、capabilities、相关 schema/plan 和 Xcode status；示例不授权占用其他任务设备。安装版缺少必要能力时保存实际失败再按仓库规则 fallback。

```sh
triton version --json
triton status --json
triton doctor --platform ios --json
triton capabilities --json
triton schema --command xcode.test --json
triton plan webview-check --json
triton xcode status --json
triton xcode test --project ControlledInputAcceptanceHost.xcodeproj --scheme ControlledInputAcceptanceHost --configuration Debug --destination 'platform=iOS Simulator,id=<owned-simulator-udid>' --derived-data-path DerivedData --result-bundle green-204.xcresult --timeout 600 --build-setting CODE_SIGNING_ALLOWED=NO --json
```

每轮用新的 result bundle 路径并保存完整外层退出码、测试断言和收尾信息。不要用 XCTest 内部完成代替外层成功，也不能把工具 timeout 当正常 exit 65。SDK runtime 默认不启动 server；仅显式 `TRITON_ACCEPTANCE_RUNTIME=1` 才启用独立 Debug bootstrap。

7 个 App-host 测试覆盖：真实 legacy provider 的受控 textarea/input/contenteditable 正例、React state/事件/DOM/validation 与强制 rerender、框架拒绝写回、strict 未 opt-in 拒绝、双 WebView ambiguity 零输入，以及输入即时接受后 setTimeout(0) 仅回滚 DOM 的隔离负例。最后一例要求 provider 的 bounded settled readback 失败、unknown outcome、不回显输入；它不伪装成某私有 App 的业务复现。没有复制产品输入实现或用 strict helper 替代 legacy 正例。

主要观察入口为 `window.fixture204.read()`（generation、values、changes、domValues、validation、renderGeneration、rollbackProbe），控制入口 `forceRerender()`、`reset()`、`setRejectChanges(true)`、`armQueuedDOMRollback()` 仅属于自有 fixture。XCTest 调用实际 SDK `performFocusedWebViewTextInsertionIfAvailable`，并要求真实 WKContentView first responder。

## 原实测证据与副本验证边界

原运行工程位于外部 worktree 根的 `SP-269-ControlledInput-AcceptanceHost/`；原 6 例 RED 源与 hash 已归档为同一根下 `archives/SP269/host-red-source/`。主控已观察原测试本体约 4.15 秒、4 failed / 2 passed、20 assertion failures，但 Xcode 结果收尾未终止，外层 600 秒报 `host_command_timeout` / exit 1；根因仍未判定。原 6 例 RED bundle hash 为 `712773a09aabf992c00a85de049145cdacdae54b1e20158d4f4822c2c7d3a5f3`，不可与新增第 7 例候选混用。

本副本只完成离线 Node 打包与 XcodeGen 展开验证，证据保留在外部 worktree 根的 `SP269-portable-fixture-check-m6zvh73a/portable-verification.json`。没有运行 Xcode build/test、设备或 Git；真实 GREEN 状态由 Space 主验收报告维护，本文件不宣称通过或原私有 App 已恢复。

## V2：默认未 opt-in 验收修正

首轮 7 项 GREEN 的 HTML 根节点仍含 `data-triton-form-input="1"`，故不能证明 legacy provider 支持未 opt-in 页面；strict 负例单独移除属性不能补足此缺口。旧 HTML、构建脚本、测试源、BUILD_INFO 和说明及 SHA256 已保存在外部 `archives/SP269/green-v1-optin-fixture/manifest.json`，首轮结果保留为历史，不作为该边界的通过证据。

V2 默认 HTML 删除该属性；每个测试在加载完成后、任何输入之前显式断言根节点无 opt-in 属性且 `window.__tritonFormInput !== true`，不满足即停止该测试。strict 负例也直接使用同一默认页面，不再先删除属性或覆盖全局标记。JS 行为及 7 个场景不变，bundle SHA256 仍为 `b483f31c14d992501d50431fbc4a5803bc17843dfa102e40afa66c4587d44765`；HTML 与测试/构建脚本 hash 随本次修正变化，以 V2 BUILD_INFO 和外部 `archives/SP269/green-v2-no-optin-source-manifest.json` 为准。V2 真实 7 项验收待主控串行执行，通过后才能取代首轮在此边界的不足；本源码准备不等同于验收通过。

最终实际验收状态见[主报告](../20261102-validation.md)：主控已使用原外部工程无opt-in v2执行7tests/0失败/0跳过，正常exit0与完整xcresult通过。该结论绑定原工程及本副本字节相同的App/Test/JSX和HTML模板；副本自身仍仅做包外重建/hash等价验证。
