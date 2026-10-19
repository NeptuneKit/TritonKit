# SP-210 — Simulator AX 几何可信度

## 范围与状态

- 2026-10-17参考增量评估后立项，状态：实现与 focused 验证通过，待主控整合。影响层为 macOS CLI host Simulator AX；不改 embedded SDK、Web/Wails、真机或远端产品面。
- 实际产品基线为 `main@d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec`。主目录当前另在 `codex/wip-main-before-sp209@0a0aec02`，不能将其当作main或整分支合并；相关AX实现blob与main一致。
- branch：`feat/SP-210-simulator-ax-geometry`；worktree：`../TritonKit-worktrees/SP-210-simulator-ax-geometry/`。本期主控：[SP-211](../SP-211-reference-adoption-integration/README.md)。
- 用户已授权参考评估可纳入项直接开发、独立验证、必要本地提交与本地main合并；无推送/发布、安装依赖、第三方执行或设备操作授权。

## 固定来源与本地缺口

参考 [ai-phone 452e7d7](https://github.com/dongxinsuperman/ai-phone/commit/452e7d77326f9fc0e5b003ecbf6cec5fc499e4bf) 的 [实例LCD几何与无效值拒绝](https://github.com/dongxinsuperman/ai-phone/blob/452e7d77326f9fc0e5b003ecbf6cec5fc499e4bf/backend/ai_phone/agent/drivers/simctl.py)。该机制源码、测试和该revision MIT许可证已完整读取，原文证据位于 `.build/reference-monitor/20261017/agents-revyl/dongxinsuperman__ai-phone/geometry-*`；整个仓库的完整增量检查状态另见SP-207，不以单机制完整性推进仓库检查点。

本地 `Sources/TritonKitCLI/CLIHostSimulatorAXDriver.swift` 的 `devicePointSize` 在缺少机型尺寸时静默使用393×852、缺scale时默认3，且未拒绝NaN/Infinity/负尺寸；`AXFrameTransform` 在无效几何时直接透传输入坐标。读不到可信几何不应包装成可用坐标。现有SimulatorAXBudget等测试没有直接证明这些边界。SP-196 resize gate处理当前resize会话与display路由，不能代替本切片的基础几何校验。

采用范围仅为独立实现可信几何校验、消除虚构fallback、稳定机器可读失败及离线回归。不复制Python代码，不新增依赖；引用MIT来源，如复制片段必须保留相应许可通知。上游性能未在本地验证。

## BDD与验收

- Given完整合法pixel尺寸与scale，When构建AX坐标转换，Then保留当前合法设备行为；至少覆盖不同机型比例与round-trip。
- Given缺尺寸、缺scale、零/负数、NaN/Infinity或非法root frame（包含非finite origin），When需要坐标映射，Then返回明确且单一的机器可读失败，不输出猜测的可信frame、不提交坐标动作。缺失KVC属性须先安全探测，不能把Swift optional当作能捕获Objective-C未知key异常的保障。
- Given可不依赖坐标的语义行为，When收紧几何校验，Then明确其适用边界，避免无关接口回归；错误进入现有CLI映射与schema/hint链路。
- Given采集deadline耗尽，When校验，Then保留预算/partial语义，不靠额外无界探测延长请求。
- 本期不引入真实 `simctl io enumerate` 调用或缓存，不自动操作Simulator。live LCD fallback、旋转/resize兼容和旧/新Xcode真实验证作为后续独立评估；不以离线fixture宣称真实设备命中。

## 文件面与交付

执行会话拥有 `CLIHostSimulatorAXDriver.swift`、必要新建 `CLIHostSimulatorAXGeometry*.swift`、对应CLI测试与本space证据；确需修改现有错误/schema映射时列入候选清单，不跨到其他业务。先失败测试，再最小实现、重构、focused/full CLI测试、根包与适用local门禁；不安装缺失依赖、不操作设备。测试使用独立scratch，避免与主控冲突。

新执行/主控会话显式 `model="gpt-6.1-sol"`，不回退；你不是独自工作，不回滚别人改动。执行提交仅含本切片，冻结候选/日志/未验收边界交主控。主控负责统一索引/memory和本地main集成；执行会话不推送、不发布、不合main。

## 2026-10-17 分派结果

独立branch/worktree创建成功；`create_thread` 显式指定 `model="gpt-6.1-sol"` 后返回 `could not validate model`，未产生thread ID。保留待重试，不省略模型、不回退、不冒称开发或主控已启动。下一次先核对登记并补缺会话，不重复建space/worktree。

## 2026-10-19 实现切片

- 消除393×852和scale=3猜测；deviceType/mainScreenSize/mainScreenScale读取前检查getter，NSValue校验CGSize类型后取值。缺失、零、负、非finite和计算溢出返回`ios_host_ax_geometry_unavailable`，接入原有HostSimulatorAXError detail/hint映射。
- AXFrameTransform初始化校验root origin/size和point size；map/unmap拒绝非finite、负child size及overflow，press在native action前完成校验。允许child零尺寸，保留真实不可见节点；root必须正尺寸。
- geometry读取逐阶段使用原collector deadline；过期返回nil并保留deadline partial，不继续读取root、不增加探测。现有语义press也返回含frame DTO，故与树/坐标命令共同要求可信几何；未引入无frame的新语义产品契约。
- 测试：SimulatorAXGeometryTests；证据目录`.build/sp210-evidence/`。原版AXFrameTransform独立提取后先红（red-transform.log，非法root透传断言exit133），CLI首次构建期间源文件变化导致red.log编译失败，该日志不作为行为红证据。
- 未执行真实Simulator/Xcode设备验收，无设备动作、依赖安装或远端写入；schema整合、完整CLI/根包/local门禁及索引memory由主控执行。
- 自动沉淀检查：本期可复用边界为Objective-C未知KVC不能依靠Swift optional/do-catch；已落实在本space与geometry reader注释，公共skill升级由主控统一处理。

### Focused 验证冻结

`swift test --package-path CLI --scratch-path .build/sp210-scratch --no-parallel --filter 'SimulatorAXGeometryTests|SimulatorAXBudgetTests'` 最终候选通过：10项geometry XCTest、6项budget Swift Testing，0失败，日志`.build/sp210-evidence/green-final.log`。`git diff --check`通过。

真实press使用`submitValidatedPress`生产编排边界；离线注入context/selected frame几何错误时native submit计数0，合法选择计数1。`cliErrorDetail → TKCLIErrorResponse → encodeJSON`断言单一JSON envelope的`ok=false`和稳定error code/hint/nextAction；这是映射/编码证明，不是真实CLI进程失败或设备动作证明。
