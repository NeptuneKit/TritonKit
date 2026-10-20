# SP-218 · Issue 222 Device Hub host input

- 状态：已清除全部 Baguette 运行依赖与兼容层，CLI/Web/根包及 Release 验证通过；文档全局编号门禁已在本地 main 补齐 SP-214～217 后通过。已合入本地 main（merge commit `c2f4bdd1`，收口文档 `ec595020`/`af91bf80`）；未推送、未发布。
- Issue：[222](https://github.com/NeptuneKit/TritonKit/issues/222)，含 [swipe 追加评论](https://github.com/NeptuneKit/TritonKit/issues/222#issuecomment-6285005107)。
- 影响层：CLI host adapter、doctor/schema、tap receipt；不新增 HTTP/Web/Wails 控制面。
- 分支：`feat/SP-218-issue-222-device-hub-input`；worktree：`../TritonKit-worktrees/SP-218-issue-222-device-hub-input/`；基线 main `f82872e2`。原工作区已有 SP-214～217 等资料，保持原样。

## 边界与决策

用户于本轮明确要求“不应该依赖外部 CLI，集成进我们项目”。当前 tap/swipe 改为 Triton 自有隔离子进程 + CoreSimulator/SimulatorKit/IOHID digitizer，生产路径不再查找/调用 Baguette、`TRITONKIT_BAGUETTE_BIN` 或 chrome。Apple Xcode 工具仍是既有 host 基础设施，无新增第三方包依赖。底层 recipe 参考并内置 tddworks/baguette@51f8ea2e0ee6d81523e8a85165f9abe0f899a9df；Apache-2.0 license、copyright 与改动说明随 CLI resource 分发。

不将输入接管扩大到 Device Hub 完整控制或自动 heal。`dtuhidd` 可能让 legacy transport ACK 却无投递；按 guest notify key 严格区分 inactive/attached/unknown，后两者发送前拒绝，不重启 SpringBoard、不杀业务 App。仅单一 Integrated primary portrait 屏，Resize/未知状态、多内屏、非主屏和旋转布局拒绝；不可从最大 framebuffer 猜测触控目标。预检不是状态变化原子锁。

显式 `--platform ios` 默认走 AX；隐式 Simulator 纯坐标走 HID。保留兼容并增加 `--hid-only`，只走内置 HID 或失败，不允许 AX/embedded/WebView 替代。

## BDD 与验收

1. Given tap/swipe，Then 调用当前 triton 内置 helper，精确绑定选中 Xcode/UUID，无第三方可执行文件或 chrome lookup；一个 helper/client/id 执行完整 down/move/up。
2. Given Device Hub attached、notify 查询未知、Resize active/unknown、未知/多内屏/非主屏/旋转几何，Then 发送前稳定 typed failure。失败日志/路径不公开、不重试/不自动 heal。
3. Given 内置 digitizer 构造，Then parent/finger 都必须成功，完整384-byte分配检查后补双target=0x32和清edge，单次send有界completion；超时保留delivery unknown。失败后只尝试释放一次，不重放原手势。
4. Given 显式 ios Simulator 坐标 tap + `--hid-only`，Then 只走内置 host HID；query/OID/selection/WebView/非 iOS/embedded target 与该 flag 冲突时在 I/O 前拒绝。
5. Given 默认显式 ios AX tap，Then receipt source/strategy/verification 明确 AX activation。HID transport completion 也不代表 guest delivery 或业务完成。
6. Then parser/递归 schema/doctor/CLI resource attribution 一致；多击/长按无已验收 host primitive 时明确不支持。
7. Given 安装环境没有 Baguette 或设置旧 override，Then 当前命令仍仅使用 triton 自身；通用 host runner 不识别旧 override、不隐式注入 framework，不存在旧外部 argv/NDJSON executor。有效生命周期/错误/Resize断言迁至 native helper；Web mock删除永远为空的外部进程字段，关闭 listener 不涉及外部进程。
8. 当前安装、发布和使用入口不再推荐 Baguette；源头版权/许可证、固定 SHA 与历史研究保留，不能把参考资料误作运行依赖。

## 前一切片验证（追加清理前）

- **通过**：最终 `swift test --package-path CLI --no-parallel`，1504 tests / 152 suites；失败前后的红绿及[实现契约](plans/20261020-native-hid-contract.md)已归档。原始日志 `/tmp/sp218-cli-full-3.log`。
- **通过**：local gate 中 SwiftPM 依赖边界、Debug 隔离、根包测试（Swift Testing 108+293及既有XCTest）、release CLI build、release CLI smoke、Harmony host smoke、iOS runtime observe smoke。日志 `/tmp/sp218-local-gate.log`。
- **通过**：release 候选实际 argv 的 malformed HID-only 返回单一 `validation_failed`/exit1；`schema act.tap` 含 flag、AX authority 与 native failure family。release resource 的 Apache LICENSE/NOTICE 与源文件逐字节一致；release bundle 既有分发脚本覆盖。
- **通过（只读拒绝边界）**：候选 debug/release `device hid-input --preflight-only` 均返回单一 `ios_host_hid_device_hub_attached`/exit1；设置不存在的 `TRITONKIT_BAGUETTE_BIN` 不影响该结果。候选 doctor 为 `hostChromeLayout=device-hub-only`、`compatible=true`、`chromeLookupVerified=false`、`inputDispatchVerified=false`、`available=false`、`inputSurfaceCode=ios_host_hid_device_hub_attached`。只读环境有4个booted Simulator，选定一个精确目标；没有发送手势、重启设备或替换运行中的 CLI/server。
- **通过**：CI scope classifier、经验索引/路由校验及28项经验夹具、version-stamping、public skill packaging（最终13项）、release automation contract、`git diff --check`。
- **失败，已归因**：`verify.sh --local` 在最后 Docs structure 步骤退出；`verify.sh --ci-docs` 同样在此退出；独立 `check-docs.sh` 复验相同。现有主目录未提交的SP-214～217资料不在本worktree的main基线，SP-218依法不可复用这些编号，现有checker又要求从SP-001物理连续。未复制无关WIP、未造placeholder、未放宽checker。整合本切片前须先整合权威SP-214～217登记，再对联合候选重跑两项门禁；当前不宣称全门禁绿色。
- **跳过**：`TRITON_VERIFY_XCODE=0` 跳过 iOS Simulator app build，本次仅 macOS CLI host/shared schema 改动，没有 UIKit runtime 修改；根包与依赖边界已验证。
- **未执行**：真实 guest 触控投递/业务后置验收、Device Hub active/inactive切换矩阵、完整 Device Hub adapter、多击/长按、双架构发布/安装/用户原机验收。当前active所有权正确拒绝，不以fixture或只读预检替代物理手势证据。

自动经验写回现有 host takeover skill、CLI契约、经验索引及 `docs-linhay/memory/2026-10-20.md`。新增运行依赖/锁文件/生成文件均无；无需提交构建产物或原始设备日志。

## 追加：全部依赖审计与清理

用户追加“还有什么依赖 Baguette 吗？都集成进来”。全量审计覆盖 Sources、CLI tests、Web dev bridge、manifest、Homebrew/CI/发布脚本和当前技能文档：无 tap/swipe 之外仍真正调用 Baguette 的生产能力，也无包/安装/发布依赖。残留为旧编译执行器、进程hook、resolver命名、测试及Web死字段；本切片全部移除，复用中性选中Xcode resolver与内置driver。旧host longPress/pinch/button/type并非已有Baguette生产能力，本次不从上游功能清单凭空扩大承诺。最终候选验证如下。


### 追加清理后的最终候选验证

- **通过**：完整 CLI 1501 tests / 152 suites（`/tmp/sp218-no-external-cli-tests.log`）；旧适配器专属断言退出，坐标、完整手势、释放/不重放、单一 envelope、Resize 与框架隔离的有效断言已迁移保留。独立源码复核未发现新增确定性缺陷。
- **通过**：同候选 CLI 明确绑定的 Web 78 tests、TypeScript/Vite 生产构建（`/tmp/sp218-no-external-web-tests-2.log`、`/tmp/sp218-no-external-web-build.log`）。首次缺本地 Vite 后按现有 lockfile 执行 npm ci，未改 manifest/lockfile。
- **通过**：local gate 中依赖边界、Debug 隔离、根包测试（Swift Testing 108+293 及既有 XCTest）、Release CLI 构建、Release CLI smoke、Harmony host smoke、iOS runtime observe smoke（`/tmp/sp218-no-external-local-gate.log`）。
- **通过**：最终 Release 在 PATH 仅含系统目录、旧 override 指向不存在路径时，只读 preflight 仍单一 `ios_host_hid_device_hub_attached` / exit1；doctor 为 compatible=true、inputDispatchVerified=false、Device Hub attached，未发送输入。非法 HID-only 混合 OID 为单一 validation_failed / exit1；schema 输出合法。旧 override、executor 和 resolver 的六个专属符号均不存在于 Release 二进制，Apache LICENSE/NOTICE 与源码资源逐字节一致。原始事实仅在忽略目录 `.build/sp218-facts/final-*`，不公开设备标识。
- **通过**：public skills packaging 13 项、经验路由/索引及 28 项夹具、CI scope classifier、`git diff --check`；生产 Sources/Web bridge/manifest/发布脚本无外部 Baguette 调用、旧 override 或兼容 hook。
- **通过**：补入权威 SP-214～217 README 与 `20261020-dispatch.json` 后，最终 `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 与 `--ci-docs` 均通过，docs 结构登记 218 个 space；未带入 `.build` 原始证据或其它 SP-207 WIP。
- **跳过/未执行**：iOS Simulator app build 使用 TRITON_VERIFY_XCODE=0；真实 guest 触控、Device Hub 所有权切换、双架构发布/安装与用户验收均未执行。本机 Device Hub 占用时正确拒绝，不能把此结果当作手势投递成功。独立 worktree 已提交并合入本地 main；未推送、未发布。
