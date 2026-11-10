# SP270 / issue #273 独立产品审阅

## 结论

**通过本轮静态产品审阅：未发现可证实、需要先修的 P1/P2 产品缺陷。** 此判断仅针对下列精确文件内容，不代表标准 Pod、整合候选测试、发布制品或真实私有 App 已验收。未执行 build/test、设备、服务或 Git 写操作；唯一写入为本报告。未修改产品、Space、索引或他人现场。

审阅时间：2026-11-03T05:17:14.908569+00:00；工作区：`<worktrees>/SP-270-lookin-core-integration`；基线与读取时 9578782a7cbfd855228f8e996b07d93437725870：`9578782a7cbfd855228f8e996b07d93437725870`。原验收候选基线 `edffb45e`，整合对照 `9578782a`。已读取当前 AGENTS、命中经验、ops-governance、SP270 README、技术契约、验证与 Web 报告及 `archives/SP272/issue273-integration-audit.md`；按实际 tracked diff 和新增文件审查，未将原审计结论直接作为本次判断。

## 已核对的关键路径

- **Release no-op 与 capability**：`TritonKitRequestHandler.swift:39` 在路由和 UI admission 前拒绝 Release details；`TritonKitRequestHandler+HierarchyDetails.swift:19` 直接 provider 也检查 runtime；`TKLayerScreenshotCapture.swift:17` 直接 helper 在读取/渲染 layer 前拒绝 Release。`TKHierarchyBuilder.swift:31` 保持 Release 空采集。请求详情始终需要 hierarchy，截图模式非 none 时额外要求 screenshot capability；普通 hierarchy 自动图像也检查 screenshot feature。没有以 canImport(UIKit) 替代 Debug 编译开关。
- **捕获 bounds/恢复/预算**：捕获拒绝非有限 origin/size、零面积、hidden/低 opacity、自有 overlay；同时限制像素面积与每轴8192。以实际 bounds origin 反向平移，没有二次 y-flip。solo 不拆层，保存每个直接子层 hidden 值，在 MainActor 同步 CATransaction 中隐藏并 defer 原样恢复，无 await。详情8 OID、每图最大1048576、请求4194304 pixels/bytes及节点/图片间2秒检查明确；层级采集共享4194304像素预算、既有节点/深度/数量预算。未把 cooperative deadline 写成可抢占 CALayer.render/PNG 编码。
- **图像语义和裸层身份**：`tk_hostView` 要求 view.layer === layer，避免任意 UIView delegate 被当作 backing view。裸 CALayer 及子树被保留，view metadata 不伪造。上传分别保留 solo/group ref，失败 bytes 保留；scene 不把 group/历史 subtree 当 solo，混合成功/失败路径仍可落到 inline PNG。CLI inline 数据有4MiB编码、PNG签名/IEND、ImageIO类型/完整性/单图/解码和1048576像素检查。
- **PNG 与记录边界**：新截图只经已授权的详情/层级传输返回，未新增外部上传、console日志或持久记录入口；运行账本 `TKRuntimeSupport.swift:164` 泛型路径只提取 ok/message/error.code，不复制 details 或 PNG。Web 正式组件消费已有 DTO，不新增设备输入/patch请求；选层/旋转/层距仅变更本地状态。既有 Raw/复制 DTO 会包含 DTO 内 dataUrl，属于显式检查/复制能力，并非自动脱敏输出；本审阅不宣称截图内容天然无敏感信息，也不把它们自动公开。图像泄露结论限于没有发现新增非授权外传路径。
- **CLI/HTTP与schema**：debug details 参数在 transport 前验证；重复/零/超量 OID、无效 mode/pixel/host/port 被拒绝。打印前校验响应OID归属/唯一性以及成功完整性；typed partial 和原错误 envelope 均只打印一次，ExitCode 不二次包装。schema注册了数组OID别名/重复方式、截图模式、attribute正反flag、像素预算、输出字段、错误码和恢复类别；solo/both明确 temporary_layer_visibility_for_capture，none/group只读。既有通用HTTP request继续承载此入口，没有新增Web写路由。
- **Web素材/边界**：默认3D材质仅取 hydrated layerOwnContents；group保留为证据。缺图/加载失败有轮廓和数量，隐藏祖先/alpha0阻断后代，零尺寸结构父层不误过滤后代；循环保护、最多200平面、深度64、有限几何过滤；target key重置相机。CSS投影仍是axis-aligned frame+depth，未实现完整transform3D/合成器复原。设计稿仅在design目录，生产新增文件没有设计fixture导入。

## 测试证据与本轮实际检查

本轮读过新增 SDK availability/details/upload、CLI details command/transport/inline/source，以及 Web material/layers/route/Inspector 测试与原报告；未重新运行。原报告的 SDK `7 XCTest +423 Swift Testing`、CLI `162 XCTest +1759 Swift Testing`、Web174、真实 iOS Debug16/Release5、真实fixture HTTP双PNG/partial/patch恢复均作为**原精确源码验收**，不作为本轮新head运行结果。原首次编译/门禁失败和条件跳过继续保留。

本轮实际 `git diff --check` exit0；重算原 sourceSHA256 manifest42文件：41完全匹配，唯一 Web/package.json 从原0.2.39保留为主线0.2.40，其test清单仍只增加hierarchyLayers.test.mjs。当前基线对比Web/package.json没有版本回退。没有新增产品依赖。

## 门禁与未覆盖范围

1. **仍需主控完成的发布门禁**：精确整合候选的必要 SDK/CLI/Web/文档/schema回归，标准 iOS13 CocoaPods lint和对应CI。既有iOS15兼容lint不替代标准lint，本报告没有读取到新的标准成功结果。不以此静态审阅绕过门禁。
2. 后续并行SP273若改变schema共同事实源，需要在联合冻结源码上重新生成/验证公开snapshot；本报告hash只覆盖本次SP270内容。
3. 原真实fixture可复用范围由下列hash绑定；如SDK/Web相关源码或依赖变化，需重跑受影响验证。旧二进制不是0.2.40正式包。Wails壳、任意SwiftUI语义、Metal/视频/远程合成器像素及私有App不是本次已验收声明。
4. 捕获临时visibility不等于业务属性编辑：代码同步恢复，并在details schema明示。Web只读契约禁止业务输入/patch，未将该契约扩张为所有观察必须零临时内部状态。仍保留渲染可能调用应用绘制代码、单次不可抢占的已知风险，不声称通用硬实时或任意宿主无副作用。

## 精确源码/测试 SHA256

以下为审阅结束时重新读取结果；任何不同内容不自动继承本结论。

```text
a7a026c0d49cc27df8ef4d2681b07a7ffe1b8bf5765f4aaf6a8c153adebd3370  CLI/Tests/TritonKitCLITests/HierarchyDetailsCommandTests.swift
e1f80b1ec4b5c3fd86791acd43f655fe07f9a317e79f044d04b0875732ed2a8c  CLI/Tests/TritonKitCLITests/HierarchyDetailsTransportTests.swift
9c3029ec27769ce93128341c76c05eb13007250c33b2f7d600ef50b14d849ce2  CLI/Tests/TritonKitCLITests/HierarchyInlineImageTests.swift
42bd2402ca3a8d6dea0b8f9018260a317058f343594e61880aa6b86abf8d54f6  CLI/Tests/TritonKitCLITests/HierarchySceneImageSourceTests.swift
4d9dce8f792ca81dd7882a8da514a05db533ff9458cd23d14229d1b4064040ea  CLI/Tests/TritonKitCLITests/SchemaFactSourceTaxonomies.swift
4ab8a1ff687728695d307b242c2c025e0d861091b684948226adfa7285ec4ad4  Sources/TritonKit/Models/TKDisplayItem.swift
8a7d04ef6c1fe79f007af2fb0cb8e1b22ba98e6536ee3ece4862f377567379a0  Sources/TritonKit/Models/TKDisplayItemDetail.swift
6c7b21710630bda556a9054ef56883425fe3890c0900db50260615c90887068c  Sources/TritonKit/Models/TKHierarchyDetails.swift
51f283e4ba9a07048ec17e72fceec5a021643837f16339592c354f3f7b26e527  Sources/TritonKit/Server/CALayer+TritonKit.swift
c3e096eb4615e8d1771a8ad4c57caa240f1324eb588a2c02539933e2b228321d  Sources/TritonKit/Server/TKAttributeGroupsBuilder.swift
5dd4cf0c70d7fd819d83cd3c6f67647b367e2501c014bb817208fbe10f185a58  Sources/TritonKit/Server/TKHierarchyBuilder.swift
6efbe46349e36b3dbc6d328ea56f1db07c73f8d73194a97e6ea88d1ce587fc00  Sources/TritonKit/Server/TKLayerScreenshotCapture.swift
0e10afc5acc17e5e704a087f95dd6fad31b9efff551a525730715a0d2372b39c  Sources/TritonKit/TKRuntimeCapabilityGate.swift
e87410d0a20db6949d126218c090478a200dda9d9517b4096682dc7cb03f55b1  Sources/TritonKit/TKRuntimeUIHealthResponses.swift
5d3e8f7465ad75396d451a7ca79906b417c457749bc28e38a36937e754f5253a  Sources/TritonKit/TritonKitRequestHandler+HierarchyDetails.swift
042a9629376a1ebe6a76324a4eb5f6c3167b8b74e66f88a04abcf729a98b1821  Sources/TritonKit/TritonKitRequestHandler+LegacyInspection.swift
8e348f30358d768dca35f60a5bd986f20c90edd45f5fa4fd570192956640d472  Sources/TritonKit/TritonKitRequestHandler+Observation.swift
682cb608af9806193a79b9f913ab3e4c1dca1faeef772b700913f69d01a037a0  Sources/TritonKit/TritonKitRequestHandler.swift
a6f54dd6f8267294599b1b3db422d428a6bb0336e7191a9f755eb08d384e62dd  Sources/TritonKitCLI/CLIDebugCommands.swift
e6289b999d4197503477a760e470d5d95c92a0aa3ed2e54e8b3957f5404bbb39  Sources/TritonKitCLI/CLIHierarchyDetailsCommands.swift
9f9e7346f33eddfe8256d780027ab1800bb66c7965be2b09d7fa8a1743962f7b  Sources/TritonKitCLI/CLIHierarchyDetailsRuntime.swift
0cfec40f265852432dc442922bff6a3df6ed21d064ce9ec456f2b52bdc0bec2c  Sources/TritonKitCLI/CLIHierarchySceneRuntime.swift
cded8862e78abd1c9c8f9d4658591cb65cddc63270dbf9db1d5dbcd68cd6f2ff  Sources/TritonKitCLI/CLISchemaDebugCommands.swift
f442a32be7f35cf77d6afcdfa95c0f47759a4c0372e9d8b7e6b6d1fdd115c364  Sources/TritonKitShared/TKCLITransportSchemaModels.swift
ce194e41e8f83b506ce4f296684fa1731c467d3b827ada29958c173767fa8e2c  Tests/TritonKitTests/TKHierarchyDetailsAvailabilityTests.swift
c5d87cdcdccf9e05a51ab83ac3bda9295ea9744141e36f8889f2158fb10b311f  Tests/TritonKitTests/TKHierarchyDetailsTests.swift
2e9f3390e0c8be33cbceaa0fef148c8702a2828a6a18c87d0433ef2452a1fc7f  Tests/TritonKitTests/TKHierarchyScreenshotUploadTests.swift
613e5f89b7a61000fb2b834d5269d28af3c43d8f040a6f6c9aaf77ce7fc74c35  Web/design/LayerScene.tsx
c8cde160358d70493e00af336f1de88c2ecfe57514436f8c9a7830c3efb90033  Web/design/catalog.tsx
f5b07e5f1bc53be8812aaee7450266e012eb550be9f744cccc1198b863c7cdfc  Web/dev/hierarchyLayers.test.mjs
43d5c9b366ea41563dcf56c1d19f470f3e099d57c46cc1b3a8736dad863a97db  Web/dev/hierarchyMaterialPolicy.test.mjs
ca05ee97417ff01f19df884d4ca416cbe892fc33b5e91f5e271bd0c720607bc2  Web/dev/ios-bridge/hierarchy.mjs
4eef4448640a2a200602e3187e13ad3d67309cd83590c3f3a2bb794670a61216  Web/dev/ios-bridge/hierarchyRoute.test.mjs
0c23fa62c66101034d3ccd1753217f22e02865d918245130aeb06140f9b03077  Web/dev/rhineInspector.test.mjs
5613efc64f923413c6f9dcd9cc4bd1bf4a25581d0970ff406b57753b078b0be8  Web/dev/rhineReview.test.mjs
488d228ca6b88aa78cf7a90707312f2c3b535aac2dc39e019de554e98a491e3b  Web/package.json
6d41137057dbeca83c4b4c078b188214126a964ce955b220314f9ac2cf098f6b  Web/src/components/HierarchyLayers.tsx
7d4e9fd293ef1e708dc46af7331c1b9c3d8efa0111f31270c2968f8275ed35cb  Web/src/components/InspectorPanel.tsx
37f18bb587c81b2bbf9dec67e7c0b380c3b160c3cffbd431f0c94b93b4c44b30  Web/src/components/NodeImageEvidence.tsx
9ff6ca72f23f211401abe8df8ace6f396c66356f74abff88eeadb7419fd5ce3c  Web/src/components/hierarchyLayers.css
404aae145a20269d79695a7ee5dbdd529639bf98abbe574c5c2c305b126e9ff8  Web/src/data/hierarchyMaterialPolicy.ts
eca6956f8d5af8cb12c1a295ca9c50b6ed0567c8a1a2b741d71dd39713a0d0d3  Web/src/inspect/layerPlanes.ts
```

## 补充审阅依赖 SHA256

```text
c10e214858726669c09db2e7d07ba0ea51d49e26728da64f274e452f91421b79  Sources/TritonKit/TKRuntimeSupport.swift
cf18496400c664ff6b988cd39be8302cfd9452bcc56cb0116df8cc6234859e84  docs-linhay/spaces/SP-270-lookin-core/README.md
501c24e96a8773a9780c4e6c6389b146654307273ab038262158249cc62d3d37  docs-linhay/dev/20261103-lookin-core-inspection.md
a8fa9adf733bc3828ffab60ad4047ba5f55dc9d068fd7f0bbfd9a8f99b0c52ac  docs-linhay/spaces/SP-270-lookin-core/plans/20261103-validation.md
f74d13971c4b4351c0d9532b36e57382c18a79d7659775b4261779d5beb182fc  docs-linhay/spaces/SP-270-lookin-core/plans/web-design.md
ae2b49bf69fb31df5ef926f6a65e6a74b262311443d71cec6ddab45688d0aa87  docs-linhay/scripts/public-skill-command-schema.json
```

本轮无新增可复用流程规则；既有 Lookin 技术说明与 EXPERIENCE 已覆盖双图语义、availability、预算和真实UIKit验证边界。将本独立证据交由主控纳入最终交付即可，不重复改写原历史。
