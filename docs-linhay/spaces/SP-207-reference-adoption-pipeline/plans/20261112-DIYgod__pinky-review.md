# Pinky 安全增量观察 · 2026-11-12

结论：partial/observe，无独立新采用。import base仍SP279静态研究209aa9e4/v2026.1109.16，checkpoint=null；新增观察窗口3248613b→9c350457c4014ccd987e443a8a03bd74806f8c44，actual main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`。默认main、最新非draft v2026.1112.2；5个新Release全文已读，固定Apache2全文hash未变。

新窗口33 commits/167净路径，compare1页闭合；只取base/head2棵完整树及15条安全文本路径的27个完整blob版本，Git blob SHA均校验。未重抓旧321增量、未请求二进制/身份材料、未取全部parent树与全新文本。因此旧321/206树阶段缺口与新窗口未审项分别保留，不推进checkpoint。原clone当前缺失原因unknown。

关键审阅：pilot为model请求截取剩余任务deadline，usage后再次检查TimeLimit再执行，late-response与通知消耗时间有测试；Android key清理旧note、type的enter保留hidden/unread，gateway同时读取type/key说明；Xiaomi后台display按capability使用Companion，否则明确错误/可能丢键。policy禁止agent打开/点击自己审批UI，精确包名+profile克隆匹配，允许Home退出；logs接受schema里的canonical logs并有回归测试。源码、选中全量diff及测试均只读未执行。

本地判断：Pinky model-runner、Xiaomi真机后台display、on-phone审批UI和phone_logs不是Triton同源实现，未证实需新开发；SP280/281已有admission/receipt工作避免重排。MyGo0.9.0的secure AX修复只有Release及go.mod证据，依赖内部未审、运行未验，不当安全通过，也不安装升级。

当前可用新资料是关键安全观察，不是完整增量成功；metadata/result由主控维护，本子任务仅review证据写入。经验检查完成，无额外仓内变更。
