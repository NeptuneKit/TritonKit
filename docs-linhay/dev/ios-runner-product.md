# iOS Runner 产品封装

对应 [SP-195](../spaces/SP-195-ios-runner-product/README.md)，研究依据为[归档的公开 XCTest 多 App 真机实验](../spaces/SP-195-ios-runner-product/research/README.md)。产品提供 `triton device runner` 与 HTTP `/v1/device/runner/`；共享 Swift service 和全局目标 session registry，用户不运行研究 Python 脚本，也不需安装 Appium、WDA 或 iproxy。

## 使用入口

```sh
triton device list --platform ios --scope real --json
triton device runner doctor --device ios-real:<id> --json
triton device runner prepare --device ios-real:<id> --allow-provisioning-updates --json
triton device runner start --device ios-real:<id> --allow-bundle com.apple.calculator --ttl 600 --json
triton device runner activate --device ios-real:<id> --bundle-id com.apple.calculator --json
triton device runner inspect --device ios-real:<id> --bundle-id com.apple.calculator --limit 40 --json
triton device runner tap --device ios-real:<id> --bundle-id com.apple.calculator --identifier Seven --request-id calc-seven --json
triton device runner receipt --device ios-real:<id> --request-id calc-seven --json
triton device runner status --device ios-real:<id> --json
triton device runner stop --device ios-real:<id> --json
```

`<id>` 来自设备列表。prepare 使用本机可用签名 identity 的唯一证书团队；多个团队或未能明确发现时传 `--team <team-id>`。`--allow-provisioning-updates` 是显式允许 Xcode 处理 provisioning，未提供时不会隐式加入。签名选项只属于 prepare。设备须完成配对、开发者模式、可信签名和 UI 自动化授权；密码解锁仍由用户完成。

每次点击先 inspect，selector 必须来自最近30秒的观察，执行前重新确认唯一且可点击；动作后再观察业务状态。输入使用 `type --text-file <private-file>`，最多4096 UTF-8字节并检查焦点；不把输入写入 CLI argv。截图使用 `screenshot --output <new-private.png>`，全屏 PNG 不保证目标 App 画面归属，需核对。超时先用 `receipt --request-id <original-id>`；截图回执可加 `--output <new-private.png>` 恢复原缓存 PNG，不重新截图。

## 执行与状态

1. 内置未签名 Runner 源项目随 CLI 分发；manifest 同版、白名单、文件大小与 SHA-256 校验，资源缺失或被改动明确失败。Homebrew 使用 pkgshare/ios-runner，portable 包使用 resources/ios-runner，SwiftPM bundle 也可解析；资源定位不依赖源码 checkout。
2. prepare 复制已验证资源到私有缓存，再按目标和本机 Xcode build-for-testing，保护安装目录。每次独立 DerivedData，prepared 配置绑定资源摘要，升级不能静默复用旧签名产物。
3. start 生成新的 token/session/xctestrun，执行 test-without-building；只有网络 health 与 fixture AX probe 均通过才返回启动就绪。运行直到显式 stop 或 TTL，不宣称永久后台。
4. Swift transport 真机直接连接 usbmuxd，精确 USB UDID匹配，Connect 后在同一socket发送鉴权 HTTP；Simulator 为固定loopback TCP。整体deadline、帧/HTTP预算、响应session/requestID匹配，无自动重试。
5. 全局设备 registry 和跨进程 flock 不依赖 sessionRoot；sessionRoot 只控制私有产物目录。CLI、HTTP 和不同 CLI 调用共用 owner；stop/status 可从已登记 canonical设备访问记录，不依赖设备当前在线。终止前核实自己启动的精确配置路径，退出判定不以 ownership 查询失败代替进程消失。
6. status 的 health 只证明网络，automationPreviouslyVerified 记录 start历史验证，当前 automationReady 不由health推导。request/receipt 使用实际返回与后置状态判断。返回 submitted 不等于业务成功。

## 通信与权限边界

Runner 使用 XCTest、Network、Foundation 和 UIKit 的公开接口，业务 App 不需嵌入 TritonKit SDK。应用白名单由 start明确允许，fixture仅作为自动化就绪基线。HTTP `/v1/device/runner/{doctor,prepare,start,status,stop,request,receipt}` 使用同service，body最大64KiB，长操作在后台执行，不混用embedded ConnectionState。现有 embedded /input、/request 与通用 act 的平台范围不因此自动改变。

设备 UI 动作串行；缓存不淘汰旧ID，受256 ID/32MiB总预算限制。传输 unknown 必须保留 requestID，查询 receipt或状态，不自动重发动作。PNG与native日志私有；Apple XCTest自身可能记录输入内容，因此不承诺系统日志没有输入。公开返回不包含token、原始设备ID或base64图像。

Safari 焦点问题保留严格拒绝，接口可用不代表所有App输入都通过；设备锁屏、USB断线、重启、无Mac启动及长期保活必须分别实测。本期的产品验证结果写入 [space](../spaces/SP-195-ios-runner-product/README.md)，不能借用旧研究实验作为新CLI通过证明。

## 本期产品验收与已知限制

2026-10-14：portable CLI 从源码目录之外调用 doctor/prepare/start，使用安装包内资源完成有线 iPhone 的签名构建和 UI readiness probe。计算器7+8=15、同ID重复等于仍15、Settings不可点击拒绝后滚动进入General并返回、fixture计数1跨App保留、全屏PNG原回执恢复字节一致、stop acknowledged与nativeExited均通过；原生testServe326.786秒并以TEST EXECUTE SUCCEEDED结束。Safari activate通过，inspect在默认18秒预算下返回transport unknown，本期没有输入或网页导航通过结论。Simulator从prepare/start到fixture点击计数1、stop与shutdown也通过。

Simulator transport目前固定loopback端口19439，本期只验收同一Mac一个Simulator Runner；不宣称多Simulator并发。同一手机跨App成功也不能推导锁屏、断线、重启或永久后台的生命周期可靠性。Homebrew formula与两架构资源包契约有离线校验；真实brew升级和远端Release发布不在本次本地交付范围。

本地最终门禁通过：CLI1297 Swift Testing与36 XCTest、根包274与shared59 Swift Testing及7 XCTest、local gate含Release build/smoke/真实Simulator build、docs gate、Release automation/Homebrew formula/skills package校验。57新增host Runner测试包含已stop的会话过TTL仍保持stopped的回归。arm64 Release tar最终binary在repo外schema/doctor/status通过，资源缺失/损坏负例明确readyToPrepare=false。产品已引入本地main并通过主仓local gate，参考文档与Runner分别提交；原worktree保留，未执行远端发布。
