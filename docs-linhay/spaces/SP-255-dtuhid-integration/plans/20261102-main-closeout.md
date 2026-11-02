# SP-255 2026-11-02 主线收口

已按授权将候选27437c0ab7eb2a73aa9f23b14f1393b71aefe3ac合入实际main c4a14e5282479b3fa10da0b1bbb3f720e1393d2d。13文件冻结hash与独立审查全部一致；merge-tree只报SP254 README add/add，保留执行方实现/验收事实并补主控链接，产品文件无冲突且与候选相同。

## 验收

- 候选focused42/7 suites、完整CLI XCTest162+SwiftTesting1677/178通过；red捕获缺失模块、失败后允许继续发送及helper/XPC接线缺口。无效请求/目标helper退出1且单JSON，未查询设备。
- 合后实际main完整CLI162+1677通过，exit0；适用local exit0：根包XCTest5及SwiftTesting110+294、release CLI构建/CLI smoke/fake Harmony host/mock iOS runtime observe/docs/diff通过。Xcode Simulator build由TRITON_VERIFY_XCODE=0显式跳过；真实Simulator/DeviceHub/private endpoint ABI/guest输入及业务后置条件均未执行。
- 匿名本机XPC peer只证明回调、pending、cancel、late-reply和消息顺序；DeviceHub claimed、Resize、geometry、ownership拒绝不变。现代transport加入不等于DeviceHub接管已解决。公共backend仅诊断文本，不冒充新增完整DTO契约。
- 发送失败永久poison，仅一次同连接terminal-up；错误不重放。经验已沉淀SP254契约及host-simulator skill，未新增重复规则。

## 归档与清理

候选证据64项manifest及含源码/ignored fixture的88项cleanup manifest全校验，归档在仓外archives/SP-254-simulator-dtuhid-transport。主控logs、smoke及测试release二进制在archives/SP-255-dtuhid-integration。

执行聊天01a19a07-826b-7453-8624-e46a38f9cb7d已完成并由工具返回archived=true；长期主控开放。候选为main祖先且worktree干净后，Git工作区正常移除、分支git branch -d删除成功。

应用managed worktree工具只支持自己的路径，无法登记按repo规范移至同级的工作区；清理时移回原managed路径并调用archive_worktree仍报“Could not verify the task's primary checkout”。未伪造工具归档成功；已验证证据后按既有授权正常git移除。应用中的旧worktree附件可能残留，单列为待后续工具恢复清理；不影响本地Git源码交付和执行聊天归档。后续命令显式使用原项目绝对路径，避免陈旧附件路径。

未push/tag/release、依赖安装/升级、上游执行、签名/DDI或设备动作。

## 后续真实验证

本页为初次离线收口历史；用户随后明确授权专用模拟器与输入，5e1c0b74修复active误判并完成真实验收，见[验证记录](20261102-live-validation.md)。上文未执行真实动作与active拒绝是该历史时点事实。
