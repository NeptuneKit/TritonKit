# GitHub Issue #163：Xcode 26.6 xcresult Array Decoding

> 状态：执行
>
> GitHub：[NeptuneKit/TritonKit#163](https://github.com/NeptuneKit/TritonKit/issues/163)
>
> Branch：`feat/20260722-issue-163-xcresult-array-decoding`
>
> Worktree：`../TritonKit-worktrees/20260722-issue-163-xcresult-array-decoding/`

`docs-linhay/scripts/create-space.sh` 当前不存在，因此本 space 按固定模板直接建立并同步总索引。

## 背景

Xcode 26.6 `xcresulttool get test-results tests` 把 `devicesAndConfigurations` 输出为 array，而当前 decoder 只接受 dictionary，导致有效 `.xcresult` 被映射为 `xcresult_parse_failed`。

## 范围

- decoder 同时接受历史 dictionary 与 Xcode 26.6 array 两种 shape。
- 将两种输入规范化为同一内部 test/failure summary，不把兼容分支泄漏到 public contract。
- 对真正未知或缺失字段继续返回明确 parse error，不用宽泛 `Any` 吞掉结构问题。
- 增加脱敏 compact JSON fixture；不提交私有 `.xcresult` bundle。

## BDD 场景

### 场景 1：Xcode 26.6 array 可解码

- Given `devicesAndConfigurations` 为 array 的 test-results JSON
- When 解析 summary/failures
- Then 返回正常计数与失败列表
- And 不返回 `xcresult_parse_failed`

### 场景 2：旧 dictionary 保持兼容

- Given 历史 dictionary shape fixture
- When 使用同一 decoder
- Then 输出与修改前一致

### 场景 3：无效 shape 仍明确失败

- Given `devicesAndConfigurations` 为非 array/dictionary 或元素缺少必要结构
- When 解析
- Then 返回稳定 parse failure 与诊断
- And 不崩溃、不生成伪造测试结果

## 验收门禁

- 先补 Xcode 26.6 array fixture 失败测试并确认红灯。
- focused parser/CLI tests、nested CLI full tests、根包 `swift test`、release build 与 docs gate 通过。
- 使用 `triton xcresult failures` 复验可用的本地脱敏 bundle/fixture；schema 与公开输出形状保持稳定。
- 同步 Xcode takeover 文档、相关 public skills、memory 与 space 索引。

## 停止条件

三个场景、自动化验证、main 集成与线上 CI 全部满足后评论并关闭 #163。
