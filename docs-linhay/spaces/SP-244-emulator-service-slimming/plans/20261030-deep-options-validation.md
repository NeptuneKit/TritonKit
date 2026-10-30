# 第四轮：高级候选真实验证

2026-10-30，用户明确要求验证[第三轮候选](20261030-github-memory-options.md)。影响层为现有CLI/HTTP采集生命周期、guest内核诊断和独立Harmony探针；不改业务App，不修改既有产品默认值。

## 验收协议

- 主控独占全部设备动作；独立闲置Android AVD使用5554，独立Harmony HVD使用10101。当前业务Harmony10100保留。服务固定127.0.0.1:19421，端口已有监听则不接管或停止；仅清理本轮创建的PID/探针。
- 预览：固定RAM/分辨率/页面，按无订阅→持续MJPEG→最后订阅取消→再次订阅测试；记录VM及Triton服务footprint、CPU与实际采集活动、输出帧、取消后状态。停止采集通过不等于宿主内存节省通过；HTTP推送fps不冒充底层采样率。
- zRAM：先读身份、boot、swap类型、mm_stat、节点权限和页大小。普通shell被拒后，仅在本轮独立debug AVD尝试官方adb root，记录身份切换并在退出前unroot恢复；不改SELinux、不解锁镜像、不重置swap。仅当前身份可写且存在可观测碎片时尝试一次compact；root实验不代表普通shell产品能力。若镜像拒绝adb root则停止该路径。
- ArkWeb：独立repo模板构建离线probe，以有限可重建图片缓存作负载；load→release→sham/trim配对，检查状态、PSS、host及再次加载。API存在或void返回不能代替实际调用和效果；商业镜像安装/签名失败保留原始错误。
- 任一探针失败先恢复/退出自有目标，不操作其他目标。保持原功能状态，保留原始私有证据，报告通过/无收益/不可用/未执行。

## 环境与事实

- 主仓main HEAD30185dc2，SP-244已有未提交候选保留；另一个任务的SP-207/governance文档差异不纳入本轮。
- 本轮Triton status/capabilities/doctor/list/schema及serve帮助保留于私有 `.triton/sp244-deep-validation/`；当前无Android活动目标，Harmony10100在线，19421未监听。
- 三个subagent分别准备ArkWeb fixture、zRAM只读采样协议、HTTP取消验证协议；只有主控操作设备。

## 实测结果

### 预览取消：生命周期通过，固定内存收益未建立

使用自有HTTP服务与三个直接MJPEG客户端，RAM/分辨率/页面在各平台单轮内不变；每平台串行跑完无订阅15秒、A订阅18秒、A+B共存5秒、仅B12秒、取消缓冲6秒、无订阅15秒、C重连10秒、再关闭12秒。Android为Settings；Harmony为首版独立probe的静态页面（当时phase=undefined），仅验证画面传输与取消，不代表ArkWeb功能通过；后续修复版另行验证缓存实验。服务启动前19421无监听，退出时只清理自有PID。

- 两端A/B/C分别收到23/17/10帧，客户端无错；A关闭后B在采样窗口继续5→16帧，C恢复首帧约1.45/1.77秒，实际JPEG已目视。每份JSON八阶段完整、客户端无错且日志无traceback；原工具退出回执未单独归档，不额外声称已有exit-code artifact。不能仅凭finally生成了JSON判成功。
- 最后关闭B后，最后一次观察到截图子进程距关闭Android约2.08秒、Harmony约2.40秒；后续15秒均未再观察到。C再次关闭结果一致。`ps`轮询会漏掉短命进程，0代表未观测到，不能当精确截图计数或取消延迟上界；实际间隔为0.08秒加`ps`耗时。没有公开cacheBytes/refcount计数器，不能声称实测缓存归零。
- 代码路径最后订阅者退出会stop/cancel并清缓存；本轮支持取消链有效，未发现断连后持续采集。页面仅隐藏但保留HTTP连接仍不属于取消，本轮未实现自动可见性管理。

单位MiB，均为同PID `proc_pid_rusage_v2.phys_footprint` 的阶段中位数；VM主进程和Triton服务分别统计，不含各自子进程：

| 平台/进程 | 单客户端A | 仅B | 无客户端 | 重开C | 再关闭 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Android VM | 5098.27 | 5093.87 | 5019.83 | 5094.66 | 5030.77 |
| Android对应Triton | 8.54 | 8.59 | 8.42 | 9.02 | 8.58 |
| Harmony VM | 5538.00 | 5568.76 | 5517.12 | 5586.01 | 5507.27 |
| Harmony对应Triton | 9.17 | 9.47 | 9.72 | 9.82 | 9.75 |

关闭前最后活跃窗口到关闭后窗口：Android两次低约74.0/63.9MiB；Harmony约51.6/78.7MiB。部分样本区间重叠且只有单轮，不能给固定收益。Triton服务自身不保证立即释放footprint，Harmony quiet窗口反而略升。

CPU辅助证据以100%=一核：A单客户端→无客户端，Android VM约53.42%→25.33%、Triton约3.92%→0.015%；Harmony VM约38.05%→20.84%、Triton约0.298%→0.011%。`ri_user_time/system_time`是Mach ticks，本机timebase为125/3，换算后才能按wall time求比例；不将原始值当纳秒，也不把主进程CPU称整条采集链总CPU。此结果支持减少采集活动，不证明全部VM变化由预览造成。

### zRAM compact：接受写入，未检出host收益

Android API34/userdebug，kernel `6.1.23-android14-4`，实际MemTotal2537912kB、zRAM1903428kB、算法LZ4、guest页4096bytes。普通shell读取mm_stat和访问compact均被拒。仅独立实验AVD官方`adb root`成功后采样，SELinux保持Enforcing；退出前`adb unroot`，回读uid2000(shell)。这不是普通shell可用的产品能力。

权限准备完成后取3个基线，仅一次写`/sys/block/zram0/compact`，返回0且stderr空。执行时`mem_used_total-compr_data_size`约10.3MiB，包含不能消除的元数据；本轮采用4MiB探索门槛，不是推荐产品阈值。取3个后样本及30秒延后样本：

- host中位5227271592→5300245928 bytes，即**增加69.6MiB**，区间重叠；延后样本5292152232仍未低于原中位。
- `pages_compacted`增450页，对应1.758MiB计数活动；并发swap与自动shrinker仍在运行，不能全部归因于手动写入。
- zRAM实际`mem_used_total`首样本短暂下降1.79MiB，第三个后样本净增加3.04MiB；不能将整理累计页数当成净回收，更不能当作macOS归还量。

结论为`accepted / no_verified_host_savings`。不增加root清内存产品开关；未使用swapoff、drop_caches、重压缩、磁盘writeback或SELinux修改。初末boot/AVD/镜像及全部9项功能状态逐项一致，自有Android VM已退出。

### ArkWeb MODERATE：接口与重载通过，额外收益未证实

基于仓库自带Harmony模板构建独立离线探针；兼容/目标API22，本机编译SDK24。商业HVD10101实际允许安装unsigned HAP，启动确认有本应用与`:render`进程，不将该能力外推至其他镜像。

真实运行发现runJavaScript结果多一层JSON字符串包装，首版出现phase=undefined、负载按钮不可用；先补真实格式失败用例，再统一两处解析并重建。修复HAP SHA256 `ea4197101fa42154ee3417ee36d366a8d5b294f272797317584edb5154096908`。修复后READY→LOADED/16图片通过，开始AB/BA对照；原第4轮在after15后中断，没有after30和重载结果，保留原始数据；另文件完整重跑BA（run5/6），不以延迟采样冒充30秒。64MiB仅名义RGBA解码量，不是实际分配承诺。

`device resource measure`只覆盖既有service allowlist，不能测此应用，因此回退显式目标的`hdc shell hidumper --mem --prune`，只在结果中汇总本probe及其命名子进程；Total Pss已含SwapPss，后者不重复相加。host按本轮启动ledger+完整argv核实的Emulator PID采样，固定启动身份。测量期间无预览连接。

两对完整记录采用原AB（run1/2）和补跑BA（run5/6）。原run3为完整补充样本，run4为中断样本，均保留但不混入配对统计。每个完整轮次有12次测量，App/render进程清单在轮内稳定，动作标记正确，全部重新解码16张图片成功；补跑整体exit0及最后terminate回执已保存。MODERATE分支实际调用公开API后才写入标记，支持“应用层调用无异常”，不是引擎释放回执。

单位MiB，PSS为本probe与命名render的合计，released为3次样本中位数，after30为单次样本：

| 轮次 | 操作 | Guest released→30秒 | Guest差值 | Host差值 |
| --- | --- | ---: | ---: | ---: |
| 1 | Sham | 255.900→231.521 | -24.379 | +0.391 |
| 2 | MODERATE | 256.401→231.555 | -24.847 | -55.625 |
| 5 | MODERATE | 255.963→231.044 | -24.919 | -22.375 |
| 6 | Sham | 233.560→232.040 | -1.520 | +1.281 |

**AB未显示明显额外收益或加速。** MODERATE相对Sham，guest差分在5/15/30秒分别约-0.116/-0.505/-0.468MiB；两组均到30秒才明显自动回收约24MiB。单组host下降不能证明由trim造成。

**BA存在基线时间错配，不作为效果证据。** run6的released三个PSS为257.989/233.560/233.470MiB，操作前已自动下降约24.52MiB；其首/末released采样距最后loaded样本为36.46/49.21秒，而run5仅12.08/16.50秒，均使用宿主采样时间计算。因此表面上的guest额外23.40MiB、host额外23.66MiB不能算trim收益。作为反证，两组loaded→结束的guest总下降接近（23.79/23.12MiB），host下降也接近（60.19/65.38MiB），但不使用改口径挽救这对数据。

分析器的空flags只证明结构和PID检查通过；独立`arkweb-causal-review.json`明确标记`baseline_timing_mismatch`、`baseline_drift`。不将同轮重复采样当独立重复实验，不对外给稳定百分比。结论：本商用镜像公开API可用，重载正常；本负载未证明额外内存节省，不新增通用ArkWeb清内存开关。CRITICAL、真实业务H5、其他镜像未测试。

### 证据与结束检查

原始命令receipt、完整样本、JPEG、JSON及复现脚本保留在私有`.triton/sp244-deep-validation/`；独立fixture及Triton构建日志在sibling worktree `.triton/sp244-probes/arkweb/`。初次原生hvigor构建发生在补核Triton前，后来显式task/product的Triton构建成功；不把最初错误流程改写为Triton-first。

- Android实验已unroot并回读shell身份，9项原功能状态/boot/镜像身份完全一致，自有VM退出。
- Harmony probe通过Triton卸载；当前`app list`不支持Harmony全量枚举、`app info`要求`--bundle-id`且返回未取得信息，保留这些错误后使用显式目标`hdc shell bm dump -a`确认探针不存在。仅停止本轮创建的HVD，使用`--skip-launchd`避免触碰共享监督任务。其PID、自有Android PID及HTTP服务PID均已不存在，19421无监听。
- 原有业务设备不在清理范围内；没有修改商业镜像权限、业务应用或生产代码，也没有提交/发布。当前自动隐藏预览仍未实现；仅现有断连生命周期已验证。
- 独立探针的负载测试、真实格式JSON codec测试、分析器自测通过。此次产品源码未变化，未重跑上一阶段1757项CLI与local门禁；本轮`verify.sh --ci-docs`、`check-docs.sh`和`git diff --check`全部通过，回执保留`final-doc-checks.json`。

## 采用裁决

- 预览断连：保留为有效降开销机制；本次观察到约52–79MiB范围的关闭后VM下降，但样本少且区间重叠，不承诺固定内存收益。自动隐藏/暂停UI属于下一实现切片。
- zRAM：仅已有debug权限实验可执行；未检出host收益，不提供root清内存产品选项。
- ArkWeb MODERATE：应用内API可调用；额外收益未证实，不作为模拟器全局功能开关。
