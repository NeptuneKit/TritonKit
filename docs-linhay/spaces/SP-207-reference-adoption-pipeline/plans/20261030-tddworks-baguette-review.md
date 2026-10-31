# Baguette 2026-10-30 增量审阅

结论：观察，无新增采用切片。影响层为上游发布文档；本地CLI/HTTP/shared core不需改动。

固定基线 `201de19842d4d6964f1e37989d69fcda24d5eefc` → HEAD `94b78d3603acf661e1f593aff7891c3bd7a86c44`。分页提交列表在第1页命中基线，共1提交 `chore(changelog): promote [Unreleased] to v0.2.12`。固定base/head递归git trees均非truncated；逐blob SHA比较仅 `CHANGELOG.md` 改变，没有源码变化。按根目录文档用途及.md文本白名单获取两端全文，完整差异仅新增0.2.12标题/日期及更新比较链接，见 `CHANGELOG.diff`；未请求compare或含patch的commit接口。

[Release v0.2.12](https://github.com/tddworks/baguette/releases/tag/v0.2.12)发布于2026-10-29：60Hz铰链3D呈现、超过60秒sweep拒绝及精确socket错误，均是10月28日已审源码的发布，不是新实现。上游性能数字未经本地验证。许可证固定HEAD全文SHA256为 `0509ebb2d8d399fb183d1973d3f6ad585e209ca4c2c42a90f3c22c0f32c1ab3e`，Apache-2.0不变。

重新对照实际 `main@30185dc277ed305483aa789cb2d8c8b06fa21fe4` 固定blob：`CLIDeviceEnvironmentRuntime.swift:106–123`仍对iOS Duo明确unsupported；Android仅静态角度控制，requested/observed/verified分离并读回验证，无动画时长整数转换。`CLIHostNativeHIDRuntime.swift:125`要求finite、正数且不超过10秒。SP-192稳定/预算语义、SP-196资源与生命周期强化、SP-200环境控制以及采用登记已核对；本次发布不产生本地新差距，不重复排期3D控制面。以上main源码/资料已保存本目录供复核。

本次增量阅读完整；累计仓库状态仍为partial，不能推进历史成功检查点。历史APK、dylib、无扩展名HingeControl及身份/证书/私钥等来源缺口原样保留在review.json errors；本次未获取这些内容，未声称已恢复。证据为 `commits-1.json`、`base-tree.json`、`head-tree.json`、`increment-manifest.json`、两端CHANGELOG全文、`CHANGELOG.diff`及本批已有release/license证据。

未实现、安装、运行第三方代码或执行设备/产品测试。本次仅只读取证，无新增治理经验；正式space/state/memory写回由主控统一完成。
