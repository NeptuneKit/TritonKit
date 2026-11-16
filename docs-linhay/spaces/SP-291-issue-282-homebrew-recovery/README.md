# SP-291-issue-282-homebrew-recovery — Issue #282 Homebrew 升级恢复

状态：实施中（2026-11-16）。

## 范围与BDD

CLI update/Homebrew分发；不直接覆盖Cellar，明确no-bottle/旧Xcode失败及可验证的独立安装恢复路径。

- Given 当前main与初始线上需求，When 完成代码、测试与契约后集中验收，Then 每项分别记录实现、fixture、真实运行和发布证据，不以发行成功替代行为验收。
- Given 失败或未知结果，Then 保留原错误和部分效果，不自动重放写操作。

- Given Homebrew编译器检查拒绝且显式选择新绝对目录，When 执行恢复安装，Then 保留Homebrew来源/Cellar/符号链接/PATH并报告新installedExecutable；完整CLI/Web/Runner/bundle属于同一已校验tag。
- Given 目标已存在、Cellar、symlink/traversal、checksum/归档/资源/版本不符，Then 拒绝覆盖且不继续skills；失败保留attempted与目标路径，不假报installedVersion。
- Given 同版本恢复，When 明确--yes，Then 仍安装并核验新路径；check/dry-run不执行brew、下载或写入。
- Given 校验匹配但归档漏发 Vite JS/CSS 入口，When 请求独立恢复安装，Then 拒绝发布新目录。
- Given 当前 CLI 来自完整独立包，When 查询下一版本或尝试 `update --yes`，Then 显示安装到新目录的命令；未传该目录时保留原整包，避免 CLI 和 Runner/Web 混版。

## 验收

候选通过独立目录安装公开 v0.2.45 的复验。启动计划返回 `mode=packaged`，原安装执行文件的 SHA-256 一致。回归覆盖缺 JS、缺 CSS、只有空壳 HTML、整包升级拒绝原地仅换二进制及同版恢复。待用已发布 v0.2.46 由旧版用户引导流程再验 release、tap 和安装结果。
