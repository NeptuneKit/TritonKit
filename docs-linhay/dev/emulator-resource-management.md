# Android / Harmony 模拟器功能裁剪

来源：[SP-244](../spaces/SP-244-emulator-service-slimming/README.md)。首期功能裁剪影响层为 CLI host adapter，不修改 embedded runtime、HTTP、Web 或桌面 UI；后续预览自动暂停与打包版只读流的扩展见文末，仍不增加设备业务写操作。

## 操作入口

`triton device resource` 提供 `profiles`、`features`、`status`、`doctor`、`plan`、`apply`、`verify`、`restore`、`measure`。`--platform` 必填；目标操作要求明确 `--device`，不接受别名、真机或远端目标。`--adb`/`--hdc` 可覆盖工具路径，无新增环境变量。

```sh
triton device resource features --platform android --json
triton device resource doctor --platform android --device emulator-5554 --json
triton device resource plan --platform android --device emulator-5554 --profile ui-minimal --keep bluetooth --json
mkdir -m 700 resource-receipts
triton device resource apply --platform android --device emulator-5554 --profile ui-minimal --keep bluetooth --receipt "$PWD/resource-receipts/run-1.json" --confirm --json
triton device resource verify --platform android --device emulator-5554 --receipt "$PWD/resource-receipts/run-1.json" --json
triton device resource measure --platform android --device emulator-5554 --json
triton device resource restore --platform android --device emulator-5554 --receipt "$PWD/resource-receipts/run-1.json" --confirm --json
```

`stock` 为空清单，不代表恢复历史状态；恢复必须用 receipt。`ui-minimal` 在 Android 关闭 assistant、youtube、music、wellbeing、bluetooth；在 Harmony 为空，不默认停系统服务。`custom --disable youtube,music` 仅关闭指定功能。`--disable` 加入 profile，`--keep` 优先保留；未知、重复或空 ID 拒绝执行。

Android 额外选项为 messaging、tts、intelligence、adservices。每项 `impact` 说明测试损失；保持 GMS/GSF、网络、WebView、输入法、Launcher/SystemUI、安装权限与业务 App。`features` 是静态清单；实际可执行性以 `doctor/status/plan` 的 `states[].available/value/reason` 为准。

Harmony 选项为 camera、audio、analytics。audio 包含 audio_server 与联动 audio_host。商用镜像的 shell 常无法读取服务状态或 boot ID；该情况只提供诊断和内存读取，拒绝写入。不会自动 root、修改 SELinux 或关闭 HDC。开发镜像上的控制路径仍必须逐项读回，不能仅凭 begetctl exit 0 宣称成功。

## 恢复与失败边界

- apply 全量预检后先保存原值；每项写入前再次核对实例、镜像和 boot。receipt 文件采用私有权限、无符号链接读取、原子发布与 fsync；不覆盖已有 receipt。
- 同一平台和目标使用跨进程排他锁。receipt 在首次写入前记录 intent，进程中断或命令结果未知时仍能按原值检查恢复。
- Android 保留 enabled 的 0–4 原值，原来默认的包用 `pm default-state` 恢复；不会一律 enable。Bluetooth 保留 on/off。
- restore 只处理本 receipt 的 intent/applied/conflict 条目；当前值不同于 applied 和 previous 时报告冲突并保留后续用户更改。依赖条目按 catalog 反序恢复。
- verify 核对 receipt 当前阶段应有状态；pending/intent/conflict 即使读回相符也保留失败与 partial，不把未完成 apply 标记为成功。全部 applied/restored 才可完整通过；不表示整个 App 测试成功。
- 任一命令失败保持单一 JSON envelope；同时检查 `ok`、`partial`、`error`，不自动重试不确定的写入。

## 测量

`memory` 只列 allowlist 服务/包及其子进程 PSS，不公开其它业务进程。`hostMemory` 单独读取 macOS VM 主进程的 `phys_footprint`，不含辅助子进程；定位歧义返回 unavailable/partial。Harmony Total Pss 已包含输出展示的 SwapPss，不能再次相加。

候选 PSS、关闭后 guest PSS 差、宿主 footprint 差是三个不同指标。测量应绑定同一设备、VM PID、负载与采样阶段；本命令始终返回 `businessVerified=false` 与 `hostSavingsVerified=false`。没有已验证 balloon/page reporting 时，guest 内存释放不能保证宿主立即回收。此前观察的 Android 约325 MiB、Harmony 约44 MiB 是候选占用，不是节省承诺。

## 验证记录

2026-10-30 独立 API 34 AVD：相同 RAM/图形配置、两次均禁用快照并在 ready 后30秒测量，原配置 host footprint 5,488,220,184 bytes，ui-minimal 为5,230,368,864 bytes，降低245.9 MiB（约4.7%）。guest allowlist PSS下降485.4 MiB。运行中直接apply时host没有下降（约增加3.8 MiB），因此不能宣称即时宿主回收。单轮对照不是所有镜像/负载的固定收益。

Android配置跨冷启动保留，restore按原enabled与蓝牙状态通过；主页、设置页、HOME输入、截图实测有效。冷启动对照使用原生 `emulator @<AVD> -port <port> -no-window -no-audio -no-snapshot`，因为首轮实验时device.start仅暴露--no-snapshot-load（第二轮已补齐--no-snapshot），连续stop/start曾命中snapshot pending。必须先确认自有实例完全退出，不清理未知锁；启动flag属于device.start，不属于resource API。

真实运行与测试结果在 [SP-244 方案/实测](../spaces/SP-244-emulator-service-slimming/plans/20261030-service-slimming-plan.md) 写回；商业 Harmony 的权限失败不得升级为成功验收。

## 启动选项与第二轮结果

`device start --platform android` 增加两个默认关闭的选项，无新增环境变量：

- `--no-snapshot`：传原生 `-no-snapshot`，不读取也不保存快照；与 `--no-snapshot-load` 同用时只输出前者。不会删除已有快照。
- `--disable-vulkan`：传原生 `-feature -Vulkan`，只适用于不需要Vulkan的测试；保留GLES路径。非Android目标携带任一选项均在启动前拒绝。

```sh
triton device start --platform android --avd <name> --headless --gpu host --no-snapshot --plan-only --json
```

先核对已安装版本schema；上述新增项为当前源码候选，未发布。`plan-only` 只给计划，真实启动后仍需wait-ready、UI断言/截图与实际renderer验证。Vulkan是否关闭不能凭guest `ro.hardware.vulkan` 判断，本机该属性仍为ranchu，宿主日志才明确显示disabled。

GitHub方案拆分实测：同RAM/分辨率/服务状态下，software→Apple M5 host GPU的一对冷启动中位数为5.1870→4.7499 GiB，减少447.6 MiB（8.4%）。后续host样本4.86–4.90 GiB，不承诺固定收益；关闭Vulkan未证明稳定额外节省。

不新增lowram开关：本机36.6.11的 `-lowram` 取消最低RAM限制，未设置 `ro.config.low_ram`；单位后缀配置样本得到约627MiB guest并出现System UI ANR。显式memory2560后恢复正常容量，宿主约4.87 GiB，未比普通host多省。真正guest页归还macOS的HVF补丁需要定制引擎，当前没有接入。

固定源码、许可、源码推导与完整7轮数据见[GitHub研究/反证](../spaces/SP-244-emulator-service-slimming/plans/20261030-github-memory-options.md)。这些启动实验不与首期ui-minimal收益直接相加，组合收益尚未测量。

## 预览自动暂停

源码Web的实时预览在页面或窗格隐藏、离屏、无可见面积时断开MJPEG，恢复可见后沿用设备与FPS重连。Android/Harmony多个窗格分别持有订阅，仍有可见窗格时保留共享采集，最后一个退出才停止。此行为独立于`device resource`，不修改设备、应用或服务配置。第五轮的HTTP/浏览器/采集生命周期与当时交付范围保留在[历史记录](../spaces/SP-244-emulator-service-slimming/plans/20261030-preview-auto-pause.md)；该轮未覆盖的packaged Android/Harmony路由由下述第六轮实现接替，不将第五轮实测外推为新候选验收。


### 第六轮：源码与打包版预览契约

以下为当前已实现并完成本机验收的契约；平台/模式、候选版本及验证边界以[第六轮报告](../spaces/SP-244-emulator-service-slimming/plans/20261030-harmony-packaged-preview.md)为准；三端packaged最终通过，尚未发布。

- 源码Web和packaged模式均注册 `/web/android/mjpeg`、`/web/harmony/mjpeg`。源码模式由dev bridge转发到现有framebuffer端点；packaged模式直接使用进程内采集订阅，不依赖dev bridge或独立19421服务。打包版缺少目标或非法FPS返回JSON错误，不落入SPA页面响应。
- 两种模式复用现有SDK工具定位，不要求adb/hdc预先加入PATH。adb先检查 `~/Library/Android/sdk/platform-tools/adb`；hdc依次检查 `~/harmonyOS-command-line-tools/bin/hdc`、`~/Library/Huawei/Sdk/openharmony/12/toolchains/hdc`、`~/Library/Huawei/Sdk/openharmony/11/toolchains/hdc`，再检查PATH。只选取实际可执行文件；不存在时仍按原工具失败路径报告，不新增安装、提权或环境变量配置。
- 显式Android/Harmony预览目标只做本平台轻量目标列表与selector解析，保留canonical ID、别名和已存储current，不为了截图订阅查询无关平台或前台应用。只有未能解析的 `current` 可进入受限的既有当前目标查询；轻量解析不等于省略身份或在线状态校验。
- Harmony的 `snapshot_display` 与 `file recv` **各有15秒预算**，顺序执行；这不是整帧15秒总预算，也不保证15秒内出图。前端首次画面探测使用单调时钟45秒上限，取得真实首帧即停止探测；隐藏、断连和卸载立即走取消，不等待该上限。提高预算不替代截图成功、首帧内容和恢复后的验收。
- Android/Harmony在HTTP响应body内取得绑定具体session的订阅，最后释放才停止采集，并覆盖首帧前断连。打包版iOS为保留原启动失败 `409`，先验证并取得引用，再由RAII订阅持有；即使body未执行、首帧尚未出现或连接取消，也释放成功取得的引用，且不会重复释放。此项不表示源码iOS所有旧采集路径均已重构。

预览生命周期只影响其自身订阅，不停止设备、业务App、录制、日志或其他仍可见预览。第五轮的内存观察量不作为本轮新资产/新路由的固定节省承诺。

iOS原生预览的主屏选择也必须验收：可解码JPEG不证明画面正确，关闭的Resizable屏可能保留更大IOSurface。当前实现保留normal target-bound Resize/display校验，按descriptor.screenProperties.uniqueId匹配系统primary uniqueId，只订阅唯一主屏；身份缺失、重复或主屏无surface不回退其他屏。port.uuid属于另一套framebuffer ID，不能互换。显式primary still的Resize unsupported豁免不扩展到stream。具体8K黑图反证、修复与真实结果见第六轮报告。


### 第七轮：有界预览缓冲与额外裁剪反证

[本轮记录](../spaces/SP-244-emulator-service-slimming/plans/20261030-further-memory-candidates.md)补充Node代理背压、源码iOS响应生命周期和`-avd NAME`宿主识别。慢客户端让`write`返回false时必须停读并等待drain，close/error/abort也必须解除等待；单次合成64MiB流的输出积压从63.46MiB降至0.17MiB，这是代理队列证据，不是模拟器内存固定收益。直接iOS路由也用RAII持有成功启动的引用，未执行body与无首帧断开均释放。

Android camera/UWB/Bluetooth/GNSS宿主裁剪组合在独立API34 AVD触发Bluetooth持续崩溃；虽能关闭相机，功能状态和环境漂移使内存差值不可作为收益。组合已拒绝，没有新增开关。鸿蒙当前6.1.1.200的free-page reporting配置与历史guest日志已证明通报机制开启，不能重复算新优化；host页归还仍未证实。camera.feature存在真实宿主初始化门禁，但共享镜像配置未改、收益未实测。


### 第八轮：编码临时对象与候选验证边界

[第八轮证据](../spaces/SP-244-emulator-service-slimming/plans/20261030-preview-memory-budget.md)已将iOS原生预览编码放入逐帧autoreleasepool，保留CIContext复用、画面质量/尺寸与停止语义。实际源码的合成IOSurface连续1000帧峰值约198→57MiB；有间隔的普通帧没有稳定额外收益。此为编码进程的突发峰值保护，不是模拟器RAM减少，也不提供用户开关。

第八轮Android完整fake-adb采集循环证明PNG passthrough可减少约11MiB峰值，但两张样本传输量增加约18%，当时仅保留候选、未修改产品MIME；现由下述第九轮正式接入。缩略编码反而增峰值，不能由较少像素推导总内存下降。Harmony当前商用镜像trimMem返回帮助，exit0不能算缓存回收成功。Android HWUI lowram在探针上使后台GPU缓存58→2MiB，但App PSS未降且host顺序漂移，不能作为VM节省，也未加开关；其作用于guest App后台，不等同宿主预览隐藏。真实owned iOS编码与订阅释放另测通过，其余范围以本轮报告为准。


### 第九轮：Android PNG直通与main收口

用户接受传输量代价后，Android host预览直接保存PNG；typed帧格式贯穿共用HTTP与packaged writer，每个part输出真实MIME/长度。原生iOS framebuffer与Harmony采集保持JPEG；源码iOS截图fallback保留实际图片格式。既有`mjpeg`URL不改，客户端必须按part Content-Type解码；硬编码JPEG的外部消费者需要适配，没有新增格式开关。源码流代理及其iOS截图fallback统一使用注入的hostInputBaseURL，默认仍为19421，独立单张截图入口不属本轮范围。

PNG校验限制16MiB、signature、IHDR/IDAT/IEND和chunk边界，再读no-cache metadata；不创建全尺寸CGImage，不保证每块CRC或任意压缩像素内容都可解码。ImageIO statusComplete不足以排除缺IEND文件；无效采集不替换有效帧。修改格式必须同时检查MIME、原始bytes、Content-Length、客户端解码、取消与重连，不能只改缓存Data。

[本轮实测与反证](../spaces/SP-244-emulator-service-slimming/plans/20261030-png-adoption-commit.md)：真实API34 Settings四轮ABBA，HTTP采集进程峰值中位18.99→8.56MiB，持续中位8.91→8.36MiB，payload增加9.87%；非VM收益，带宽依画面变化。源码代理、实际解包版的双订阅/隐藏停止/恢复/卸载及原生WKWebView通过；不外推为所有WebKit版本或完整桌面壳。CLI1819、Web156/build、local通过；当前候选真实Harmony/iOS设备矩阵未重跑。

采集观察必须分开记录恢复请求与恢复首帧时间；隐藏负窗口止于恢复请求之前，不能把连接等待算作仍隐藏。可见阶段保留正对照，采样缺失不能当零采集。测试不能偷偷重写hardcoded上游地址而掩盖配置失效。后续按需采集FPS、PNG缓冲拷贝、HWUI净收益仍需各自对照，未增加未经验证的选项。
