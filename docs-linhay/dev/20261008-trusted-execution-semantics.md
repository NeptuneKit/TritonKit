# TritonKit 多端统一语义契约

> 2026-10-08；SP-182设计补充，用户明确要求支持的多端在语义上统一。本文是proposal，不是已发布schema、已实现API或已通过的跨平台能力矩阵。上位设计：[可信执行系统ADR](20261008-trusted-execution-system-architecture.md)。

## 1. 核心裁决

**统一语义，不统一底层实现，也不退化成各平台最小公共命令集。**

平台轴：iOS Simulator / Android Emulator / Harmony Emulator；embedded、host、WebView是执行或观察来源，不是另一种产品语义。访问轴：CLI / HTTP / future MCP；Web/Wails是只读投影。两条轴共同消费一份semantic schema、compiler与result reducer，不各自定义同名动作的含义。

相同意图须有相同前置条件、效果定义、完成判据和失败含义；实际可支持范围可不同。某端不能满足契约就返回unsupported/unknown，不偷偷改成较弱的动作后返回同样verified。

**两条一等操作路径：agent自由组合单点命令；agent调用TritonKit封装高级命令。** 共享语义和ExecutionCore，不要求单点先创建Run。单点返回所请求Operation的事实，高级命令通过WorkflowEngine聚合Run结果；不因入口层级不同改变同一effect/verification含义，也不把高级命令作为唯一可信来源。

## 2. 语义由内核拥有，平台由adapter解释

```text
任务意图 / 声明条件
        ↓
规范化语义IR（version + effect + target + constraints + postcondition）
        ↓
共同compiler / resolver / verification / outcome
        ↓
backend实现与能力证明
        ↓
事实receipt + observation + limitations
```

semantic spec规定“意味着什么”；backend manifest声明“在何种条件下做到”；probe确认“当前是否具备条件”；conformance suite验证“实现是否满足”。README声明、工具退出0或某类可加载都不能代替conformance。

同语义版本有破坏性含义变化必须升级，不用平台flag让同一verb暗中换义。旧命令的导入要显式映射旧语义，不能把旧tap/type自动升级为更强语义承诺。

## 3. 三层语义，不混用业务目标与设备事件

| 层 | 例子 | 保证边界 |
| --- | --- | --- |
| 任务条件 | “进入目标页面”“字段最终值为V” | 条件由用户/App profile定义，可验证才成立；不内置跨App业务猜测 |
| 交互意图 | activate、set-value、focus、reveal、select、set-state | 描述目标效果，不默认规定平台事件实现；要求的事件/信任/scope是显式约束 |
| 设备原语 | tap、swipe、key、pointer | 描述输入；提交成功不证明控件激活或任务成功 |

旧act名称无需立即全部改名；归一化IR区分上述层。`tap`只有在显式selector/effect/expectations后才可能编译为activate，不依靠字符串名猜。

## 4. 首期语义字典（候选，需fixtures与真实验收）

| 意图/条件 | 统一效果与完成判据 | 禁止伪等价 |
| --- | --- | --- |
| observe | 指定目标/scope/来源与coverage的观察，字段unknown保留 | 空树不是空页面；runtime app-layer不是整屏；confidence不是事实 |
| activate | 唯一语义目标的激活请求；最终由声明的postcondition验收 | click/tap、AX activate、JS click不自动同等；physical/trusted input要求无法满足时拒绝 |
| focus | 指定控件获得焦点，以fresh focus evidence确认 | 键盘弹出不是指定控件已focus；不可读focus为inconclusive |
| set-value | 控件最终值符合声明的Unicode比较规则，selection/事件义务显式 | type/paste/setText不同；键盘事件/IME要求不能用直接赋值替代；不盲追加后假set |
| reveal | 指定目标进入声明的可见/可操作范围，复观测验证 | 固定swipe次数不是revealed；存在于树不等于可见、不等于可点击 |
| select / set-state | 控件达到明确值，不是无条件toggle | toggle不幂等；未知当前值不能默认为false；read-back不支持不假verified |
| launch | 指定App实例启动；running、foreground、runtime-ready、business-ready分别评估 | 进程存在不等于前台，更不等于业务可操作 |
| wait / verify | 在deadline内对相同target/app作用域评估声明条件 | 某轮无数据不能证明not-exists；readiness/timeout/transport失败不可混成一个false |
| capture | 按声明scope/fidelity捕获artifact与来源/敏感性 | runtime截图不自动替代整屏；manifest存在不等于业务成功 |

动作声明可附加 `scope`、`requiredInputSemantics`、`requiredEvents`、`verificationRequirement`。这些是proposal字段名，不能作为现有CLI选项示例。默认不能扩大到system scope，也不能隐式请求真机或权限。

## 5. 目标与观察的共同语义

### 5.1 身份与selector

- device identity / app identity / app instance / runtime instance分开；OID、resourceId、DOM节点ID保留source且有有效期。
- selector可包含semantic key、规范role、文本匹配规则、区域/层级约束；多命中返回ambiguous，不平台性选择第一个。
- 同case跨端用明确App profile映射semantic key到平台identifier，不假定不同App的同名label是同一业务对象。
- 文本label/contentDescription/title/value分别保留，不平铺为一个text后失去匹配含义。Unicode normalization/大小写/locale策略必须声明；不能为“匹配成功”自动改用宽松contains。

### 5.2 观察与coverage

当前 [ObserveNodeOutput](../../Sources/TritonKitCLI/CLIObservationModels.swift#L19-L33) 已有可选状态、source/confidence/candidateOnly；统一语义应保留未知，而非补默认false。

新观察需要coverage（app/system/WebView/viewport/完整性）、freshness、generation、geometry、来源。`visible`、`enabled`、`focused`为known true/known false/unknown；role映射需字典，平台原始属性置于typed extensions，不泄漏为公共必需字段。

屏幕坐标必须注明logical point/pixel/normalized、screen ID、方向与转换依据；统一服务负责转换校验，不让客户端知道每个平台缩放规则。

负断言 `not-exists` 要求fresh、scope正确且对目标匹配有足够coverage。树不完整/服务失败/只看viewport时，不能从未发现推导不存在。visual推断与semantic evidence分别标记；两者都可贡献验证，但不能隐式提升证据等级。

敏感字段值可能不可读；不采集密码作为通用证据。可在获授权runtime内求值并只返回redacted verdict/必要元数据；无可靠验证源时inconclusive，不用插入长度猜内容正确。

## 6. 能力差异也是统一契约的一部分

把“available: Bool”扩展为语义能力描述，而不是删除平台高级能力。现有 [host capability模型](../../Sources/TritonKitShared/TKHostStrongControlModels.swift#L3-L13) 可兼容导入，但不足以单独证明语义等价。

建议descriptor内容：semantic ID/version、support（supported/conditional/unsupported/unknown）、scope、target kind、前提、可实现effects、input event语义、read-back/verification来源、幂等边界、恢复支持、限制与probe refs。

每次编译比较requested guarantees与provided guarantees：

- 满足全部required：可选择该backend。
- 只有conditional：先验证客观前提；失败typed blocked/unsupported。
- 比请求弱：返回semantic_gap，说明缺项与候选方案，不自动发送。
- 用户明确接受弱语义：生成新spec revision并重新授权/验证；原请求不被悄悄改写。
- unavailable/unknown：分别表达当前不可用与没有充分事实，不互相猜。

例如：要求真实键盘输入，但后端仅setText；要求system scope，但后端仅embedded app；要求完整absence，但仅viewport树。这些都是语义差距，不是参数错误或一个通用tool failure。

允许平台高级功能在typed extensions中存在；非通用意图明确namespace/version。不能为了统一削掉高级能力，也不能把平台扩展伪装成所有端支持的标准能力。

## 7. 统一结果与错误，而非统一原始日志

复用上位ADR的execution/verification/recovery/evidence四维，backend结果不直接决定outcome。所有入口对同一个Run返回同一判定；CLI/HTTP只转换transport status/格式，不改变业务语义。

建议canonical reason：ambiguous-target、stale-observation、unsupported-effect、semantic-gap、precondition-unmet、delivery-unknown、postcondition-failed、verification-inconclusive、evidence-incomplete。具体machine code在实施schema登记，现有稳定错误继续兼容投影。

保留backend code、工具版本、redacted sourceCommands和probe details作为诊断字段；不让上层必须识别adb/simctl/hdc错误文本才能决定成功。capture.partial不能投影成business pass，编译成功不能投影成执行verified。

## 8. 跨端conformance：统一必须能被测试推翻

建立一份semantic fixture suite，iOS/Android/Harmony与不同入口分别运行相同条件表。不是要求三端raw JSON逐字相同，而是要求required effects、后置条件、错误类别、outcome、unsupported边界一致。忽略测试ID/时间戳/原始日志，但不能忽略scope、freshness、输入事件要求和验证来源限制。

BDD候选：

1. 同一semantic key存在两个候选：三端都ambiguous，零dispatch。
2. set-value要求replace且Unicode含组合字符：不能某端append、某端paste后统一报通过；按比较规则read-back。
3. required keyboard/IME事件与backend direct setter不符：三端统一semantic_gap，不能静默“近似”。
4. 空/partial/stale树与not-exists：均inconclusive，不把捕获失败当不存在。
5. action receipt成功但postcondition未通过：统一非verified；模型done不得改变结果。
6. normalized/logical/pixel映射经过方向/缩放变换：选择同语义目标；geometry变化使旧引用失效。
7. execution已提交但timeout：所有backend先reconcile，不切策略重复发送。
8. unsupported高级功能：明确能力缺项，基础能力不受影响；不能以其它平台成功覆盖该端缺项。
9. 同一Run经CLI/HTTP读取：business outcome一致；HTTP accepted和CLI progress不是业务success。
10. secure value不能公开读回：不记录明文；缺少可靠verifier保持inconclusive。

先fake各端adapter与property/metamorphic测试，再用受控App在真实平台验证效果。完成一个平台的测试不代表多端统一完成；逐端登记支持矩阵/限制/skip。

## 9. 对SP-182实施路线的调整

M0先定义semantic vocabulary/IR、字段unknown与能力匹配、共同verifier/reducer，再进入“一动作三入口”。M1不仅验证同入口结果，还用至少两种fake平台实现证明效应/错误一致。M3接第二真实平台时跑共享conformance，并把平台routing消融到registry/adapter。

本轮只补设计，不宣称以上契约已实现。公共skill/CLI示例待schema实现后更新，不能把proposal动作名当现有命令。
