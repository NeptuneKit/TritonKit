# SP-132 Testrec Import Seam

> 状态：已完成（P0 offline contract seam；本地 checkpoint）
>
> Branch：`feat/SP-132-testrec-import-seam`
>
> Worktree：`../TritonKit-worktrees/SP-132-testrec-import-seam/`
>
> 基线：`feat/SP-131-ios-simulator-canonical-proof@6f700b13`

## 目标

实现 Hybrid 路线的第一个离线导入切片：把已存在的 `.tritontestcase` **compiled contract** 转成可由既有 `test validate` 接受的 `.tritontest.yaml`。真实动作、target resolve、observation、evidence 与最终 verdict 仍只属于 `test run`；本 slice 不启动 imported plan 的设备执行。

稳定入口暂定为：

```text
triton test import <case.tritontestcase> \
  --output <plan.tritontest.yaml> \
  --bundle-id <bundle-id> \
  --device-platform ios-simulator \
  --json \
  [--expect-compiled-digest <fnv1a64>]
```

`--bundle-id` 和 `--device-platform ios-simulator` 都是 fail-closed 的必要输入。v1 `.tritontestcase` manifest 不携带可运行 App 的 bundle identity；而泛化的 `sourcePlatform: ios` 只代表平台族，不能被 importer 静默重标为 Simulator。可选 `--expect-compiled-digest` 只校验既有 `compiled-contract.json` 的 FNV-1a 稳定身份，不是加密签名。

## 边界

- 只读既有 `manifest.json`、`contract-capabilities.json` 与 `compiled-contract.json`；三者必须是 canonical source-root 内的 regular file，不能经 symlink 指向包外。`--output` 同样 canonicalize，且必须位于 source package 外；不重新录制、不从 raw stream 重编译、不执行 `testrec`，不创建第二 executor。
- P0 仅支持一一映射到现有 test primitive 的 `tap(text)`、`assert(text)` 与 `screenshot`，并在输出前加入显式 `launch`。`type/paste`（缺少可保真的 focus/selector 语义）、scroll/swipe/wait/open-url/evidence、未知 action、弱/空/敏感 target、缺 page evidence 都 fail closed。
- source platform 只接受 `ios` 或 `ios-simulator`，但输出 target 必须由调用者明确指定为 `ios-simulator`；Android、Harmony、真机、Web/Wails、HTTP route、workspace 编排、网络策略与 `testrec local-simulated` 迁移提示均不在本 slice。
- `redactionStatus: pending` 不是 blocker：现有 case 没有独立 review 状态流。任何 concrete `qualityFindings`（尤其 `contract.redaction`/privacy）、截断、capability 或 identity 异常才是 blocker；不得把 pending 误报为“已审查”。
- output response、YAML、validator 与 normalized plan 都保留 privacy-safe provenance：importer version、source kind/platform 与 package-relative `compiled-contract.json` FNV ref；success response 只发布 source/output filename 和 command template，错误不回显原始 action/sourcePath/底层路径。现有 `test run` 序列化 normalized plan 时会自然带上该字段；P0 仅以 fake executor 覆盖这条保留链，不产生设备 evidence。
- 生成 YAML 先内存 validate，再写同目录 temporary file 并以 no-clobber hard-link publish；并发或既有 output 都不会被覆盖，失败不留下 plan。
- 不读取、修改、合入或清理 #164 dirty evidence WIP；不 push、PR、merge、tag、release、关闭 issue 或删除 worktree/branch。

## BDD / TDD

1. **确定性成功导入**
   - Given sourcePlatform 为 `ios` 或 `ios-simulator`、带 page evidence、没有 quality finding 的 compiled case，其中只含 `tap(AX text)` 与 `assert(AX text)`。
   - When 显式传入 bundle ID、`--device-platform ios-simulator` 并 import 到两个新 output path。
   - Then 两份 YAML 字节一致，含 `launch`、精确 AX text tap/assert，response 含 contract ref/digest，且各自 `test validate` 成功；全程不连接 runtime。

2. **安全失败**
   - Given 缺 `compiled-contract.json`、存在 concrete redaction/privacy quality finding、已编译 contract 与 manifest identity 不一致、缺 page evidence、target platform 不是 `ios-simulator`，或存在不可映射 action。
   - When import。
   - Then 返回单一 `{ ok:false, error:{ type:"validation_error", code, path, message } }`，包括遗漏必填参数时的 `--json`；不写 output plan、不连接 device，也不把动作降级成 sleep / coordinate / simulated pass。

3. **可审计保留**
   - Given 成功导入的 YAML。
   - When 独立 validate，或由 fake executor 调用既有 `test run` runtime。
   - Then typed provenance 不被 validator 丢弃，并进入 run 写出的 `normalized-plan.json`；不需要新增 evidence writer。

4. **兼容边界**
   - Given 现有 `testrec inspect/compile/replay` contract。
   - Then import 只复用其读取模型与 digest，不删除或改写 case、compiled contract、HTTP route、replay/matrix surface；`testrec` 仍是 compatibility/import layer。

## 验收与停止条件

- TDD 已先以缺 `importTritonTestCase` 的编译失败建立 red，再实现最小 importer，并在只读审查后补齐 source/output containment、symlink、敏感 numeric target、digest、no-clobber 与 omission-envelope 回归。`TestImportTests` 11/11、`TestValidationTests` 13/13、`TestCreateFromSessionTests` 2/2、`TestRunExecutionTests` 9/9、`FailureDiagnosticsTests` 13/13 与 `SchemaFactSourceCapabilityTests` 22/22 通过；CLI help/schema 也已由编译产物读取确认。
- `TestRecorderContractTests` 现为 38/39：唯一既有 replay local-device 断言在当前环境得到 `target_not_found`，而历史期望为 `target_capability_missing`，不经过 importer 改动路径。`SchemaFactSourceContractTests` 仍有 6 个既有 device/app-console schema failure；import 的 output/failure taxonomy 相关断言通过。两类既有失败不在本 P0 扩修范围，已记录为集成风险。
- `TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local` 已通过：根 SwiftPM 231/231、release CLI build/smoke、Harmony host smoke、iOS runtime observe smoke、docs 与 whitespace 均通过；Xcode Simulator build 按纯离线 P0 边界显式跳过。P0 不以 Simulator/live run 替代纯导入合同测试。
- 若编译产物无法无损表达最小动作（尤其 target、focus、platform 或 provenance），停在 `unmapped_contract_feature` 并写回该差异；不得扩写 testrec executor 或隐式补值。

## 后续

P1 才能在专用 iOS Simulator 上执行一条 imported plan，复用 SP-131 的 Triton-first target/runtime/evidence 方法，并验证最终 evidence 读取的 normalized plan provenance。可靠性样本、workspace 编排和第二平台另建有限 space。
