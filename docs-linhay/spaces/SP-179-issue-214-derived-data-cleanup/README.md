# SP-179 — Issue 214 DerivedData cleanup

## 范围
新增 `triton xcode derived-data inspect` 与 `cleanup`。inspect 只读统计；cleanup 默认 dry-run，只有 `--confirm` 才允许删除。

## 验收
- 输出 totalBytes、fileCount、breakdown、mtime、errors、symlinkSkipped。
- root canonical 校验，拒绝 symlink、路径逃逸、权限错误及竞态。
- 默认保留 repo-local `.triton/DerivedData`，支持显式全局 DerivedData root。

## 验证
由实现代理运行 CLI focused tests；不得提交、推送或发布。
