# Agent Regression Capture And UI Assertions

## 背景

真实项目回归需要把“当前 UI 状态正确”表达成机器可读断言，而不是只依赖截图人工判断。dxyer 地区筛选回归里，AI 需要证明选择澳门、香港这类无二级地区后，右侧二级列表不再残留上一次选择的子项。

## 目标

在现有 `evidence` 和 `.tritonplan` 基础上补一层更面向 agent 的入口：

- `triton capture`：一站式采集回归证据包，默认包含 archive 和 geometry。
- `triton assert`：断言可见文本存在或不存在，并支持 role、count 和 bounds 过滤，降低重复文本歧义。

## BDD 场景

### 场景一：一站式采集回归证据

- Given App 已连接 TritonKit runtime
- When 执行 `triton capture --case job-search-area-filter --output /tmp/job-search-area-filter.tritonevidence --json`
- Then CLI 输出 evidence manifest
- And 默认 artifact 包含 `status/list/version/hierarchy/ax/screenshot/geometry/archive`
- And manifest 中每个 artifact 保留 freshness metadata

### 场景二：断言文本存在

- Given AX tree 中可见文本包含 `Macau`
- When 执行 `triton assert text-exists Macau --json`
- Then CLI 输出 `ok=true`
- And 输出 matches、count、sample 和 connection/cache freshness

### 场景三：断言文本不存在

- Given AX tree 中当前右侧区域不应出现 `Qinghai`
- When 执行 `triton assert text-not-exists Qinghai --within 180,120,190,500 --json`
- Then CLI 只在 bounds 内检查匹配
- And 若没有匹配，输出 `ok=true`

### 场景四：重复文本可用 count 收敛

- Given 同一 label 可能出现在 header、左侧列表和可点击 item 中
- When 执行 `triton assert text-exists Macau --count 1 --role text --json`
- Then CLI 只有匹配数量等于 1 时通过
- And 结果返回匹配 frame 与 source，便于 agent 解释断言依据

## 首期范围

- `capture` 作为 `evidence` 的回归友好别名，不新增证据包格式。
- `assert` 支持 `text-exists`、`text-not-exists`。
- `assert` 支持 `--role`、`--count`、`--min-count`、`--max-count`、`--within x,y,width,height`。
- `assert` 结果包含 freshness 字段，说明 AX 与 status 采集时的 target/cache 状态。

## 暂不做

- 不做 deep link launch；这属于 host-side app/simulator adapter。
- 不做通用 `list-empty --region <selector>` 语义；首期用 bounds + text/count 组合覆盖。
- 不处理 SpringBoard 或系统弹窗。
