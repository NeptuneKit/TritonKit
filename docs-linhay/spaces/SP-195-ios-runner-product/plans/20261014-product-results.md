# 产品封装验收记录

## 实现

CLI与HTTP共用Swift service，USB直接连接usbmuxd，unsigned Runner源项目随CLI资源分发；业务App无需SDK。prepare只在私有目录构建签名，start验证network+fixture AX；全局设备锁与owner、session/TTL/token、允许App、最新观察与动作、单JSON输出和回执恢复都有契约。

Release arm64/x86_64流程同版stamp与资源包装，上传前tar inventory/hash校验，Homebrew/pkgshare安装及manifest测试，原SwiftPM资源bundle随包保留；root SwiftPM包未引入CLI-only依赖。README、public skills、command schema snapshot已同步。

## 真实设备

从仓库外运行portable CLI，真机签名构建和启动通过。计算器7+8=15，同ID重复等于仍15；Settings先不可点击拒绝，滚动后General→返回root；fixture计数1跨App保留；全屏截图与原receipt恢复PNG字节相同。stop acknowledged/nativeExited，原生testServe326.786秒、TEST EXECUTE SUCCEEDED。Simulator prepare/start/fixture点击计数1/stop/shutdown通过。

Safari activate通过、inspect默认18秒deadline unknown；未重复提交该观察，后续fixture恢复通过；未在本会话结束前恢复Safari原receipt，不宣称Safari完整成功。输入/网页、锁屏/断线/重启/永久后台仍待专项验收。Simulator固定19439，仅一台同机Simulator Runner经过验收。

## TDD与回归

资源路径与taxonomy集成先失败后修复：macOS bundle Contents/Resources、/var与/private/var路径、root failurecode去重、capability taxonomy与恢复分类。新增57 host Runner测试、14协议、9离线包装fixtures；CLI全量1297 Swift Testing+36 XCTest。已停止会话TTL之后的status错误先复现，再修复，并重跑门禁。

根包274、shared59 Swift Testing及7 XCTest，local gate包括Release CLI/smoke/Harmony smoke/iOS observe smoke/真实Simulator build/docs/diff；最终结果见[脱敏摘要](../product-verification.json)。HTTP5条router tests；19421被其他服务占用，未启动第二个产品server或修改其状态，未宣称真机HTTP全流程。arm64 Release tar真实binary从repo外version/schema/doctor/status与缺失/损坏资源负例；x86资源archive离线契约验证，不是原生x86执行验收。

## 交付状态

产品已引入本地main，主仓local gate复跑通过；参考文档独立提交306dc42b，Runner单独提交。原feature worktree和私有证据保留，无远端发布、tag或push。旧Runner研究记录归档到SP195/research，主仓正式SP193/194参考文档保留；私有日志/截图/签名/设备事实保留ignored .build及用户私有registry，不进入公开证据。
