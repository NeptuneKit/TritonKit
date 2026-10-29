# Baguette 2026-10-28 增量审阅

结论：observe，无新采用切片。本日仅iPhone Duo铰链3D呈现平滑、串行sweep、最长60秒与精确错误；Triton iOS折叠明确unsupported，Android折叠直接读回角度，native HID已有有限值/10秒上限，无同源整数溢出路径；不新增3D写控制面。

## 固定来源与完整性

- [完整比较](https://github.com/tddworks/baguette/compare/34097c50d1db2ad5c0278867c5363dca046298f4...201de19842d4d6964f1e37989d69fcda24d5eefc)：2提交、27文本路径；逐commit文件数低于100分页上限，全部patch加减行计数匹配，merge内容与功能提交一致；固定HEAD全文27份已下载供相关上下文复核。无比较/patch截断。
- [功能提交](https://github.com/tddworks/baguette/commit/9104113396785b471c394b14dfbc5ab59838bf93)：HingeSweep/PosedHinge、SharedHinge/RenderedFoldable、CLI/HTTP/socket错误及测试/文档。
- [Release v0.2.11](https://github.com/tddworks/baguette/releases/tag/v0.2.11)未变；今日内容为未发布主分支增量，不能当新版本已发布。软件键盘观察项沿用10月27日裁决。
- [许可](https://github.com/tddworks/baguette/blob/201de19842d4d6964f1e37989d69fcda24d5eefc/LICENSE)：Apache-2.0全文hash `0509ebb2d8d399fb183d1973d3f6ad585e209ca4c2c42a90f3c22c0f32c1ab3e` 未变。历史APK/dylib/身份材料来源缺口未修复，不重新获取这些内容、不推进累计成功点。

## 实际机制与本地边界

上游把命令动画与真实读数分离：自己的sweep先以60Hz插值呈现，成功后保持目标直到读数赶上；拒绝/未确认退回实际读数，读数反向/越界退出保持。共享fold串行，停止流取消timer/watch。CLI/HTTP/set_pose统一拒绝超过60秒或非法角度，socket报告具体错误，避免巨大duration转换溢出。

对照实际main `a0d187ace03d6e56b79b50a7a601c91b359b7955`：`Sources/TritonKitCLI/CLIDeviceEnvironmentRuntime.swift:106` 的iOS Duo明确unsupported；Android fold仅设置静态角度并读回，保留requested/observed/verified，无浮点时长转换。`CLIHostNativeHIDRuntime.swift:125` 已要求finite、正数且最多10秒。SP-192的视觉稳定、健康与预算机制，SP-196强化、SP-200环境控制以及SP-218/219输入/录制已交付，不因为上游展示动画重复立项。Web只读DTO不新增socket动作或乐观成功状态。

借鉴价值是保持commanded/displayed/observed语义分离；本地已用requested/observed与verified拒绝不符值。未来若独立立项3D/折叠动画，BDD须涵盖延迟读数、拒绝/未确认、外部反向输入、串行与关闭取消；真实设备证明不能由上游fixture替代。本日没有确认可纳入的实现缺口。

上游60Hz、0.8秒命令/约5秒读回为上游自述，未经本地验证。未运行第三方代码、设备、依赖、签名/DDI或产品测试。沿用既有安全文本读取与累计完整性规则，无新治理经验。
