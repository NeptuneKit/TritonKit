# #224 后续：Resize 查询根因与部分修复

## 请求与边界

用户要求继续处理#224。基线d966c559/v0.2.35，准备分支codex/issue-224-resize-query位于SP241集成worktree，原主目录未提交WIP隔离。影响CLI原生错误分类、doctor DTO/schema及hint；不降低unknown门禁，不改截图/录像/AX/HID的放行条件。

## 新事实

- 开始时没有Booted设备。本任务通过Triton创建专用iPhone17及iPad A16（iOS27.0），只操作这两个自有实例；其它项目设备只做只读查询。
- iPhone17启动初期doctor曾queryTimedOut，稳定后发布版v0.2.35已返回resize inactive/display primary，真实截图1206×2622成功。原生appResize是精确CoreDeviceError24004，没有错误包装层级缺陷。
- iPad A16启动稳定后持续queryFailed；原生JSON明确为CoreDeviceError1001，userInfo包含CapabilityFeatureIdentifier.string=resizableappmanagement完整标识、精确DeviceIdentifier及“能力不支持”描述。displays查询独立返回primary。旧发布现场iPad的只读查询也返回该1001，但不把当前shutdown状态等同旧现场。
- 因而iPad可复现原因是查询能力不支持，而不是笼统执行失败。该事实不证明inactive，更不能把primary framebuffer等同目标应用Resize场景；保持capture/input拒绝。原始iPhone/Xcode26.6未在本机复现，该工具链验收仍缺。

## 修复与反证

新增unknown原因unsupportedDevice，只有精确domain/code/feature/error目标以及完整原生argv回执匹配才识别；不搜索任意嵌套错误、不依赖本地化文本。新增可选simulatorDiagnostics.resize.hint并同步schema，说明重复同目标查询不能启用能力，改用已验证兼容目标/工具链或显式embedded App-only观察；不宣称host恢复。

真实iPad脱敏结构的新测试在旧实现red：3项中2项失败、4条断言，明确错误原因仍queryFailed且hint/schema缺失。最小实现后相关27项green；补typed failure及primary+unknown的screenshot/stream/AX/HID拒绝边界，完整验证结果待补。

## 仍未完成与后续

这只是已证实原因的分类/恢复指引修复，iPad主机截图和输入仍拒绝，#224已恢复OPEN并保留后续：获取原Xcode26.6/iPhone原生appResize文件JSON与退出码；若要显式主屏framebuffer能力，须独立定义显示绑定/结果语义/验收，不能暗中作为默认截图fallback。当前没有依据把unsupported当inactive，不替用户切换全局工具链或关闭问题。

原始设备JSON、日志与截图只在ignored `.build/issue-224-followup/`；公开测试/报告不含设备UDID、项目或主机私有路径。

## 真实候选验证与门禁修整

候选Debug CLI在自有iPhone17保持inactive/primary并截图1206×2622，已目视检查为真实主屏；自有iPad doctor准确unknown/unsupportedDevice并给hint，sim screenshot和sim swipe分别保留capture/input稳定拒绝码且不创建PNG。两个自有Simulator已通过Triton shutdown，保留关闭状态供后续，不删除其它设备。脱敏证据见[机器摘要](20261028-capability-evidence.json)。

CLI首轮1566项中一项既有FramebufferHelperTests缺临时脚本marker，单独重跑仍失败。其产品实现与发布candidate无差异；本机独立脚本探针首次观察到marker出现约0.506秒，后续两次为0.30/0.28秒，表明启动时序可变、原0.5秒预算脆弱；该探针不证明失败测试的具体底层延迟来源，也不能归因到Resize。测试原本验证超时不重启而非亚秒启动性能，改为2秒capture预算并用单调时钟至多5秒等待停止，继续严格断言marker恰好一个x、running=false和无frame。生产超时/执行器未改，首轮失败保留。

复跑：FramebufferHelperTests 11项通过，完整CLI1566项Swift Testing +94项XCTest通过，0失败；保留首轮失败。原始最低版本iPhone/Xcode26.6目前无可用安装，不能据本机27.1结果关闭兼容性问题。

本地总门禁`TRITON_VERIFY_XCODE=0 verify.sh --local`通过（native/jobs=2 wrapper），根包401+7、CLI release构建及smoke、docs/diff通过。可选裸Xcode测试未跑：本轮无embedded/UIKit/Runner源码变化，实际host Simulator复验已单列。文档/skill门禁完成后创建PR；未自动合并或发布。独立只读审计确认没有安全放行变化、typed零动作负例齐备、helper测试核心断言保持。

## 用户确认的验收范围与PR

用户追加“Xcode27.1测试就行了”。因此此前26.6缺失记录只是历史验证边界，不再是本轮阻塞，也不继续索要该环境；本次以已完成的Xcode27.1+iOS27.0自有iPhone17/iPad A16验证为准。iPad捕获/输入仍受安全拒绝，是保留#224 OPEN的功能限制。实现提交5296ec2e，[PR #236](https://github.com/NeptuneKit/TritonKit/pull/236)为部分修复，没有自动关闭关键词；未合并/发布。后续若要恢复不支持查询目标的主屏只读捕获，需要独立、显式的显示绑定契约，不能静默放宽unknown。
