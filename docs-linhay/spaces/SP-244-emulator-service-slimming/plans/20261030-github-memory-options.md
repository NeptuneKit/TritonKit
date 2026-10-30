# GitHub 方案复核与第二轮内存实验

2026-10-30；接续[首期功能裁剪](20261030-service-slimming-plan.md)。用户要求继续寻找 GitHub 方案。范围仍为本机 Android / Harmony；不引入外部执行依赖，不安装第三方优化器，不改现有业务目标。源码阅读、作者自报和本机实测分别记录。

## 候选与采用结论

| 来源与固定版本 | 实际机制 | 本项目判断 |
| --- | --- | --- |
| [avdslim](https://github.com/kdbhalala/avdslim/tree/69dddfa73df713659f6cc90db5f65dfd7ebe9762)，MIT，2026-10-15 / v1.0.16 | macOS `-gpu host`；`-lowram`；1536 MB RAM；关闭音频、相机、动画；禁用系统包 | 分项复现GPU；lowram未通过同RAM收益验收，不采用；不直接运行优化器 |
| [serve-emu](https://github.com/jiunshinn/serve-emu)，Apache-2.0 | macOS 启动显式选择 host GPU，避免 headless auto 软件渲染 | GPU 机制与本机对照吻合；仅作检索入口，未复制源码 |
| [android-emulator-runner](https://github.com/ReactiveCircus/android-emulator-runner/tree/ed009f5318f15b1cf93a191b856c4f1748a2d4c1)，Apache-2.0，2026-08-26 | headless/no-snapshot/noaudio/no-boot-anim、ATD 镜像与自动化参数 | 可借冷启动与按需功能选项；其软件 GPU 默认值不适合直接照搬到 Apple Silicon |
| [try-omarchy HVF 补丁](https://github.com/omacom/try-omarchy/blob/fdffc8f4682a5adcfa2cf2a43ea4e5b4c1d59885/macos/patches/qemu-hvf-free-page-reclaim.patch)，仓库 MIT，2026-09-22 | free-page reporting 后 `hv_vm_unmap`、替换匿名 backing、`hv_vm_map`，真正释放 guest 已触碰的宿主页 | 进一步回收的重要研发线索；需定制 QEMU 与 guest 协作，不能包装成现有 Android/DevEco 参数。未移植代码；QEMU 衍生发行的许可另审 |
| [macos-vm-memory-ratchet 修正](https://github.com/arcboxlabs/macos-vm-memory-ratchet/commit/35b28f379daac60bb8af099ace5d41ba52a17453)，Apache-2.0，2026-08-13 | 独立 HVF 实验指出 ledger 下降来自 stage-2 unmap；中间 MADV_FREE_REUSABLE 没有贡献 | 不照搬旧 README 中单改 madvise 的解释；其页内容重访语义未完整验收 |

avdslim [bench 实现](https://github.com/kdbhalala/avdslim/blob/69dddfa73df713659f6cc90db5f65dfd7ebe9762/cmd/avdslim/main.go#L1432)硬编码 5600 MB footprint、2800 MB RSS 和 heap 512→256，不能用其百分比代替实测。[Issue #4](https://github.com/kdbhalala/avdslim/issues/4)也记录禁包后 host 上升，作者明确区分 guest 释放和宿主收益。它的 tune 还会删除快照，包恢复不保留 default-state；因此不采用一键执行链。

try-omarchy [PR #243](https://github.com/omacom/try-omarchy/pull/243)自报三轮释放 768 MiB 后宿主下降约718–742 MiB，但仅覆盖其 Linux headless VM / macOS 27，不是本机 Android 或 Harmony 复现。

## Android 引擎边界

- 当前 classic [balloon 源码](https://android.googlesource.com/platform/external/qemu/+/cf0f40a0aad1aa3fca68f2f89372525c8d28ca68/hw/virtio/virtio-balloon.c)（2026-10-27）仍只有 inflate/deflate/stats，未接 free-page-reporting；此源码尚未与已安装36.6.11二进制建立精确提交映射。
- [next 分支](https://android.googlesource.com/platform/external/qemu/+/f8106989754c7c88558905f4bb6b17b57a90c85c/hw/virtio/virtio-balloon.c)有 reporting 但默认关闭，尚未见上述 HVF 特殊回收路径。[官方预览说明](https://developer.android.com/studio/releases/emulator)要求新引擎使用 API37+，且 API37 最低4 GiB RAM；不能将升级承诺为节省内存。
- 上游 [QEMU virtio-mem](https://github.com/qemu/qemu/blob/v11.1.0/hw/virtio/Kconfig#L70)依赖 Linux host，不能套用到当前 macOS。
- 官方 release notes 的 Activity 泄漏修复在36.4.9，HVF关闭资源泄漏修复在36.6.11，均已包含于本机版本；不能据此诊断当前常驻量。
- [官方图形说明](https://developer.android.com/studio/run/emulator-acceleration)支持 `host`；[故障排查](https://developer.android.com/studio/run/emulator-troubleshooting)支持 `-feature -Vulkan`。后者关闭 Vulkan 能力，需要 Vulkan 的业务不能选择此项。

## Harmony 候选与权限边界

本轮未找到适用于 Apple Silicon / 商业HarmonyOS6.0.2 / DevEco Emulator6.0.0.130 的现成瘦身项目。以下是开源系统机制，不能等同于商业镜像可执行能力。

1. **服务自身空闲卸载**：[打印服务](https://github.com/openharmony/print_print_fwk/blob/abc04909493e0c17e4cb0afbef18222c2efe17a0/services/print_service/src/print_service_ability.cpp#L1835)按需启动，空闲退出；当前商业镜像打印进程本来就未运行，收益不能重复计算。[samgr](https://github.com/openharmony/systemabilitymgr_samgr/blob/b664566aea14f09bdd058ad2edfffe50369cc88f/services/samgr/native/source/system_ability_manager.cpp#L1658)限制单项卸载调用者身份，批量仅允许memmgrservice。不能发布普通shell任意停SA入口。
2. **开发镜像回收触发**：[memmgr门禁](https://github.com/openharmony/resourceschedule_memmgr/blob/860a64e32f4914bbc0f0baf87300df6fd9142b87/services/memmgrservice/src/mem_mgr_service.cpp#L335)要求debuggable与DUMP权限，相关purgeable编译选项默认关闭。保留为开发镜像待验证方向，不冒充商用能力。
3. **自建GUI精简产品**：[产品配置](https://github.com/openharmony/productdefine_common/tree/a11680784a8f6831c86f5b11d4cf2ff80674ebcf)可按组件和feature裁剪。官方[arm64最小产品](https://github.com/openharmony/vendor_ohemu/blob/7e21e37d5310c0e45ab12548da8241fe8c536e30/qemu_arm64_linux_min/config.json)关闭JS API且nographic/1024MiB，不适合当前GUI/HAP回归；1024MiB不是宿主实测。
4. **新镜像接通balloon**：官方[ARM64 full内核](https://github.com/openharmony/device_qemu/blob/434e755fdb46ea93df016b56eb4f3033823d36d4/common/virt_full/kernel/arm64_virt_defconfig#L7007)已开MEMORY_BALLOON/PAGE_REPORTING/VIRTIO_BALLOON，但[launcher](https://github.com/openharmony/vendor_ohemu/blob/7e21e37d5310c0e45ab12548da8241fe8c536e30/virt/qemu_run/arm64/qemu_profile.json)未挂balloon，默认4096MiB。可在独立开源镜像研究HVF回收，不证明商业DevEco已有接口。

[harmonyos_next_emulator_mod](https://github.com/wuxianlin/harmonyos_next_emulator_mod/tree/b43826cf68afdaeca2be45cb54eac87e64ec761d)是Windows x86/HarmonyOS5 API12的root修改，未见许可声明与可审查完整补丁，不适用于当前Mac。没有下载/执行。OpenHarmony vendor/device仓库元数据为Apache-2.0，但未完成整套镜像LICENSE/NOTICE与商业兼容审计，不宣称可直接再分发。

## 本机实验协议

- macOS27.0.1 / Apple M5 /24 GiB；Android Emulator36.6.11；独立 API34 arm64 AVD。持久配置不改，普通启动实际 RAM 2560 MiB，`MemTotal=2537912 kB`，1080×2400，density420。lowram未指定memory的反证样本改变了实际容量，不能纳入同RAM对照。
- headless/no-audio/no-snapshot；服务状态保持原值，未套用 ui-minimal。每次 ready 后等待30秒，采3次 VM 主进程 phys_footprint，间隔5秒。记录实际 GLES renderer、内存、分辨率、9项功能状态、设置页与PNG哈希。
- Triton-first事实与 `device.start --plan-only --gpu host` 已保存。原生启动仅因当前CLI尚未暴露 no-snapshot/lowram/disable-Vulkan；等待自有PID退出后才启动下一轮，不删除快照/锁。
- 数据与脚本在私有 `.triton/sp244-github/`；原始日志可能有私有路径/ADB密钥，不提交。原业务目标不操作。

## 第二阶段 BDD 与实现边界

- `device start` 的新选项须显式 opt-in、默认false；启动计划展示完整参数与能力损失，`--plan-only` 不执行。
- Android 允许关闭不需要的 Vulkan和完全禁用快照读写；Triton不额外注入memory/分辨率参数，不禁包、删除快照或改变GPU默认值。
- lowram原先列为待验证候选，实测后撤回采用：它取消引擎最低RAM约束，本机未启用 `ro.config.low_ram`。不能因CLI接受参数就宣称开启Android低内存策略。
- 非Android目标拒绝新增Android参数；解析、默认值、命令构造、参数组合、schema与真实启动分别验收。
- 本轮禁止将实验性引擎补丁、未知商用服务开关或批量禁包纳入默认profile。

## 结果

以下均为VM主进程 `phys_footprint` 的3次采样中位数，GiB=2³⁰ bytes；不是guest PSS，也不是整机所有辅助进程总和。

| 顺序 / 配置 | Guest MemTotal kB | Host GiB | 真实结果 |
| --- | ---: | ---: | --- |
| auto，未指定GPU | 2,537,912 | 5.1870 | GLES实际ANGLE+SwiftShader；设置页正常 |
| host GPU | 2,537,912 | 4.7499 | GLES实际Apple M5；设置页正常；9项服务状态与基线一致 |
| host + Vulkan关闭 | 2,537,912 | 4.8468 | 启动日志明确Vulkan disabled；设置页正常 |
| host + lowram，不传memory | 641,664 | 1.5385 | ready耗时122.3秒，蓝牙读回off，设置页截图出现System UI无响应；失败样本 |
| host普通重启 | 2,537,912 | 4.9041 | ready14.7秒，蓝牙自动恢复on；设置页正常 |
| host + lowram + memory2560 | 2,537,912 | 4.8674 | ready14.8秒；low_ram属性仍空，9项状态正常；未见额外收益 |
| host普通重启/结束恢复 | 2,537,912 | 4.8637 | ready18.2秒；9项状态与初始完全一致，设置页正常；实例已退出 |

首对GPU实验减少469,353,120 bytes，即447.6 MiB /8.4%；本轮只支持该配对结果。后续普通host启动落在4.86–4.90 GiB，说明不同boot仍有波动。后续实验期间另一个业务AVD被其他任务启动，且有构建活动，不能把不同阶段小差值当成统计稳定收益。Vulkan关闭没有证明独立稳定节省；lowram显式同RAM时与结束基线仅差约3.8 MiB，方向为增加。

不传memory的lowram虽然显著降低host，却改变了容量并产生ANR，不能采纳为“关闭闲置功能”的收益。`wait-ready`、app launch成功与PNG存在均没有发现ANR；必须目视截图或用UI断言完成验收。恢复为普通启动后RAM、蓝牙与设置页均恢复，未执行额外蓝牙写入。

### lowram反证的源码解释

[旧版main-common.c](https://android.googlesource.com/platform/external/qemu/+/ae9d18d2b6261179fbd57fffec720a04f7bfb053/android/android-emu/android/main-common.c#1179)先接受显式memory，再由lowram取消minRam下限，不设置ro.config.low_ram。当前实验中属性一直为空，符合此机制。

本机AVD写有 `hw.ramSize=2G`、`vm.heapSize=228M`。[旧整数解析器](https://android.googlesource.com/platform/external/qemu/+/4dff0e93c253e1bb326c178043c3fb876bac43f5/android/android-emu-base/android/base/files/IniFile.cpp#427)遇到剩余字符会回退默认值；[2026-06-24修复](https://android.googlesource.com/platform/external/qemu/+/f67e21922f62c964204146a5f92ee66a310afcf7)明确增加单位后缀支持，[官方37.1.11说明](https://developer.android.com/studio/releases/emulator)于2026-07-30列出该修复，晚于本机36.6.11。

源码推导：单位后缀回落0后，旧屏幕默认RAM256MB、最小heap336MB再将RAM抬到672MB，可解释约627MiB的实际MemTotal。但未取得本机二进制对应精确构建SHA，因此不把该推导写成已完整证明的运行内部链。持久配置未修改，未升级SDK；显式memory2560的对照已经直接证明本轮lowram没有独立功能裁剪收益。

### 接入结论

- 保留既有 `--gpu host` 显式入口，写入有实测依据的建议；不自动覆盖默认GPU。
- 新增 `--no-snapshot`（不读也不保存快照；覆盖no-snapshot-load）与 `--disable-vulkan`（不用Vulkan的测试才启用），默认false、非Android拒绝。二者不承诺固定内存收益。
- 不新增 `--low-ram`。不采用上游批量禁包、删除快照、root/drop_caches或固定benchmark。
- 未移植HVF补丁，未新建ATD/OpenHarmony镜像，Harmony商用权限限制仍在；这些方向保留为独立研发候选。

### 候选验证

- 新启动选项先取得未知参数/schema缺项的2项失败；实现后10项新增测试通过，覆盖默认、原生参数、强快照项优先、非Android拒绝、lowram不暴露、递归schema与plan-only无执行。
- 主工作区完整CLI测试1757项通过（158 XCTest、1599 Swift Testing），包含首期resource回归。构建使用native/jobs2，同一scratch串行。未改shared runtime或Web，未新增依赖。
- 主工作区 `verify.sh --local` 通过：root测试、release CLI build/smoke、fake Harmony host、mock iOS runtime observe、docs/diff。真实Bonjour隔离测试按既有开关跳过；Xcode/iOS Simulator build因本轮CLI范围通过TRITON_VERIFY_XCODE=0跳过。
- 新release CLI plan-only包含两个native flags且无执行；iOS/Harmony误用返回单一合法JSON错误；真实启动PID18490与measure定位一致，Vulkan日志确认disabled，9项原状态一致，设置页截图目视正常，Triton stop后PID完全退出。
- 源码研究不等同于引擎移植/商用Harmony停服验收。未提交或发布；原始source/截图/hash/命令日志保留私有目录。

## 第三轮：更底层的候选与反证

2026-10-30，用户继续询问“其他黑科技”。本轮为源码/本地SDK只读研究；没有设备动作、没有新增产品开关，不将以下候选写成已测节省量。

### 优先候选

1. **预览不用时停止采集，恢复时重连。** 当前项目Android/Harmony MJPEG采用定时截图，不是gRPC streamScreenshot。Android静止后仍约2.5FPS，Harmony仍约2FPS；HTTP的fps只限制推送，没有传进底层采集session。Web预览在connected时保持img连接，没有visibility/idle暂停。已有最后消费者退出后stop/cancel/清空JPEG的生命周期，可评估显式暂停与隐藏后断连；不能只降低推送FPS。来源：[采集器](../../../../Sources/TritonKitCLI/CLIAndroidHarmonyFramebufferService.swift)、[HTTP生命周期](../../../../Sources/TritonKitCLI/CLIServeCommand.swift)、[Web原型](../../../../Web/src/components/StreamCard.tsx)。收益首先是采集/编码开销，VM主进程内存收益仍需实测；没有发现已证实的断连泄漏。
2. **ArkWeb主动释放本应用缓存。** 本机SDK确认API14公开 `WebviewController.trimMemoryByPressureLevel`，可先用MODERATE请求释放可重建缓存。需要应用接入且引擎已初始化；不是HDC全局清理，返回void不证明释放了字节。源码：[NAPI入口](https://github.com/openharmony/web_webview/blob/ab5003e525708c593a37c9e60a7d17da27351671/interfaces/kits/napi/webviewcontroller/napi_webview_controller.cpp#L6875)、[初始化门禁](https://github.com/openharmony/web_webview/blob/ab5003e525708c593a37c9e60a7d17da27351671/ohos_nweb/src/nweb_helper.cpp#L1099)。应测H5反复打开/关闭后的PSS与host footprint，并验证页面状态与重新加载耗时。
3. **zRAM内存池碎片整理。** [内核compact接口](https://docs.kernel.org/6.8/admin-guide/blockdev/zram.html)整理压缩对象、释放分配器碎片页；先读mm_stat，`mem_used_total - compr_data_size`仅为碎片和元数据的粗上界。需已有权限与可写节点；[自动shrinker](https://android.googlesource.com/kernel/common/+/b0aa53810b1daf4e3cbafddbbb61f2e0bf16581e/mm/zsmalloc.c#2321)可能已完成同样工作。只有guest压缩池和host实测共同下降才接受收益；不为实验提权或重置swap。

### 不应包装成新收益的机制

- AOSP14 [goldfish配置](https://android.googlesource.com/device/generic/goldfish/+/bebb672576b05d95a05e29c6f249404dfa80ec8e/fstab.ranchu.arm#13)已用zRAM/LZ4；[CachedAppOptimizer](https://android.googlesource.com/platform/frameworks/base/+/android-14.0.0_r1/services/core/java/com/android/server/am/CachedAppOptimizer.java#244)的compaction/freezer默认true。运行时仍可能被配置/内核支持覆盖；读取null不等于关闭。冻结主要省CPU，RSS转入zRAM不等于宿主回收；不采用激进LMKD阈值换取应用频繁重载。
- gfxstream的[显示回调](https://android.googlesource.com/platform/hardware/google/gfxstream/+/49ee51f297118cd2e98c5f4867df556e8966562a/host/frame_buffer.cpp#1798)及[GL读回缓冲](https://android.googlesource.com/platform/hardware/google/gfxstream/+/49ee51f297118cd2e98c5f4867df556e8966562a/host/gl/readback_worker_gl.cpp#32)在1080×2400下有1份CPU+4份PBO，名义容量49.4MiB，取消时才释放。该数是源码容量推算，未与本机binary精确绑定；Triton当前使用截图循环，不能直接把这49.4MiB归为它的节省。
- 旧官方文档的read-only/Quickboot COW是同一AVD多实例机制；[当前平台覆盖](https://android.googlesource.com/platform/external/qemu/+/cf0f40a0aad1aa3fca68f2f89372525c8d28ca68/android-qemu2-glue/main.cpp#2029)因页大小/同步等问题在Mac默认关闭QuickbootFileBacked。ini写on不代表最终启用；不强开，也不能让Android与DevEco互享内存。
- Linux KSM依赖MADV_MERGEABLE；[Apple XNU advice](https://github.com/apple-oss-distributions/xnu/blob/xnu-12377.1.9/bsd/sys/mman.h#L199)不提供该项，不能照抄QEMU mem-merge作为Mac去重开关。
- Harmony [ESwap](https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/zh-cn/device-dev/kernel/kernel-standard-mm-eswap.md)把压缩页写往磁盘，需要内核/backing配置，增加I/O；[purgeable](https://github.com/openharmony/docs/blob/f41b9345badd47c7ab0c263344cd7f4b5a549afb/zh-cn/application-dev/kernel-enhance/purgeable-memory-guidelines.md)要求应用预先管理可重建缓存。二者都不是商用镜像现成shell一键释放，且未有本机host收益证据。

后续建议先做预览采集生命周期的可控A/B；ArkWeb仅在已授权应用接入时验证；zRAM先只读估算空间。当前首期/二阶段实现状态保持不变。
