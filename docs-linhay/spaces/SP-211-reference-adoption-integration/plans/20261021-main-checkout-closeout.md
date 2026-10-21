# 2026-10-21 主目录回归 main

## 范围与验收

本次只整合已存在的文档提交、修正当前状态和切换 Git 工作目录。产品代码相对 `a8f0b17f` 不变，发布 tag `v0.2.32` 保持原 SHA，不产生新发布。

- Given 原目录仍在旧 WIP 分支，When 用户要求主线收口，Then 源 tip 的内容逐文件核对并成为 main 祖先，原目录最终处于 main。
- Given 主线已发布且旧分支仍写未发布，When 合并文档，Then 保留较新的发布事实，只补缺失证据。
- Given 临时 worktree 含 ignored 证据，When 清理，Then 先保留完整目录及证据 hash，再正常移除，无强制清理。

## 提交裁决

源 tip `3ebb29fd91e9f55684d822626614aaf1c513573d` 相对共同祖先只修改文档。独有提交为 `5c876af1`（参考采用资料，绝大部分已由主线吸收）与 `3ebb29fd`（外部安装更新复核）。逐文件比对只有六个文件内容不同，差别为主线较新的发布/实现状态，以及源分支独有的外部安装复核段。

`merge-tree` 预检发现六个文档冲突。按文件保留主线较新状态，向当日 memory 补入源分支外部安装证据，形成正式 merge `d642e80c5b673efcf15d4a87dd8240af79207395`，双亲为 `a8f0b17f`、`3ebb29fd`。该 merge 相对首亲只有 memory 七行新增；不存在产品文件回退。

## 目录与归档

- 主目录 `TritonKit/` 已切回 `main`；源 tip 经祖先检查后，旧分支 `codex/wip-main-before-sp209` 使用 `git branch -d` 删除，历史仍可由 merge 第二父提交访问。
- 临时 `TritonKit-worktrees/main-integrated` 先解除 main 占用，再将 `.build/`、`CLI/.build/`、`CLI/.triton/`、`Web/dist/`、`Web/node_modules/` 整体移动到同级 `TritonKit-worktrees/archives/20261021-main-integrated-closeout/`。所有 ignored 内容保留，`MANIFEST.json` 登记路径和 36113 个证据文件 SHA-256。归档不是活动 worktree。
- 临时 worktree 经 `git worktree remove` 正常移除；最终仅保留原项目目录一个 worktree 和 main 分支。
- SP-219/220 的旧 worktree 在前次收尾已删除，本次仅纠正采用登记中仍写 retained 的状态，不虚构其历史归档 hash。

## 验证与后续

merge 阶段与最终文档阶段 `verify.sh --ci-docs`、`check-docs.sh` 和差异 whitespace 检查均通过（220 spaces）。源 tip 祖先关系、产品差异为空、主目录 main 分支与唯一工作树清单均通过终检。仅 docs/internal skill 改动，无需重复运行产品/设备测试。最终 docs 提交随本次已授权 push 同步 origin/main，并观察该提交 CI。

## 遗漏原因与修正

此前把临时 main 已推送等同于原项目目录已经收口，未检查原目录仍在旧分支及其后续文档提交；发布状态也未完整同步到索引和采用登记。已将“原目录 branch、源 tip 祖先关系、远端同步、工作树清单和 ignored 归档”检查补入 ops skill 和参考采用流程，避免只报 main SHA 而遗漏目录状态。发布完成后补写的记录属于 main 后续文档提交，不移动已发布 tag。
