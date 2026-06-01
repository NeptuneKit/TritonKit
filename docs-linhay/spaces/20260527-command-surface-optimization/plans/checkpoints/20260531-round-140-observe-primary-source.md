# Round 140: observe primary source

## 背景

继续减少 agent 在 observe 面上的二次聚合。当前 `observe.surface` 会返回 `sources[]`，但数组顺序并不总是等于优先级；例如 iOS `observe.current` 里，首个 source 可能是不可用的 `host-layout`，真正可用的事实源是后面的 `runtime-tree`。

## 本轮动作

1. 为 `ObserveOutput` 新增 `primarySource: ObserveSourceOutput?`。
2. 默认回填规则固定为：
   - 显式字段优先；
   - 否则按 canonical source 优先级选择：`runtime-tree`、`host-layout`、`webview-provider`；
   - 若三者都不可用，再回退到首个 available source；
   - 若仍没有 available source，再保守回退到 `sources.first`。
3. `observe.surface` schema output contract 同步暴露：
   - `primarySource`
   - `primarySource.name`
   - `primarySource.available`
   - `primarySource.reason`
   - `primarySource.artifact`
   - `primarySource.sourceCommands`
4. 新增 `ObservationOutputTests`，锁定 runtime-first、host-layout fallback 与显式 override 三种场景。

## 验证

1. `swift test --package-path CLI --filter ObservationOutputTests`
2. `swift test --package-path CLI --filter SchemaFactSourceTests`

## 结果

1. agent 读取 `observe.current/tree --json` 时，可以直接消费单值 `primarySource`，不再把 `sources[]` 的原始顺序误当成优先级。
2. `sources[]` 仍保留完整 provenance，方便后续下钻 unavailable reason、artifact path 和底层 source command。
3. 该字段只表达首选事实源，不替代完整 multi-source 边界，也不保证其他 source 无价值。

## 后续

继续检查 WebView list/current、target/host selection 或 route/assert 结果里，是否还存在类似“首选读取入口只藏在数组或嵌套对象里”的一跳事实缺口。
