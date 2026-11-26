# SP-297 · Xcode 共享编译缓存

状态：随 [v0.2.48](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.48) 发布并完成正式包验收。仓库内 `TritonKitDemo` 为固定验收入口，跨路径命中、变更失效、并发写入与独立重放均已通过；CLI 仅显式启用。该工程依赖本地 TritonKit SwiftPM 产品，根包无远程包依赖。

## 边界

- 按用户裁决，不再使用外部工程作实现门槛。冻结本仓库 Git 提交，导出 `Examples/TritonKitDemo` 与根 SwiftPM 包到不同的临时源码根，以同机、同工具链、独立 DerivedData、同一试验 CAS 复验。不改原 demo 源码、默认 DerivedData 或默认 CAS。
- 前置门槛通过后再改 TritonKit CLI 的 `xcode build` 和对应 schema/构建摘要；不改变 CI、`test`、`run`、发布和清理流程。`build` 的默认行为可根据真实复验及兼容性证据再决定，不能静默套用未经验证的配置。
- 主 App 原始构建日志留在本机，项目文档仅记录脱敏、可核验的结果。轻量宿主已验证的诊断口径见[缓存观察契约](../SP-175-issue-212-xcode-cache-evidence/plans/20260908-cache-observation-contract.md)。

## 2026-11-26 · 已退役的外部工程试验（仅历史）

- 用固定 Git 提交与两个 gitlink 修订导出隔离快照；只读原检出。工具链为 Xcode 27.1（27A9275）/ iOS Simulator SDK 27.1，Triton 0.2.47。以 Debug/arm64、禁用签名和索引、显式关闭 CAS 跑基线。
- 首次依赖解析在远端 Git clone 失败；进程级本机 Git 镜像恢复了同一锁定修订，锁文件字节未变，47 个 checkout HEAD 均与锁匹配。第二次仍在包解析退出（Xcode 74，Triton `xcodebuild_failed`）：上游 CDN 的 TLS 证书不匹配主机名，实际需要两个 SHA-256 固定的二进制归档。查到的同名公开镜像与锁定摘要不一致，不采用。
- `pod-archive` 是 ONNX 上游二进制文件名，不是项目使用 CocoaPods 的证据：当前是 SwiftPM `binaryTarget` 拉取 ZIP，没有恢复 `pod install` 的需求。应用可以在运行时不使用相应功能；当前主 App target 仍无条件依赖 SFace 产品及 OCR adapter，两者都把 ONNX Runtime 纳入 SwiftPM 图。未找到能保持当前 target 输入不变并跳过 ONNX 的开关。
- 本机原始证据在 `.triton/benchmarks/2026-11-26-overloaded-main-cas/`，含原始日志、命令与 pinned checkout 验证。外部工程试验没有成功产物、跨路径命中、变更失效或并发结论；现在不再重跑它，也不作为实施门槛。

后续只读复核：[Runtime 历史发布源清单](https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/3/a/a/onnxruntime-c/1.24.2/onnxruntime-c.podspec.json)与 [Extensions 历史发布源清单](https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/7/f/9/onnxruntime-extensions-c/0.13.0/onnxruntime-extensions-c.podspec.json)都仍指向同一 CDN，不提供独立下载源；本机限定路径索引也没有命中同名归档。两个独立 DNS 解析器返回相同 CDN 链，严格 TLS 复核仍失败，CDN 别名通过 TLS 但返回 404；公开网页档案查询这两个原始 URL 均未返回快照。已在本机证据目录准备 `verify-onnx-archives.py`，负例验证缺失文件与错误摘要均返回非零；没有原版 ZIP，尚无恢复正例。

## 2026-11-26 · 仓库内 Demo 复验通过

- Xcode 27.1（27A9275）、Triton 0.2.47、iOS Simulator SDK 27.1、Debug/arm64，冻结源码 `8804b86e`。通过 `triton xcode build --build-setting …` 在隔离副本构建，索引和签名仅为本次试验显式关闭。每次检查实际退出状态、对应 `.app` 的 bundle ID、主程序和 debug dylib 的 Simulator 平台、源码探针及对应 CAS 诊断；未安装或启动 Demo。
- **跨路径：** 相同 SwiftPM 根目录名 `TritonKit`、不同父目录和全新 DerivedData，Swift/Clang 映射源码根及 DerivedData 的实际路径拼写（本机存在 `/tmp`、`/private/tmp` 两种）。命中 **175/175** 条编译重放诊断：App 3/3、本地包 22/22、SDK/未署名 150/150。`App.swift` 重放了预热的同一键。时长是单次观测，非正式性能基准。
- **失效：** 只改临时副本的 `App.swift` 字符串；App 3 条诊断 miss，`App.swift` 键与预热不同，新标记进入实际 debug dylib；本地包仍命中 22/22。
- **并发读写：** 两个不同临时源码根各改一个不同标记，两个 `xcodebuild` 时间区间重叠且独立 DerivedData，共享同一 CAS。两边 `App.swift` 均首次 miss、产物只含各自标记；随后从新的源码路径和 DerivedData，分别命中对应并发写入的键，产物未串用。
- **反例：** 仅映射一种路径拼写仍可能漏掉本地 SwiftPM 输入；改 checkout 叶目录名会改变 Swift 的 `-package-name`，Prefix Mapping 不会消掉该差异。以 `llvm-cas` 比对同源码模块任务，实际差异可追到 `-package-name`；App 的显式模块表随上游模块键变化。不得通过改包名或自动注入额外语义设置来强制命中。
- 本机证据：`.triton/benchmarks/2026-11-26-tritonkit-demo-cas/`，含可复跑脚本、原始日志、产物平台检查、逐批 key/outcome、写入重叠时间及缓存键比较。一个 Swift 批次的多个 `local cache found` 可以只对应一条 `replay cache hit`；不得把批次次数说成源码文件数量。

## 2026-11-27 · CLI 候选验收

- 已接入普通 iOS Simulator `xcode build --compilation-cache shared`。保留 Xcode 默认行为；显式配置分别验证源码根、独立 DerivedData、共享 CAS 和本次实际 Xcode。`compilationCache` 是单次构建日志观测，不继承成增量验证；缺失诊断不填 0。
- 候选 CLI SHA-256 `c739fb682ca412b1aca8643cd87cd88913b8e467e2133d9d5908ef927363e9bf`：全量 CLI 1,916 项通过，父级与 `xcode.build` schema 已回读。八次仓库内 Demo 构建与四个 fail-closed CLI 负例通过，均未关闭索引。默认构建没有注入也没有摘要字段；预热 0/175，跨路径 175/175；变更 172 hit / 3 miss，产物有新标记。两路并发分别写入不同 App key，随后新的 DerivedData 各自 175/175 重放，未串用标记。
- 初版真实 CLI 未创建的 DerivedData 只投影 `/private/tmp`；缓存键中仍含 `/tmp` 路径，造成 App 与本地 SwiftPM 的 25 条重放诊断全 miss。修正为先规范化现存祖先，再附加未创建路径组件；定向负例覆盖此拼写差异及同根/大小写冲突。另修复父级 failureCodes 与真实父子 schema parser 正例的一致性。此后用新候选完整重跑，不以初版结果代替验收。
- 本机候选证据：`.triton/benchmarks/2026-11-26-tritonkit-demo-cas/cli/verified-uSFrDl/`（精确候选源码指纹、原始日志、逐轮键、产物校验与 schema）。全量 CLI另有 167 项 XCTest 通过，根包 132 + 313 项 Swift Testing 通过；`verify.sh --local` 与 `--ci-docs` 通过。`--local` 的根包 Simulator 构建用 `TRITON_VERIFY_XCODE=0` 显式跳过以不使用默认 DerivedData；上述八次独立 Demo Xcode 构建单独验证 iOS 编译，不声明运行态。无提交、安装、发布或外部工程操作。

## v0.2.48 · 正式发布回执

- Tag 指向 `7c4ed9c62d5cd370f8357e657dd2b1e38e221614`，含 CAS 与公开 skills 提交 `16f46d45`。[主线 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/45867000871)、[标签 CI](https://github.com/NeptuneKit/TritonKit/actions/runs/45868554093) 和 [Release 与 Homebrew tap](https://github.com/NeptuneKit/TritonKit/actions/runs/45868554160) 均通过。`.github`、Demo 原源码、默认行为、`xcode test/run` 未改。
- 从公开下载地址重新取得 arm64 CLI（含 Web、Runner）、四个 public skills 和 checksum，核对 GitHub 元数据字节数、SHA-256、版本戳及 `xcode.build` schema。发布 CI 的匿名 arm64 资产门禁通过；本机完整匿名 API 查询受 403 限流，独立公开直链下载与 checksum 比对通过，不将两者混报。
- Homebrew tap `440faff8adfe8f0530cd4da00e57e5f52262e0fe`；本机由 0.2.47 升级至 0.2.48，`brew test` 通过，安装后二进制与正式包 SHA-256 相同。仓库外 packaged Web 的 HTML/JS/CSS 均为 200、host targets 为 `readonly=true`，完整点按 DTO 返回 `405/web_host_input_readonly`。真实浏览器渲染和后续观察均无 console error；停止本轮隔离 Web 实例，未操作设备。
- 正式二进制单独通过仓库内 Demo 八次构建及四个拒绝负例：跨路径 175 hit / 0 miss，受控改动 172 hit / 3 miss；两路并发写入后分别重放各自键及产物标记。证据留在本机 `.triton/releases/v0.2.48/`。

## BDD 与门槛

1. **跨路径复用：** Given 冻结的同一提交与本地包、Xcode 与 SDK；When 在预热后以另一源码路径、空 DerivedData 构建；Then 两次产物正确，未修改的 Demo Swift 任务至少有可归因到预热键的真实 `replay cache hit`，按 App、本地包与 SDK/未署名分开统计，不能只看整体命中率和耗时。
2. **源码改动失效：** Given 已验证的命中基线；When 在临时副本改变一个可识别的 App Swift 输入并使用空 DerivedData；Then 受控任务不会重放原键，构建产物包含受控输入，仍可观察不受影响的复用（若编译粒度允许）。
3. **并发共用 CAS：** Given 两个不同源码路径和空 DerivedData；When 同时启动两个构建指向同一个 CAS；Then 观测实际执行时间重叠，两次命令均成功且产物身份正确，无 CAS 损坏、写入争用失败或 DerivedData 混用。
4. **CLI 契约：** Given Xcode 27.1 或更新的 27.x、普通 iOS Simulator build、明确的 source/DerivedData/CAS 边界；When `--compilation-cache shared`；Then 仅本次注入真实构建设置，机器可读 `compilationCache` 与 DerivedData 的 `reuseVerification` 独立，缺日志不报 0。未启用时无版本检查、无注入，也不新增字段。对于不支持的版本/目标、`--for-testing`、手动缓存 setting 冲突、外部覆盖配置或重叠路径，执行前稳定拒绝。不改默认、CI、`test` 或 `run`。
