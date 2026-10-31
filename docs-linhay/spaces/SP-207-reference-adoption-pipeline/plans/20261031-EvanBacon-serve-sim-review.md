# serve-sim 2026-10-31 增量审阅

结论：observe，无新增采用切片；影响为上游Simulator相机注入的Objective-C生命周期与真实模拟器测试。本地相机CLI/hook无需复制该修复。

固定基线 `0193e65c481fc9b64a62427f32fcf143dbc3d2c0` → HEAD `ede4c21ee3021a36fbee1fec106b388a50a5ce4e`，1提交、1父边、3文本文件。commits第1页命中基线；每提交/父边完整递归trees均未truncated，仅该父边，故不存在遗漏中间回滚。先路径用途及.m/.ts文本白名单筛选，获取两端6个安全blob全文，保存JSON、解码文本和逐文件完整diff；无跳过文件，不使用含patch compare/commit接口。

[固定提交](https://github.com/EvanBacon/serve-sim/commit/ede4c21ee3021a36fbee1fec106b388a50a5ce4e)：SimCamFakeConnection以class_createInstance绕过AVCaptureConnection native initializer，output释放时可进入缺失私有状态的dealloc。改为同步集合在进程期保留每个fake connection，connection仅weak引用output。其占用随进程累计创建过的输出数增长，不能推定恒定内存上限。新增metadata/video output teardown测试：清除delegate、移除input/output、释放局部引用，以weak probe每50ms轮询最多5秒，必须实际释放output/input/session，避免固定延迟假通过。E2E每mode重新启动App并等待结果。

对照实际 `main@1139db7712d485c0927282a4415ac45765567332` 的 `Sources/TritonKitCLI/Resources/sim-camera/TritonSimCameraHook.m` 全文：本地fake device为进程期对象，但没有fake AVCaptureConnection类型、class_createInstance连接分配或output关联连接；上游dealloc故障链不存在，不能盲目增加永存连接集合。本地hook的输入/输出session数组、弱delegate与预览路径属于另一机制；本次不凭上游新测试推定本地复现同一故障。SP-192、SP-196、SP-200与采用登记固定main资料及CameraCommandTests已核对/保存，没有现成同源未交付项重复排期。弱probe证明真实释放可留作未来连接图/teardown专项参考，目前缺少能成立的新增实现BDD/文件面。

Release列表无发布；固定HEAD LICENSE为Apache-2.0，SHA256 `9024cdf56dfe7e66523698a9f63d3a0061eb15f43bd5ea8e3833a56017ae37fd` 与既有记录一致，沿用本批完整全文证据。匿名curl三次403/exit56已保留network-failure.json；使用现有认证gh官方只读API恢复，当前不再是网络阻塞。

完整增量阅读完成；未运行第三方代码、设备、依赖或产品测试。上游iOS26.5崩溃与释放结果仅为上游源码/提交证据，未经本地运行验证。未修改result/state/正式docs/Git；无新增治理经验，认证读取恢复事实由主控统一回写。
