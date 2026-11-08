# SP-277 — v0.2.42 发布

## 范围

发布SP276的Harmony空白文本读取修复。候选不包含SP257人工IME WIP，#246整体与私有App、#224默认iPad验收缺口保持未知，#214继续暂停。不关闭issue、不移动历史tag。

隔离分支codex/sp277-release-v0-2-42与同级worktree；发布clone复用SP250-publish，主目录WIP不动。

## BDD与门禁

旧版本manifests对0.2.42应失败，升级后版本一致；修复候选CI与main CI、完整local preflight、标准Pod、公有skills/Web必过。新tag资产双架构/checksum/BUILD_INFO/Homebrew/两个skills roots对齐；安装CLI空白fixture3/3、仓库外packaged Web HTTP与真实浏览器验收。

纯JSON归一化修复无需真实设备写入；设备输入、三端实时采集与私有App恢复不由本切片证明。CocoaPods lint与trunk发布分开。

## 状态

2026-11-08：0.2.42未占用，版本预检旧值按预期失败；产品PR280精确CI等待中。版本候选准备，未发布。
