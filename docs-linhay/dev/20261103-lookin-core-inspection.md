# Lookin 核心能力内置

关联 [SP-270](../spaces/SP-270-lookin-core/README.md)。2026-11-03 用户选择将核心能力做进 TritonKit 并沿用现有界面，替代外部 LookinServer provider 接入建议。本实现不依赖 Lookin 或 LookinServer，不复制其源码，也不兼容其 Peertalk/NSKeyedArchiver 协议。

## 入口与范围

embedded UIKit runtime 负责完整 CALayer 树、节点属性和截图；CLI/现有 HTTP request 负责读取，现有 Web 检查器消费只读 scene。已有 typed `debug patch-node`、对象元数据入口继续复用。不存在新 Web 写接口。

```sh
triton debug hierarchy --target <runtime-target> --json
triton debug details --target <runtime-target> --oid <oid> --screenshots both --max-pixel-count 262144 --json
triton debug details --target <runtime-target> --oid <oid> --screenshots none --json
triton schema --command debug.details --compact --json
```

OID 只在当前 App runtime 进程内有效，重启后须重新观察。详情 payload 为 `TKHierarchyDetailsRequest`，通过现有 `hierarchyDetails` 消息传输：1–8 个不重复且非零 OID，截图模式 `none|solo|group|both`，属性默认开启，每图像素默认 262144，上限 1048576。

## 图像与边界

- group 是当前层及其可绘制后代；solo 是隐藏直接子层后的当前层。同步 MainActor 事务禁用隐式动画，并用 `defer` 恢复每个子层原隐藏状态；不拆层、不重排，不在隐藏期间 await。
- 裸 CALayer 不再截断树。只有 `view.layer === layer` 才认定 UIView 身份，不能把任意 UIView delegate 当 backing view。frame 转换到所属 window；无所属 window 时保留可解释的局部树坐标。
- `soloScreenshotRef` 与 `groupScreenshotRef` 分开；旧 `screenshotRef` 保持子树兼容语义。上传失败保留原始 PNG，scene 的 inline 回退必须验证 PNG 和预算，不能把 group 当 solo。
- 按需详情每请求限制 4194304 像素、4194304 PNG bytes、节点/图像间 2 秒检查。单次 `CALayer.render` 或 PNG 编码不可抢占；这是协作预算，不是严格硬实时上限。
- 属性或几何成功、图像失败时返回部分成功；过期 OID 的默认零几何不算成功数据。消费方联合检查 `ok`、`partial`、`error` 和每项 `failureReason`。
- 详情需要 hierarchy capability；请求图像还需要 screenshot capability。Release 入口和采图 helper 均不采集。UI admission 超时保留 `outcome=unknown`，不能声称临时绘制尚未开始或自动重放。

## 只读 3D 视图

沿用检查器结构和固定 Rhine 包。图层树与平面共享选择，支持拖动/方向键旋转、层间距、Home 重置。最多展示 200 个可见平面；缺独立图像或图片加载失败时使用轮廓，并保留缺图提示。零尺寸结构父层不能误过滤有尺寸后代；明确 hidden/alpha=0 的祖先仍过滤。

当前是屏幕轴对齐 frame + depth 的分层投影，不能宣称完整复原 transform3D、透视、遮罩或合成器效果。Metal/视频/远程渲染等不能靠 `CALayer.render` 保证像素等价；SwiftUI 仅检查 UIKit/CALayer 所能表达的运行时层级。任意对象方法控制台、外部 Lookin wire、完整 SwiftUI 语义树均不在本切片。

## 验证与经验

macOS `swift test` 不运行 UIKit 分支。真实像素、裸层几何、状态恢复及属性回读必须在 App-hosted iOS destination 执行；Debug 宿主测试目标与 SDK 同时使用 `TRITONKIT_RUNTIME_ENABLED`，Release 单独证明不采集。

并行构建期间需冻结整个编译 module 的所有 Sources/Tests。只冻结被 filter 选中的测试不足以防止 Swift 编译输入变化；出现 `input file was modified during the build` 时，不能把该次编译失败当作 BDD 行为红证据。

新增 CLI 子命令同时更新 public skill command snapshot；schema 本身通过不代表分发文档门禁一致。验收进度和实际命令见 space 的验证记录。
