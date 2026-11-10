# SP-277 — v0.2.42 发布

## 范围

发布SP276的Harmony空白文本读取修复。候选不包含SP257人工IME WIP，#246整体与私有App、#224默认iPad验收缺口保持未知，#214继续暂停。不关闭issue、不移动历史tag。

隔离分支codex/sp277-release-v0-2-42与同级worktree；发布clone复用SP250-publish，主目录WIP不动。

## BDD与门禁

旧版本manifests对0.2.42应失败，升级后版本一致；修复候选CI与main CI、完整local preflight、标准Pod、公有skills/Web必过。新tag资产双架构/checksum/BUILD_INFO/Homebrew/两个skills roots对齐；安装CLI空白fixture3/3、仓库外packaged Web HTTP与真实浏览器验收。

纯JSON归一化修复无需真实设备写入；设备输入、三端实时采集与私有App恢复不由本切片证明。CocoaPods lint与trunk发布分开。

## 状态

2026-11-09：v0.2.42已正式发布，PR280/281及精确main/tag/Release CI通过。双架构资产/checksum/Runner/Web/skills、Homebrew、两个skills roots、安装版空白fixture和真实浏览器只读离线验收通过。CocoaPods标准远端lint通过、未推trunk。详见[发布验收](plans/20261109-release.md)；人工IME、默认iPad与原私有现场不作通过声明。
