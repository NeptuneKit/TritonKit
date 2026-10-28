# #214 · 用户授权的两处缓存删除

## 范围与授权

2026-10-28 用户在只读调查完成后明确要求“提交并推送调查文档，把脱敏结论同步到 #214，未查明的问题保留，缓存可以删除”。该新授权允许本次人工删除已调查的 A/B 两处 `.triton/DerivedData`；不扩展到用户级 Xcode DerivedData、其它缓存或取消的通用自动清理功能。

本记录接替只读阶段“未删除”的当前状态；[只读调查](20261028-cache-investigation.md)与[原占用快照](20261028-cache-inventory.json)保留历史证据。该批文档提交到 `codex/issue-214-cache-investigation`；不修改主仓既有 WIP。

## 执行与复核

- 删除前两处全部 41,277 个普通文件的 inode、大小、mtime/ctime、分配块与调查清单一致；目录的 canonical path、root inode、父目录 inode 均核对。
- `triton xcode status --json` 返回 ok=true / active=false；补充进程精确名称核对未发现 Xcode/xcodebuild/XCBuildService/编译/测试活动。路径包含 xcodebuildmcp 的 node-runtime 服务不是实际构建进程，未停止它们。
- `lsof -nP +D <A/B>` 各返回 1、stdout/stderr 均为空，即未观测到打开的文件句柄。检查只代表该时间窗口，不证明未来不会启动构建。
- 在持有父目录 fd 的情况下，分别将精确目标改为同父目录内的专用暂存名称；再核对 inode、完整普通文件清单、构建进程和打开句柄，随后使用支持 fd/symlink 防护的 Python `shutil.rmtree(..., dir_fd=...)` 逐个删除。没有调用 Triton cleanup/confirm，没有跟随内部软链接删除外部目标。
- 两个原路径与暂存路径均已不存在；两个 `.triton` 父目录仍存在，同级其它条目集合未变。主工作区 Git WIP 清单保持一致。原始调查报告/摘要保存在独立集成 worktree，不随缓存删除。

删除前分配块合计 **2,093,416,448 bytes（约 1.95 GiB）**。本次没有测量 APFS 独占 extent、快照或全盘空闲量变化，因此不声明实际释放了同等物理空间。下次相关构建可能重新下载依赖和生成编译/索引缓存。

## 未查明项仍保留

1. 原 issue 的约 18.66 GB 两处大目录仍未定位；不能将本次 A/B 删除视为原现场已处理。
2. 原始 Triton 版本、构建调用和 cwd 尚不明确；旧相对路径机制只是有源码依据的可能解释。
3. 不能从相同内容、mtime 或分配块推断缓存泄漏、最后使用时间或可回收独占物理字节。

#214 保持 OPEN。后续取得原目录或历史构建证据时继续调查；本次用户授权不恢复通用自动删除实现，不代表 Triton 已通过并发删除安全验收。

## 证据与验证

[脱敏删除结果](20261028-authorized-cache-deletion.json)记录起止 UTC 时间、逐根删除结果与本地原始证据 SHA-256。私有路径、原始日志和项目身份未上传。无产品代码变动，不启动构建或设备；文档与脱敏检查通过后提交/推送并同步 issue。

本地验证结果：`verify.sh --ci-docs`、`check-docs.sh`、`git diff --check`、`git diff --cached --check`、脱敏与 JSON 解析检查均通过。
