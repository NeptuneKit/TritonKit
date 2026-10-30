# SP-244 Android / Harmony Emulator Service Slimming

## 当前状态

第九轮已验收并收口到本地main：[PNG采用与整合证据](plans/20261030-png-adoption-commit.md)。用户接受带宽代价，Android预览采用原始PNG直通；真实Settings四轮对照，HTTP采集进程峰值中位18.99→8.56MiB，持续中位少0.55MiB，payload增加9.87%。这是预览进程收益，不是VM减少；第八轮约18%是另一组图像样本。

CLI1819项（含3条件跳过）、Web156项/build、root408及本地门禁通过；真实Android源码代理/仓库外解包版的双订阅、隐藏停止、恢复重连、最后卸载与原生WKWebView通过。当前候选未重新实测Harmony/iOS设备矩阵或完整Wails壳；第六/八轮真实证据保留其候选边界。所有本轮自有测试资源已清理，未push/tag/release、未接替用户运行服务。

本地整合包含第1–8轮已验证实现与本轮PNG，保留并行Rhine UI与其它任务WIP。长期契约见[资源管理与预览](../../dev/emulator-resource-management.md)；此前“未提交”属于各轮当时状态，由本轮本地提交接续，历史报告不回写成新候选验收。

| 范围 | 已交付或裁决 | 证据 |
| --- | --- | --- |
| 功能裁剪 | Android五项关闭/精确恢复、冷启动核对；Harmony商用权限不足只诊断并拒绝写入 | [首期](plans/20261030-service-slimming-plan.md) |
| 启动选项 | no-snapshot/disable-vulkan显式可选；host GPU配对曾少447.6MiB，波动不作保证；lowram缩RAM/ANR排除 | [第二/三轮](plans/20261030-github-memory-options.md) |
| 缓存实验 | zRAM、ArkWeb未证额外host收益；停止预览有效但不承诺固定VM下降 | [第四轮](plans/20261030-deep-options-validation.md) |
| 预览生命周期 | 自动隐藏暂停/显示重连；三端packaged、SDK定位与iOS主屏绑定 | [第五轮](plans/20261030-preview-auto-pause.md)、[第六轮](plans/20261030-harmony-packaged-preview.md) |
| 继续减内存 | Node背压、direct iOS引用释放、Android -avd识别；硬件组合因蓝牙崩溃拒绝 | [第七轮](plans/20261030-further-memory-candidates.md) |
| 编码峰值 | iOS逐帧pool的连续编码夹具峰值198→57MiB，普通节奏无稳定收益；PNG候选已由第九轮采用，HWUI仍待净收益验证 | [第八轮](plans/20261030-preview-memory-budget.md) |

下一步依次量化按订阅仲裁采集FPS、PNG缓冲生命周期、稳定host负载下HWUI净收益；均未增加开关。guest释放、预览队列、编码峰值与VM footprint不能相加。

## 边界与工作区

- 首期影响层：CLI host adapter、shared schema恢复分类、public skill；不新增HTTP/Web/桌面控制面。产品不隐式缩RAM/分辨率或修改业务App；lowram反证仅在自有AVD进行，容量与功能已恢复。
- 原活动Android存在instrumentation，实际操作只覆盖主控新启动的独立AVD与第二个Harmony HVD；Android恢复后退出，两次独立Harmony探测均退出。
- 分支 `feat/SP-244-emulator-service-slimming`；worktree `../TritonKit-worktrees/SP-244-emulator-service-slimming` 保留验证环境。本space拥有的CLI与共享helper已同步主工作区；Web保留SP-246/SP-247的新界面，未用旧worktree界面覆盖。此前checkpoint见各轮记录；本轮按精确文件清单在main提交，工作树保留，无远端写入。
- 参考 [SP-177](../SP-177-ios-simulator-resource-management/README.md) 的 plan/apply/verify/restore 模式；两端使用各自真实服务清单，不套用iOS标签。

## BDD 与验收

- 明确本机emulator与清单后，plan只读取当前状态、影响与不可用原因；未知条目或不完整原状态拒绝apply。
- apply确认后，首次副作用前写入私有receipt；每步核对身份并读回。跨进程目标锁、整组依赖intent与原子持久化保护恢复。
- restore只恢复receipt拥有且当前仍匹配的条目，冲突不覆盖；Android精确恢复enabled 0–4与蓝牙原状态。Harmony依赖反序恢复且要求同一boot。
- 未完成pending/intent/conflict的verify保留partial与失败，不能伪装成完整验收。
- 商用Harmony权限拒绝按真实正文识别，不能因HDC/begetctl exit0宣称成功；不root或修改SELinux。
- guest PSS与host footprint分开返回；控制状态验证不代表业务功能或固定宿主收益。

## 首期与二阶段验证（历史）

- 完整CLI 1757项通过（158 XCTest、1599 Swift Testing）；首期75项加二阶段10项，覆盖adapter、receipt、恢复、host采样、启动选项、命令与schema。
- 主工作区 `verify.sh --local` 在二阶段代码整合后再次通过：root测试、release CLI构建与smoke、fake Harmony host、mock iOS runtime observe、docs/diff。Swift构建限jobs=2；真实Bonjour隔离测试按既有开关跳过，iOS Simulator/Xcode build因无UIKit/平台UI改动跳过，不能声称真实iOS回归。
- `verify.sh --ci-docs`、`check-docs.sh`、`git diff --check` 通过。真实截图和完整日志保留在私有 `.triton/sp244-validation/` 与 `.triton/sp244-github/`，不公开业务图像。
- [功能契约与用法](../../dev/emulator-resource-management.md)、[方案与真实证据](plans/20261030-service-slimming-plan.md)、[当日日志](../../memory/2026-10-30.md)。没有提交、发布或定时任务。

## 二阶段补充验收

- 区分GitHub作者自报、源码实际实现与本机复现；固定来源commit/license，不运行上游安装脚本。
- 同一独立AVD保持RAM、分辨率和服务状态，只比较software/host GPU；记录实际renderer、host footprint、可取得的ready时间、截图与设置页。必要原生fallback保留Triton-first不足证据。
- lowram/缩RAM/缩分辨率与关闭服务分开，不把改变设备规格的混合收益归因于裁剪。lowram可能解除最低RAM约束，必须读取guest MemTotal；隔离实验显式指定相同RAM。Harmony当前活动目标保持只读。
- 新增Android启动选项 `--no-snapshot`、`--disable-vulkan` 均默认false；非Android拒绝；no-snapshot覆盖no-snapshot-load，不删除已有快照。plan包含完整参数与能力损失，计划不执行。相关解析/构造/schema和真实启动分别验收。lowram因真实ANR/容量变化反证及同RAM未见收益，撤回采用。
- 来源与分项证据见[GitHub研究与实验](plans/20261030-github-memory-options.md)。

## 第五轮：预览自动暂停（已验收，未发布）

用户明确授权将自动暂停加入项目并真实验证。影响层为现有Web mock预览组件、只读MJPEG订阅生命周期；必要时修正现有dev bridge取消，不新增设备写操作或HTTP控制接口，不改变Web mock产品边界。

BDD/契约：

- 给定已连接目标，页面变为hidden/pagehide，或预览窗格不可见/无尺寸/离开视口，则撤销该窗格的MJPEG请求；保留设备选择、FPS、检查状态和用户连接意图。
- 页面及窗格恢复可见后，自动建立新请求并显示新画面；初始隐藏不请求，重复可见通知不重复连接，卸载清理监听器和请求。
- 同一设备两个预览中，仅一个隐藏时另一个继续显示；最后一个预览隐藏后，后端采集停止。隐藏只影响预览，不停止设备、应用、录制、日志或其他订阅。
- 连接状态区分预览暂停/连接中/有画面，不把隐藏标为设备离线；变化中快速切换不得复用已取消请求或创建孤儿连接。
- 验证先失败单测，再实现/回归，Web全量test/build；真实浏览器可见性、窗格、重连和多订阅验证，结合至少一个独立真实模拟器采集活动检查。Android/Harmony共用前端路径，平台实测范围分别声明；不外推固定内存收益。

实现保留在SP-244 sibling worktree，验证后只同步本轮拥有文件。既有主仓SP-193/SP-207等并行差异不动；不提交、发布或停止其他任务服务。

第五轮真实重连反证追加：单次截图正常时，HTTP framebuffer可返回200却无帧。只读代码核实headers写失败前获取的订阅可能无释放、无帧循环未消费入站close、terminal session可能复用。范围追加现有Android/Harmony HTTP流和session生命周期窄修复，不增加路由或控制面；保留timeout后不自动重启，显式新订阅可创建新session。新增body未执行无lease、无帧断开清理、terminal后新订阅、迟到旧释放不影响新流场景。


第五轮结果：[自动暂停验证记录](plans/20261030-preview-auto-pause.md)。Web100项、CLI158+1605项、17项生命周期专项通过；真实Android浏览器16阶段/19断言通过，后台/双隐藏/最后卸载未再观察到截图，恢复后采集与画面恢复。修复了headers前取消、无帧断连和terminal session复用/旧释放问题。源码Web路径验收，packaged Android/Harmony既有路由缺口及iOS native未验收边界明确保留；未承诺固定内存收益。main local及两工作区docs/diff最终通过。自有测试服务已清理，模拟器因外部scrcpy使用而保留。


## 第六轮：鸿蒙与打包版（已验收，未发布）

用户追加授权实际验证鸿蒙和packaged模式，问题直接修复。范围/BDD/所有权见[第六轮计划](plans/20261030-harmony-packaged-preview.md)。

第六轮完成：鸿蒙源码及Android/Harmony/iOS仓库外打包版实际暂停/重连/双预览/最后卸载通过。修复packaged缺路由、SDK定位、重连重查询、Harmony分阶段超时，以及iOS最大surface误选8K黑图。最终CLI1800、Web142/build、加强iOS native1及main local通过；实际矩阵、失败反证、包hash和清理见第六轮报告。代码已接入主工作区，未提交发布；自有实例/服务清理，外部Android保留。


## 第七轮：继续裁剪内存

[完整记录与截图反证](plans/20261030-further-memory-candidates.md)：慢TCP消费者测试的Node队列积压63.46→0.17MiB；该数不是VM物理内存收益。直接iOS路由首帧前断开/未执行body的引用释放修复，Android宿主识别兼容`-avd NAME`。Android四轮硬件裁剪对照出现蓝牙崩溃、包状态与宿主负载漂移，因此不采用组合、不新增启动开关；一次性AVD已删除，外部设备未修改。鸿蒙camera宿主门禁仍为未实测候选，free-page reporting已开启不重复包装。

CLI1810项（含3项条件跳过）、Web153/build通过。首次全量的Vision OCR框架错误保留，相关23项及完整CLI原样复测通过；未修改OCR/跳过用例。七文件按hash整合main；main local通过，含iOS Simulator编译；最终文档检查结果见第七轮记录。

远端此前的仅编号登记由本次完整整合接替；登记历史保留于 `e6258339`，不将占位资料解释为当时已交付。
