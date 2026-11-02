# 2026-11-02 DTUHID 真模拟器验证

阶段：真实验证与最小修复已完成，待主控最终收口；不将离线交付或protocol ACK当业务成功。用户本轮明确授权新建专用模拟器、必要输入、发现问题直接修复/测试并合本地main；未授权push。基线main `71b878c592a7b5691248f6d65988f8bce9533898`。所有device/build动作由同一执行者串行处理，不操作既有用户booted设备或关闭现有DeviceHub。

## 事实与首次反证

工具链Xcode27.1；新建专用iPhone17/iOS27.0（精确UDID仅在私有证据），使用`triton sim create/boot`。Release TritonKitDemo通过`triton xcode build/app install/app launch`构建安装，页面Status:Disabled，未接embedded runtime。先存status/doctor/capabilities/schema/plan/list及doctor；原始命令、target、时间与退出码在仓外`archives/SP-255-dtuhid-live/*.receipt.json`，stdout/stderr、截图、构建DerivedData留同目录。

首个`act tap --hid-only` exit1、`ios_host_hid_device_hub_attached`，未输入；`tap-first.*`保留。并未启动/关闭现有Hub。目标guest notify实际返回`com.apple.coredevice.dtuhidd.active 1`。该值是guest daemon active观测，不能直接认定外部UI独占；旧无条件拒绝挡住已可握手的DTUHID。

## 修复边界与BDD

- snapshot保留严格target-bound active0/1，其他/缺失/malformed继续unknown拒绝。默认调用维持拒绝active；只有生产helper显式允许先观察，再构造modern-first driver。
- 已知active=1仅在成功DTUHID service lookup+no-event握手且backend=dtuhid后允许contact；legacy active仍拒绝，unknown不创建driver。preflight不协商modern，active时仍保守拒绝，不代表modern不可用。
- screen等值含active位，初始化后变化在输入前拒绝，发送后变化/unknown返回surface_changed/可能已输入，不重放。Resize、唯一主屏/portrait、geometry和target仍原样校验。
- focused先红（新增gate测试缺所需观测字段）后绿；新增active0↔1前/后翻转、strict parser、legacy拒绝、preflight拒绝、post-send unknown无重放。已有typed wire/poison/XPC callback测试保留。

## 已完成真实证明

1. opt-in `DTUHIDLiveIntegrationTests`只对显式owned UUID运行，走生产guard→NativeSimulatorDigitizer.init→finish→guard，明确断言backend=dtuhid，未发任何touch/key。exit0。前后截图业务区域保持Complex harness:0、输入框与carousel item1–4；系统状态/实时钟变化不算业务变化。它证明本工具链的无事件barrier在该fixture未造成可见业务改变，不泛化所有系统副作用。
2. 修复Debug CLI真实`act tap --hid-only --at 192,366` exit0、message backend=dtuhid，截图Complex harness:0→1；未用AX performPress或embedded动作替代HID。receipt仍verification=not-verified，业务通过由独立截图后置给出。
3. 同一Debug CLI真实`sim swipe`横向手势exit0、backend=dtuhid；截图carousel由item1–4移至item7–10，计数仍1。截图尺寸1206×2622；操作坐标来自3x原生framebuffer，不复用陈旧AX坐标。
4. 首轮host AX读取返回tree_unavailable，原失败保留；本轮以主framebuffer截图独立观察，未为了通过而AX激活。OCR只作为截图候选读取，不执行输入。

## 验证状态与后续

扩展focused35项/6 suites通过（live默认禁用）；完整CLI XCTest162、SwiftTesting1680项/179 suites通过，live默认skip不冒充完整CLI实测。显式live barrier另行exit0。Release候选构建与实测、Resize拒绝及owned设备清理均已完成，见下方。

许可来源沿SP254固定Loupe/idb MIT和完整通知不变；未引入依赖、上游执行或签名/DDI。新经验为daemon active与exclusive ownership的区分，应由主控更新权威host skill/原历史当前断言及memory；不改写历史“当时拒绝”的原命令事实。


## Release复验、Resize与清理完成

- Release CLI构建exit0（114.18秒），精确二进制副本与hash存私有归档。相同`--hid-only`真实tap返回backend=dtuhid，计数1→2；反向真实swipe返回backend=dtuhid，carousel从item7–10回到item1–4。截图分别release-tap.png、release-swipe.png。
- Triton无appResize环境设置入口（已保存sim help/schema）；只对自有精确目标使用官方`devicectl device appResize start --preferred-size 560x874`，进程intent记录PID/target，原native JSON/log保存。Resize期间host截图1680×2622，HID tap exit1、`ios_simulator_resize_touch_unroutable`，页面计数仍2，没有AX输入替代。仅对自有resize进程SIGINT正常结束，native exit0。
- 恢复普通主屏后截图1206×2622；Release HID tap backend=dtuhid，计数2→3。最终再次显式live init+finish barrier test exit0，前后计数仍3、carousel位置/输入框无变化。该证据限定本机Xcode27.1+iOS27.0+iPhone17+单主屏fixture；不推断其他OS/secondary/任意App。
- unknown/active翻转与legacy-active拒绝由离线fixture验证，未伪造真实daemon状态或强行制造不明系统失败。现有现代unknown lookup/connection不fallback、poison不重发和Resize/geometry测试继续通过。
- `triton sim shutdown`退出0；Triton schema缺delete后仅对本任务创建的精确UDID调用`xcrun simctl delete`退出0。cleanup-list与最初inventory按全部既有UDID/state比对完全相同，owned实例已消失；既有用户booted iPhone保持Booted，没有关闭现有Hub。
- focused35/6通过（含1个默认disabled live），完整CLI XCTest162/SwiftTesting1680项179 suites通过，2个live默认disabled；DTUHID显式live单项两次独立通过。未执行新root/iOS SDK测试：改动仅CLI host路径，无embedded变更，Release Demo构建/真实输入另行通过。文档门禁与diff结果保留同归档。

所有原始失败、红/绿、真实动作、no-event barrier、Resize进程与清理回执均保留，不只留成功摘要。公开文档不含私有device UUID；归档manifest绑定来源/源码/测试及release二进制hash。公共skill/memory/当前入口由主控统一同步，不在本切片混写。
