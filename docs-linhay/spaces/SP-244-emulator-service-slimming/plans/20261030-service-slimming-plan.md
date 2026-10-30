# Android / Harmony 非必要功能裁剪方案

## 目标与证据边界

目标是在保持模拟器和业务 App 可用的情况下，减少非必要功能的常驻进程。方案借鉴 iOS 的功能目录、依赖保护、变更回执与按原状恢复，不照搬 launchd 服务名。

2026-10-30，主仓 `main@30185dc2`；本轮候选仅文档。Android Emulator 36.6.11.0 / API 34 arm64，guest RAM 2560 MB；HarmonyOS 6.0.2(API 22) / software 6.0.0.130，guest RAM 4096 MB。开始时 macOS 24 GiB，两个宿主进程 footprint 分别约 7.3G / 4.9G。期间其他任务重启了 Harmony，因此新 guest 样本不能与旧宿主 footprint 拼成前后优化对比。

Triton 0.2.36 的 `status/doctor/capabilities/schema --command device.start/plan` 和两端 `device doctor` 已核对。当前没有 Android/Harmony 的 `resource`、系统服务枚举或停服恢复契约；本报告因此使用只读 `adb -s <serial> shell ...` / `hdc -t <target> shell ...`、安装工具帮助及当前镜像配置作为 fallback 证据。下面关闭/恢复命令是计划，均未执行。

## Android：首选普通 UI / 网络回归 profile

一次 `dumpsys meminfo --oom` 的 PSS 区段，以及 `dumpsys package <package>` / `settings get secure assistant` / `settings get secure voice_interaction_service` / `dumpsys bluetooth_manager` 的只读核对得到：

| 功能 | 精确包名/组件 | 初始 guest PSS | 适用条件 |
| --- | --- | ---: | --- |
| Google 搜索、语音助手 | `com.google.android.googlequicksearchbox` 的 search + interactor | 185022 KiB，约181 MiB | 不测试搜索、语音助手、Assistant；此包当前确实担任相关 provider |
| YouTube | `com.google.android.youtube` | 59144 KiB，约58 MiB | 不测试 YouTube App 与对应外链路由 |
| YouTube Music | `com.google.android.apps.youtube.music` | 35971 KiB，约35 MiB | 不测试音乐 App 集成 |
| 数字健康 | `com.google.android.apps.wellbeing` | 25220 KiB，约25 MiB | 不测试使用时长、专注模式 |
| 蓝牙 | `com.google.android.bluetooth` + Bluetooth HAL | 27636 KiB，约27 MiB | 当前 ON、未连接、0 BLE app；不测试蓝牙/BLE |

四包合计约298 MiB，加蓝牙约325 MiB。这是候选进程的当前占用量，不是已实现的净节省。缓存进程、共享页分摊和采样时刻都会影响结果。主控随后按两个真实 PID 复核搜索/助手，读到142370+29147 KiB，说明不能把首次样本固化为保证值。直接 `dumpsys meminfo <base-package>` 对只有冒号后缀的进程可能返回 `No process found`；应先枚举 PID，再按 PID 或读取全局 PSS 区段。

### 关闭与原状恢复

以下语法由本机 `pm help` / `cmd bluetooth_manager help` 核对；两者帮助内容有效，但返回255，不能把帮助退出码当执行能力验证。实际调用仍需核对命令结果、目标状态和业务后置条件。

```bash
# 精确选择目标并重新记录 enabled 原值、角色/默认provider与蓝牙原状态后执行。
adb -s <serial> shell pm disable-user --user 0 com.google.android.googlequicksearchbox
adb -s <serial> shell pm disable-user --user 0 com.google.android.youtube
adb -s <serial> shell pm disable-user --user 0 com.google.android.apps.youtube.music
adb -s <serial> shell pm disable-user --user 0 com.google.android.apps.wellbeing
adb -s <serial> shell cmd bluetooth_manager disable
```

现场 User 0 的原 `enabled`：YouTube=1，其他三包=0，蓝牙=ON。若执行前仍相同，恢复如下；若不同，必须依实际记录生成恢复命令。

```bash
adb -s <serial> shell pm default-state --user 0 com.google.android.googlequicksearchbox
adb -s <serial> shell pm enable --user 0 com.google.android.youtube
adb -s <serial> shell pm default-state --user 0 com.google.android.apps.youtube.music
adb -s <serial> shell pm default-state --user 0 com.google.android.apps.wellbeing
adb -s <serial> shell cmd bluetooth_manager enable
```

包禁用优于 `force-stop` 的原因是后者不构成持久功能关闭，可能再次被唤起。本方案不卸载、不清数据、不修改系统分区、不升级 root。恢复仅恢复本次变更且当前值仍符合回执的条目；保留执行期间用户或其他任务的新改动。

### 需要显式选择的扩展项

| 功能/包 | 初始 guest PSS | 关闭会影响 |
| --- | ---: | --- |
| 短信 `com.google.android.apps.messaging` | 约58 MiB | 短信/RCS/短信 Intent 与默认短信角色 |
| 系统智能 `com.google.android.as` | 约36 MiB | 文本/内容预测等系统智能能力 |
| TTS `com.google.android.tts` | 约12 MiB | 朗读、TTS、无障碍测试 |
| 广告隐私 `com.google.android.adservices.api` | 约6.5 MiB | 广告/隐私沙盒 SDK |
| 三个打印包 | 当前未运行，无即时进程收益 | 打印；只可能减少未来唤醒 |

上述包原 enabled=0；如采用同样 `disable-user`，原状恢复用 `default-state`。打印包为 `com.android.printspooler`、`com.android.bips`、`com.google.android.printservice.recommendation`。不默认关闭 GMS/GSF、WebView、Chrome/Custom Tabs、IME、Launcher、SystemUI、网络栈、权限/密钥/安装组件、业务 App、instrumentation 或屏幕串流。

## Android：启动级功能裁剪

| 功能 | 已核对关闭方式 | 当前证据与优先级 |
| --- | --- | --- |
| guest Vulkan | `-feature -Vulkan` | 不依赖 Vulkan 的 UI 回归可做单变量实验；当前 GLES 自身使用 ANGLE/SwiftShader，关闭 guest HAL 不保证移除宿主 Vulkan 后端或释放大块堆 |
| 后置相机仿真 | `-camera-back none -camera-front none` | 当前后摄emulated、前摄none，相机链PSS约8.4 MiB；不测扫码/拍照/相机上传时可关闭；恢复原参数 |
| 快照功能 | `-no-snapshot` | 本机帮助明确禁用加载/保存；减少恢复旧后台状态的机会，收益未知，启动变慢；恢复原启动参数，不能删除已有快照 |
| netsim Web/CLI UI | `-netsim-args '--no-web-ui --no-cli-ui'` | 本机help支持，整个netsimd宿主footprint仅5601 KiB，优先级低；保留无线/网络功能，不杀netsimd |
| 音频、窗口 | 已有 `-no-audio -no-window` | 无新增收益；headless仍渲染，guest音频进程存在不代表宿主参数失效 |
| 传感器 | 对应 `hw.sensors.*` 配置 | sensor HAL仅约1.3 MiB，已有2个accelerometer connection；不进入默认裁剪，避免姿态/传感器回归变化 |

当前 Triton 启动契约可规划 headless、GPU、RAM、no-snapshot-load、no-audio，但未覆盖上述全部原生 flags。未来实现应先补 schema/plan/receipt，再封装经验证的原生 argv；不要把未接入参数写成可运行的 `triton` 命令。启动级变更需测试空闲后冷启动验证；本轮未修改当前 AVD。

## Harmony：独立功能开关与维护模式

对实际HarmonyOS 6.0.2镜像中的 `/system/etc/init/*.cfg` 与 `/system/profile/*.json` 做只读解析，并在其他任务恢复在线期间用 `ps` / `hidumper --mem --prune` 核对运行状态。首次offline时及主控稍后复核时，HDC返回 `[Fail][E001005]`，尽管exit=0；这些失败调用没有产出guest证据。

| 功能/service | 样本guest Total PSS | 依赖与适用边界 |
| --- | ---: | --- |
| 相机 `camera_service` | 13757 kB，约13.4 MiB | SA3008，run-on-create=true，无显式critical/ondemand；不测扫码/拍照/视频会议时列首批候选；另有camera_host3648 kB，不假定联动退出 |
| 音频 `audio_server` | 18052 kB，约17.6 MiB | SA3009/3001，run-on-create=true、condition启动；on-stop会stop audio_host（另2838 kB）。不测音视频/录音/通话时可选，恢复须覆盖原先运行的依赖 |
| 统计 `hianalytics` | 13192 kB，约12.9 MiB | SA65777，run-on-create=true，无显式critical/ondemand；不测统计/HMS相关行为时可选 |
| 传感器 `sensors` + `sensor_host` | 4607+2182 kB，约6.6 MiB | 收益小，可能影响旋转/运动传感器，不入首批默认项 |
| 诊断 `hiview` | 30414 kB，约29.7 MiB | boot启动；故障/回归诊断仍依赖它，默认保留 |

首批no-camera/no-audio/no-analytics三个功能约44 MiB候选Total PSS，未含另列的HAL。hianalytics样本中SwapPss为11580 kB、hiview为19300 kB；不要重复加到总额中当节省。此前包含HAL、传感器、诊断的大范围观察约85 MiB，不代表建议全关。

### 已核对机制与权限缺口

本机二进制与 `begetctl --help`、OpenHarmony 6.0源码支持以下机制；没有执行停服或恢复：

```bash
hdc -t <target> shell begetctl service_control stop camera_service
hdc -t <target> shell begetctl service_control start camera_service
```

对应的白名单候选为 `audio_server`、`hianalytics`；每次只关闭一项。当前HDC shell为uid2000，读取 `startup.service.ctl.camera_service` 等状态返回1002（上游6.0对应SELinux拒绝）。读取权限与写权限不同，因此结论是“命令存在，当前shell控制权限和停服/恢复未验证”，不能声称已能执行，也不能只因groups未列servicectrl就判定具体DAC规则。

在设备独占的维护时段，先验证镜像允许的开发者服务控制权限和可读回通道，再执行临时stop/start；不关闭SELinux、不改保护策略、不用裸kill替代。保存服务与受影响依赖的原运行集合，原来未运行的服务不在restore时强行拉起。`audio_server`的on-stop联动必须在回执中包含audio_host；start成功也不证明内部音频会话已还原。显式stop可避免普通退出自动重启，但其他系统调用方仍可能重新启动服务，应观察稳定期与业务调用后状态。

### 无即时收益与禁止默认裁剪的项目

- 打印、扫描、大模型/AI、云备份和游戏native候选多数已按需启动且当前未运行：`large_model_engine`、`aiengine`、`ai_dispatcher_engine_service`、`print_service`、`cupsd`、`scan_service`、`sane_service`、`gameservice_server`、`gamecontroller_server`、`cloud_backup_service`。大多ondemand=true / run-on-create=false；cupsd受print.cupsd.ready触发。不把“清单长”算收益。
- `intell_voice_service`当前也未发现进程；蓝牙只有约1.5 MiB的blue_host，未核实通用shell框架开关，不作主要方向。
- `com.huawei.hms.adsservice`约31.6 MiB、`com.huawei.hmsapp.intelligent`约27.2 MiB、`com.huawei.hms.pafservice`三进程约79 MiB、`com.huawei.hms.pushservice`约29 MiB，合计约167 MiB。它们是不可移除系统HAP；当前bm help无disable/enable，aa force-stop只证明瞬时终止、不证明禁止拉起或可恢复。PAF具体职责未完整确认，推送有明确业务依赖，因此不进入默认自动裁剪。
- 默认保护hdcd、foundation、samgr、render_service、sceneboard、输入法、网络、nwebspawn、安全/凭据/存储、device_manager与softbus_server。SceneBoard、EngineService、输入法虽大，直接停掉会破坏UI与输入。
- 原生Emulator的完整help确认 `-create ... -memory <2~32 GB>`；这是创建参数，纠正了初始只看设备预设而未找到低于4GB支持的不足。它不证明现有实例改RAM已验证，也不是本次功能裁剪的替代方案。

建议最终profile结构：`stock`仅观察；Android `ui-minimal`按能力选择包与蓝牙；Harmony `maintenance`显式no-camera/no-audio/no-analytics；每项保留目标、镜像、依赖、原状态、实际结果和restore回执。当前只是方案，不存在已实现的跨端resource CLI。

## guest 内存释放与宿主内存下降

Android 当前 `/sys/bus/virtio/drivers/virtio_balloon/` 无设备绑定，23个virtio设备的driver链接也未发现balloon。`page_reporting_order`节点存在但读取被拒；这不证明free page reporting正在工作。guest当时MemTotal2537912 KiB、MemAvailable636640 KiB，另有guest swap使用。

因此必须分别验收：功能关闭、进程PSS下降、业务回归、宿主footprint下降。Linux的free page reporting可向hypervisor报告空闲页，但不能从通用机制推导当前Android Emulator或DevEco已支持。原生QEMU子二进制的只读`-device help`探测退出-6，未取得可用接口证据，本轮不建议注入未经验证的balloon设备或调用内存清空工具。

## 单变量验证与恢复流程

1. 绑定平台、镜像版本、目标、boot身份、宿主PID/启动时间；确认当前无其它任务正在执行会受该候选影响的流程。
2. 保存原配置/原enabled、角色、服务运行状态与关闭后期望值。先做一项，不能一次停几十个未知服务。
3. 同一业务负载采样稳定期的guest PSS/SwapPss、宿主`vmmap -summary` footprint、系统swap与压力；至少保留基线、处理后、恢复后三组，不能将不同启动/业务负载拼成节省率。
4. 关闭后验证进程是否消失/重生、ADB/HDC与网络、启动、输入、截图、WebView等受保护行为。只退出码成功不够。
5. 若服务被拉起、依赖报错或收益不稳定，退出默认profile；恢复必须读回，不以命令已发送当恢复完成。
6. 下一轮冷启动检查是否保留设置、是否再次唤起服务；会随镜像更新变化的项目重新发现，不永久写死跨版本清单。

## 外部依据

- [Android ADB：包启用/禁用命令](https://developer.android.com/tools/adb)：与本机help共同核对包管理语法，非本次停用验收。
- [Android Emulator 图形排查](https://developer.android.com/studio/run/emulator-troubleshooting)：不需要Vulkan的GLES应用可以禁用Vulkan；不能据文档推导具体节省量。
- [AOSP emulator feature定义](https://android.googlesource.com/platform/external/qemu/+/emu-master-dev/android/data/advancedFeatures.ini)：Vulkan guest HAL与图形后端分开判断；本机36.6.11行为仍以启动日志和验证为准。
- [Linux free page reporting](https://cdn.kernel.org/doc/html/latest/mm/free_page_reporting.html)：guest空闲页返还需guest与hypervisor协作，不等同关闭进程。
- [OpenHarmony 6.0服务控制实现](https://raw.githubusercontent.com/openharmony/startup_init/OpenHarmony-6.0-Release/services/begetctl/service_control.c)：start/stop机制及返回码局限；商用镜像权限须另外核对。
- [OpenHarmony 6.0参数错误码](https://raw.githubusercontent.com/openharmony/startup_init/OpenHarmony-6.0-Release/interfaces/innerkits/include/param/init_param.h)：1002为SELinux拒绝，不能把exit0当状态读取成功。

## 验证状态

已完成：两端真实只读观察、当前工具帮助、Android关闭/恢复语法与候选状态核对、Harmony当前镜像服务与权限边界核对、官方资料。未执行：功能关闭、恢复、裁剪后业务回归和宿主净节省量实测。当前设备有其他任务使用，因此本次交付可操作方案，未进行停服或权限调整。

主控在Harmony离线后尝试一次Triton原配置启动，返回`emulator_exited_early`，日志为实例已运行；随即发现其他任务正在以`-hvd`恢复同一设备，未重试、未清理lock、未停止该进程。进程发现必须同时覆盖`-start/-hvd`或直接匹配可执行路径。后续再次offline不影响此前真实样本的历史事实，也不能将该样本标为当前在线状态。

## 2026-10-30 实施验证追加

用户追加授权验证后接入项目；实现位于 SP-244 独立 worktree。实际操作保持单目标串行，原 Android emulator-5556 检测到 active instrumentation，因此没有裁剪该实例；改用原本未运行的独立 emulator-5554。Harmony 使用原本未运行的第二个 HVD/10101，完成探测后通过 `triton device stop --skip-launchd` 退出；没有重置原 HVD/10100。

### Android 命令级闭环

在独立 API 34 AVD 上确认无 active instrumentation。保存 4 个包的 enabled 原值与蓝牙当前态后，顺序禁用 assistant/youtube/music/wellbeing/bluetooth，再按原值恢复。全部 5 项读回匹配；ADB ready、显示信息、PNG 截图有效。YouTube 原值为 1，其余三包原值为 0，恢复使用 enable / default-state。

候选 guest PSS：关闭前 564,943,872 bytes（约538.8 MiB），关闭后 1,095,680 bytes（约1.0 MiB，蓝牙 HAL 仍存活），差 563,848,192 bytes（约537.7 MiB）。恢复后即时 PSS 为46,086,144 bytes；恢复的是功能状态，不强行重建已终止的缓存进程。此轮没有配对宿主 footprint，不将这537.7 MiB声明为macOS节省量。

真实格式修正必须进入 fixture：`dumpsys package` 当前状态只取顶级 Packages 段，后续 Queries 的 User 0 不属于包状态；`dumpsys meminfo --oom` 是 RSS/PSS 两个 OOM 分组而非 Total PSS by process；分类汇总不能重复加到子进程。Bluetooth 成功输出实际为 `BluetoothShellCommand: Exec disable` 与 `disable: Success` 两行，enable 同理；必须结合当前状态读回，不能只匹配任意 Success。第一次预检失败时尚无副作用，已保留失败证据。

### Harmony 权限探测

guest `const.product.model/name` 均为 emulator，software version 为 emulator 6.0.0.130(SP7DEVC00E130R4P11)。`/proc/sys/kernel/random/boot_id` 与 `/proc/cmdline` 返回 Permission denied；`startup.service.ctl.camera_service` 与 const.boot.sn 返回 errNum 1002，shell uid=2000。HDC 随后离线；唯一实际发送的停服探测得到 Device not found or connected，未到达 guest，不算权限写验证，也不算停服成功。没有自动 root、关闭 SELinux 或强杀系统进程。

因此商用镜像的 camera/audio/analytics 当前只提供可用性诊断，apply必须拒绝；开发镜像的正路径目前是fake-runner覆盖，不能声称已经在商用镜像关闭并恢复成功。

### 新 CLI 与冷启动闭环

新 CLI 的 doctor/plan/apply/verify/measure/restore 全部成功，恢复后 verify 再次成功。即刻测量（同PID46832）guest allowlist PSS 489,604,096→130,616,320 bytes，host footprint 5,547,464,680→5,551,445,992 bytes，即host增加3.8 MiB，没有回收证据。该allowlist含9项候选，和手动首轮只统计首批5项的口径不同，不能横向直接比较。

另做相同 AVD/RAM/软件图形配置的两次冷启动，均禁用快照且ready后30秒采样：

| 配置 | VM PID | guest allowlist PSS bytes | host VM主进程 footprint bytes |
| --- | --- | --- | --- |
| 原开关状态 | 14473 | 760303616 | 5488220184 |
| ui-minimal | 16443 | 251370496 | 5230368864 |

冷启动host下降257,851,320 bytes（245.9 MiB，4.7%，5.11→4.87 GiB）；guest下降485.4 MiB。只有一次配对样本，不保证其它负载、镜像或原emulator-5556获得相同收益。控制面/包开关跨boot核对与原值恢复通过。主页与设置页PNG已目视检查有效；首次即时HOME截图为转场黑帧，不以其PNG存在作为UI验收，后续稳定截图补齐。独立Android实例在恢复后退出。

Triton-first启动验证发现旧device.wait-ready在目标offline阶段可立即返回错误；观测重试有界，未自动重放写操作。旧device.start的--no-snapshot-load在紧邻stop后碰到snapshot pending；最终对照使用原生-no-snapshot（禁用load/save），本机-help已确认语义，sourceCommand已记录。此fallback仅用于独占试验，没有删除AVD锁/快照或改动原活动实例。

### 构建与测试

- feature worktree完整CLI：148 XCTest +1599 Swift Testing，共1747项通过。覆盖新增75项及全局schema/snapshot/recovery taxonomy。
- main同步28个文件后运行verify.sh --local：root XCTest7+Swift Testing401、release CLI build、release CLI smoke、fake Harmony host smoke、mock iOS runtime observe、docs/diff均通过。Swift调用限jobs=2并使用native build system；iOS Simulator/Xcode build以TRITON_VERIFY_XCODE=0跳过，本切片无UIKit/平台UI改动，仅CLI与shared schema纯函数。
- verify.sh --ci-docs、check-docs.sh、git diff --check通过。
- 修复的反证包括包状态跨段误读、OOM右对齐缩进、蓝牙成功回执、部分apply的verify误报、receipt依赖顺序、receipt发布临时硬链接，以及schema字段/恢复分类/公共命令snapshot漏接。

### main release Harmony拒绝路径实测

最后使用main新构建release CLI启动独立HVD/10101，wait-ready成功。doctor身份bootID=unavailable，camera_service/audio_server/audio_host/hianalytics全部available=false、resource_permission_denied。custom plan正确partial；apply camera --confirm退出1，resource_state_unavailable，未创建receipt。measure成功读取四服务PSS：18,420,736 +2,876,416 +14,095,360 +14,314,496 bytes；hostMemory因宿主参数无法唯一确认而partial，未冒充0或成功宿主采样。随后精确停止自有HVD并确认PID已退出。
