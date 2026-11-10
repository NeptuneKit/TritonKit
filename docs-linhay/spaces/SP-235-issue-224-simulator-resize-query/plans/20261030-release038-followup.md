# #224 · v0.2.38 发布后证据接替

## 当前结论

#224继续OPEN，部分验收推进，未整体解决。本轮以远端main `1139db7712d485c0927282a4415ac45765567332`及已发布tag `v0.2.38`重新核对。发布由SP251负责人完成，本轮复用其真实验收，不重复发布或占用设备。

| 场景 | 最新证据与边界 |
| --- | --- |
| iPhone主屏实时预览 | SP251当前候选真实native 1/1、1206×2622 JPEG主屏内容通过；安装版0.2.38真实浏览器首帧、双预览、隐藏/恢复通过。旧0.2.37的7680×4320黑图为历史失败，主屏identity绑定修复已经发布 |
| iPhone默认截图/单次swipe | SP235原Xcode27.1验收已证实默认1206×2622截图、Settings滚动后置状态；本轮不重复该设备测试，也不把新预览验收当作新的输入证据 |
| iPad默认截图/输入 | 原Xcode27.1 A16/iOS27精确CoreDevice1001仍为unknown/unsupportedDevice。0.2.37→0.2.38未改Resize/display/HID/default screenshot门禁；没有新的可验证后端证据，不扩大为恢复 |
| iPad显式主屏still | 原单LCD opt-in截图已通过，仍保留resizeVerified=false/inputDispatchVerified=false；不能扩展至流、默认捕获或HID |
| 原用户私有App | 本轮未修改、未验；工具链以用户允许的Xcode27.1为范围，旧26.6不作为本轮阻塞 |

## 证据核对

- [SP251正式发布及三端公开包验收](../../SP-251-release-v0-2-38/plans/20261030-release.md)：tag固定 `74680bbd962111111690b9a53f3a548f6781a3ca`；[main CI](https://github.com/NeptuneKit/TritonKit/actions/runs/41058224415)、[tag CI](https://github.com/NeptuneKit/TritonKit/actions/runs/41060054355)、[Release](https://github.com/NeptuneKit/TritonKit/actions/runs/41060054364)通过，收尾main CI41064879265通过。
- 本轮远端回读Release四资产及digest，与SP251记录一致；本机CLI为0.2.38。没有重复下载/安装或声称本轮执行了SP251的设备矩阵。
- tag差异复核：Simulator生产变更为framebuffer主屏选择及逐帧对象释放；Resize、display safety、native HID及CLIHostRuntime的默认截图路径与0.2.37一致。主屏绑定解决选错surface，与iPad Resize能力查询拒绝是不同剩余边界。
- 全部开放issue及评论、成功下界后已关闭issue/PR更新和评论已读取，没有新issue或原现场回报。来源聊天无新指令。SP251负责人已完成并清理独占测试资源；原主工作区23个参考跟踪WIP保持不动。

## 接续条件

不以诊断改善、显式截图或iPhone预览成功关闭issue。后续若出现支持iPad Resize状态的可验证后端、独立安全路由契约或新的原生响应，再在自有fixture先写失败测试、最小实现并分别验收默认截图/输入/流；不通过推断inactive解除unknown保护。新issue巡查持续，#214暂缓。

本轮只更新证据关系及当前入口，未新增产品行为。复用host skill既有“主屏绑定与Resize能力拒绝分离”规则；不新增重复经验文件。文档门禁与提交CI绑定本次文档候选，自动任务memory记录最终SHA和运行检查点。
