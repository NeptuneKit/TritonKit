# SP-231 · Android UIAutomator 当前树新鲜度

- Issue：[GitHub #229](https://github.com/NeptuneKit/TritonKit/issues/229)
- 影响层：CLI Android host observation，以及复用它的坐标目标解析；不改变 embedded bridge。
- 分支：`feat/SP-231-issue-229-android-observe-stale-tree`
- Worktree：`../TritonKit-worktrees/SP-231-issue-229-android-observe-stale-tree`
- 状态：候选已冻结，等待主控联合 native 构建验证；未整合/发布/远端关闭。

## BDD 与验收

1. Given 旧 `/sdcard/window_dump.xml` 存在，When 新 dump 退出 0 但含 `ERROR: null root node`，Then 返回 `hierarchy_unavailable`，不读取旧文件、不产生新的成功 capturedAt/坐标。
2. Given 连续两次 observation/action resolution，When 每次 dump，Then 使用不同 UUID 文件并核对成功回执的精确路径；每次只清理自己路径。
3. Given dump 未确认路径或 XML 缺失、为空、截断、无节点、不可解析，Then 拒绝当前树；cleanup 失败不掩盖原失败。
4. Given 有效 dump/read，Then 正常解析节点、写本地 artifact，并保留 capture/read/cleanup 命令来源；collection budget 行为继续保持。

## 实现边界

`captureAndroidHierarchy` 统一观察和坐标解析的 fresh capture 逻辑。退出码只是必要条件；同时验证 dump 文本、唯一文件读取和可用节点。不会把旧树标记成当前，也不会基于失败输出自动重试手势。远端 cleanup 为 best effort，只作用于本次 UUID 文件；其命令记录表示尝试，不证明删除成功。

## 验证

见 [20261028-validation](plans/20261028-validation.md)。真实 Android Emulator null-root 场景未执行；fixture 不替代实际设备验收。
