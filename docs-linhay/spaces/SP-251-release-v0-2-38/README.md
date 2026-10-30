# SP-251 v0.2.38 skills更新与完整发布

## 当前状态

已完成v0.2.38发布与安装验收，tag固定74680bbd；main/tag/Release CI全绿，双架构、Homebrew、两处skills及三端公开包预览通过。本轮测试资源已清理，其他任务WIP保留。用户已授权提交、推送与发版，未移动旧tag。

## 边界与BDD

- 影响层：公开skills、CLI/HTTP采集、随包只读Web、iOS SDK版本与发布资产；产品实现来自SP244–249的已提交工作，不加入新的内存候选。
- Given 本地main的Rhine/内存提交与远端WebView修复分叉，When整合，Then两边产品与验收历史均保留，原SP193/SP207未提交资料不进入发布。
- Given version0.2.37，When准备0.2.38，Then先保存版本门禁失败，再同步podspec/Web两manifest；CLI/skills由tag构建stamp。
- Given最终联合候选，ThenCLI全量、Web test/build、local、skills/发布契约与实际main CI通过；原minimum CocoaPods标准lint是发布前门禁。
- Given公开制品，Then双架构CLI、Runner、Web、skills和checksum同版，Homebrew安装与包外只读Web验证通过；预览采集格式与隐藏恢复保持边界，不能用首页200代替流验收。

## 工作区与证据

分支`feat/SP-251-release-v0-2-38`，同级worktree；实际发布使用干净的独立main克隆，与候选SHA一致。主目录WIP通过精确patch/hash保全，不能stash或混入提交。所有共享build、git、服务与设备动作由主控串行。

本轮[发布记录](plans/20261030-release.md)；沿用[发布治理skill](../../../.agents/skills/tritonkit-release-package-governance/SKILL.md)。未授权的issue关闭、私有App修改与CocoaPods trunk发布不在本轮范围。
