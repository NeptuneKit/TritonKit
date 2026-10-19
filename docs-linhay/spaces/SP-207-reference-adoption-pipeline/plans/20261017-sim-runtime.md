# 2026-10-17 simulator/runtime 上游检查

10仓：变化5，无变化5；完整9，partial1。

只读GitHub API；未执行上游代码、安装、设备或Git写动作。基线来自2026-10-14 imported_observation，不是完整历史审计。分页读取非draft Releases（含prerelease）后按发布时间选取；许可证按固定HEAD读取全文并SHA256，历史无hash不能证明许可未变。所有检查点由root裁决，本agent不写共享state。

| 仓库 | 变化 | 完整 | 提交数 | 最新Release | 裁决 |
|---|---|---|---:|---|---|
| EvanBacon/serve-sim | True | True | 3 | 无 | observe |
| JaviSoto/device-hub-ios | True | True | 2 | 无 | observe |
| Mastersam07/OpenDeviceHub | False | True | 0 | v0.2.0 | observe |
| MobAI-App/simslim | False | True | 0 | v0.12.2 | observe |
| ProxymanApp/atlantis | True | True | 0 | 2.0.0 | observe |
| RockxyApp/Rockxy | False | True | 0 | v0.41.0 | observe |
| heoblitz/Loupe | False | True | 0 | v0.5.1 | observe |
| jfarcand/mirroir-mcp | False | True | 0 | v0.40.1 | observe |
| lycorp-jp/sim-use | True | True | 7 | v0.15.0 | observe |
| tddworks/baguette | True | False | 9 | v0.2.7 | observe |

## EvanBacon/serve-sim
82个增量文件已按鉴权/typed RPC、CLI坐标、native编码诊断、doctor与读流/UI恢复分组读完。Web/远端shell写面不采用；SP196/205已有受控helper与持密Runner。诊断快照与首帧分阶段错误可观察，不作为性能或运行验收。
82文件阅读清单：EvanBacon__serve-sim/reading-manifest.json。鉴权、typed RPC、原生编码/doctor、首帧错误、读流重试与UI错误展示均已覆盖。
- host-rpc execFile默认有16MiB maxBuffer但无timeout，不能照搬为有界进程实现
- encoder errors唯一key字典及renderer不同日志Set无全局上限；诊断仅home路径脱敏，不代表完全匿名
- CLI配置401/403可继续未映射触控；Triton必须保留geometry fail-closed
- 只读MJPEG指数退避500ms到10s与reader/abort清理不构成动作重试授权
- Web相机/权限/location/media改typed RPC是上游自身收敛；Triton不新增Web写控制面或remote exec
固定来源：https://github.com/EvanBacon/serve-sim/commit/c47a468b600362d14960504bfb4f222101ead634
读取完整；未运行上游测试、服务或设备。

## JaviSoto/device-hub-ios
测试进程检查2→10秒并保留清理错误；远程UI操作统一corner menu并更新AX契约。正式Web/远程控制不在本轮范围；本项目已有有界process/helper，未出现对应失败证据，不直接放宽timeout。
固定来源：https://github.com/JaviSoto/device-hub-ios/commit/b5994ff72d8c75d68370ae80aa3efaa4e590686d
错误/边界：无读取错误。

## ProxymanApp/atlantis
HEAD完全未变但Release由历史1.36.0变为2.0.0，notes仅声明兼容iOS26/27；未提供新源码差异，不把版本兼容声明当本地证明；SP196网络完整性/header-only边界继续有效。
固定来源：https://github.com/ProxymanApp/atlantis/commit/cc059013de8778072b4fea6453b45e964e4202fe
错误/边界：无读取错误。

## lycorp-jp/sim-use
新增同一真机session的null AX root最多5次只读重试，500ms间隔/2秒只控制调度，非取消在途DTX；malformed root/transport/cancel不重试。Triton不使用该AXAudit私有真机后端，观察而不移植；禁止把动作unknown重发。
固定来源：https://github.com/lycorp-jp/sim-use/commit/81c3089331aa0004fc97cd5330e2b32ca79dd6ce
错误/边界：无读取错误。

## tddworks/baguette
运行App实际defaults lookup/unset/live与按需relaunch是现有typed磁盘prefs之外的真实缺口；另有Xcode27.1 guest hinge读回，但需注入helper/私有ABI。官方APK字节已完整保存，但APK关联构建源码/身份分发来源未证实，因此整体仍partial，不推进成功点。
固定来源：https://github.com/tddworks/baguette/commit/14b39834fef663c2eca868db98422e4eaa8e2bb3
错误/边界：partial source association: fixed official APK/certificate/identity bytes are retained, but corresponding APK build source/manifest provenance is not established; no binary behavior executed or asserted

每仓完整release元数据、license hash、固定HEAD、coverage、errors与采用候选BDD/本地文件见 results.json；原始API和解码源码位于相邻仓库子目录。
经验检查：遵循现有SP207检查点/采用分离规则；本轮无新增治理规则，partial不得推进成功点。只做研究，不运行产品测试。

实际main基线为d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec；10个引用源码/测试的main blob与工作区HEAD一致，见main-source-check.json，未修改main工作树。
