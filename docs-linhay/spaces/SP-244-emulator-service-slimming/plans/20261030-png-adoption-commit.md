# PNG预览接入与SP-244主线提交

2026-10-30用户明确接受PNG样本约18%的传输量代价，授权把本轮相关调整合到main、整理、沉淀并本地提交。继续SP-244，已有1–8轮验证历史保留。未授权push/tag/release，不修改SP-193/SP-207并行资料。

## 边界与BDD

影响层：Android host采集、共用HTTP multipart帧类型、源码Web代理/packaged只读预览；原生iOS framebuffer与Harmony采集保持JPEG，源码iOS截图fallback保留实际格式。现有Web渲染不承担业务动作，不调整RAM、屏幕尺寸、FPS或模拟器功能配置。

- 给定Android screencap完整PNG，采集保留原始bytes，不再解码成全尺寸CGImage再编码JPEG；multipart part必须标image/png，Content-Length准确，图片尺寸/完整画面保持。
- 异常/截断采集不能替换已有有效帧；校验本身不引入完整位图解码。明确结构检查与完整像素可解码性的区别。
- 原生iOS framebuffer与Harmony采集仍发image/jpeg；源码iOS截图fallback保留实际格式；同session多个订阅共享采集；最后取消停止；首帧前取消、隐藏恢复和新旧session隔离保持。
- 源码Web代理透传类型；实际Android与本地packaged浏览器验证首帧、动态画面、隐藏停止、恢复新帧和双订阅。补WebKit兼容检查，不能用Chromium替代所有浏览器。
- 先红测再最小实现，专项/CLI全量/Web测试构建/本地门禁；绑定本轮候选源与真实二进制，不复用旧package宣称新能力。

## 整理与提交

主控在同级SP244 worktree完成独占实现，按文件hash同步main；main已包含并行Web提交4126aec2，不用旧worktree整棵树覆盖。只stage SP244实现、测试、文档与共享文件的本space片段，保留SP193/SP207 WIP；核对实际暂存树、依赖文件、文档链接与所有新文件后本地提交。

先整理既有历史结论，保留“已验证/反证/候选/未发布”边界；记录下一轮优化队列，不把未测HWUI策略加入功能开关。后续优先：稳定host负载下HWUI净收益、采集FPS按订阅需求仲裁、PNG路径缓冲拷贝；均需先量化再采用。

## 实现与证据

Android framebuffer保留screencap的PNG原字节，共用writer通过typed imageFormat生成每个part的Content-Type/Content-Length；默认仍为JPEG，原生iOS framebuffer与Harmony采集不转换；源码iOS截图fallback保留实际图片格式。路径继续使用既有`mjpeg`名称，消费者必须按part MIME解码，不能由URL假定JPEG。没有增加格式开关或依赖。

PNG输入先检查16MiB上限、signature、IHDR唯一性/长度、IDAT、末尾IEND及chunk边界，再用禁用cache的ImageIO读取类型/数量/尺寸/状态，不创建全尺寸位图。反证发现缺IEND时ImageIO仍可能报告complete，因此不能只靠metadata状态；此校验不等于验证每块CRC或任意压缩像素的语义完整性。无效采集保留上个有效帧，不推进版本。

源码代理的Android/Harmony/iOS流与iOS流内截图fallback改用既有注入hostInputBaseURL，默认端口不变。测试直接断言真实配置上游，删除偷偷重写19421的fixture；独立单张截图入口不在本轮修改范围。旧fixture曾掩盖hardcode问题。

本轮源码四文件SHA及真实包/静态资源hash保存在私有证据`.triton/sp244-png-commit/`的`png-source-manifest.json`与`package-artifact.json`；本地release CLI SHA256为`d706c2b6654a996eed1dd57b7e0b030a3b83f2c02c0e10875fd101cd2503df27`，实际tar SHA256为`135d43df232564b81be31fb5199e75022de4a900f7ee198b9cb383209772d473`。包从仓库外解包目录运行并确认mode=packaged，未发布。

## 真实内存与画面

主控在独立API34 Google APIs arm64 AVD上验证，RAM2560MiB、4核、1080×2400、host GPU；测试目标固定为Settings。四轮独立HTTP进程按旧JPEG/新PNG/新PNG/旧JPEG顺序执行，每轮16帧，采样实际PID的physical footprint，不以RSS替代。完整数据在`real-memory-summary.json`与`http-controlled-*/`；较早HOME预热轮不混入对照。

| 指标 | JPEG | PNG | 本样本差异 |
| --- | ---: | ---: | ---: |
| 每轮流期间峰值的中位数 | 18.99MiB | 8.56MiB | 减少10.42MiB |
| 流期间中位占用的组间中位数 | 8.91MiB | 8.36MiB | 减少0.55MiB |
| 平均每帧payload | 136173bytes | 149611bytes | 增加9.87% |

上述收益属于HTTP采集进程，不是VM；空闲中位数7.09→7.32MiB，不能宣称全阶段都下降。第八轮两图payload增加17.60%是另一组历史样本，用户已接受约18%的代价，不把任一比例写成固定上限。没有改变屏幕规格、采集FPS或设备功能来制造收益。

真实直连、源码代理与packaged HTTP均验证PNG signature、image/png与准确Content-Length，实际画面1080×2400。源码/packaged浏览器使用当前实际Web资产及真实图像，仅把discovery响应过滤为自有设备，拦截其它设备请求；单预览、双订阅、隐藏一个、全部隐藏、恢复和最后卸载通过，错误/越界请求均为0。绑定各自实际server PID的抖动进程采样：源码全隐藏20样本/0采集、卸载14/0；packaged全隐藏21/0、卸载9/0；各可见窗口均有采集正对照。采样不是精确帧数。第六轮真实三端历史与本轮Android PNG验收分别保留，不冒称本轮重跑Harmony/iOS设备矩阵。

原生WKWebView接真实Android流，识别两幅不同画面、取消后占位解码、恢复后3次有效采样，0错误；harness清理窗口/handler/WebView后退出。这证明本机WebKit兼容，不等于完整Wails桌面壳验收。原生Page Visibility全流程沿用第五轮候选历史，本轮复验实际窗格生命周期。

## 测试与反证

| 检查 | 结果与边界 |
| --- | --- |
| TDD | 旧实现下6测试/11场景产生10个预期issue；新PNG原字节、MIME、无效输入、旧帧保留与默认JPEG通过；最终6测试函数含14参数场景 |
| Swift专项 | 30 tests / 6 suites通过 |
| CLI全量 | 162 XCTest + 1657 Swift Testing，共1819；0失败，含3个条件跳过（native iOS1、Bonjour2）；本轮未另跑native iOS，历史第八轮1项真实通过 |
| Web | Node流24项、Web全量156项、build通过；24项包含在156内，不累加 |
| 本地门禁 | `verify.sh --local`通过：root408、release build/smoke、fake Harmony host、mock iOS observe、iOS Simulator编译、docs/diff |
| 文档/暂存树 | 主仓与保留worktree的ci-docs/check-docs、diff，以及暂存树离线check-docs通过；源码与已测候选保持一致 |

完整日志在私有证据的`swift-red.log`、`swift-green.log`、`full-cli.log`、`web-test-retry.log`、`web-build-retry.log`、`main-local.log`。Web首次缺node_modules导致module缺失；用原lock执行npm ci后重跑通过，无依赖升级。代理fallback漏传参数、旧断言依赖未转义target URL的中间失败已修正并保留日志。

UI观察首轮把“首帧已到达”作为隐藏结束时间，错误包含了恢复请求之后的采集。修正为隐藏动作后预先固定窗口；packaged脚本显式记录restore-requested与restored两个时刻，负窗口在恢复请求前结束，可见正对照使用完整阶段。这是验证时序缺陷，不是产品隐藏失效。首次目标过滤遗漏target-registry，外部iOS请求被网络拦截，未采集；修正两处discovery过滤后重跑通过。

## 清理、整合与后续

自有HTTP/Node/packaged服务、浏览器context、WKWebView和观察器均退出；独立AVD经Triton stop核对目标消失，再通过avdmanager删除私有AVD。删除接口和显式启动端口未被当前Triton schema覆盖，fallback命令与Triton-first事实已保存。未操作外部服务/设备，未将测试环境接替用户运行环境。详见`final-cleanup.json`。

第1–8轮已验证实现与本轮PNG合成到当前main；保留main已提交的Rhine/预览UI，按精确文件清单纳入新增split文件和测试，5份共享文档仅暂存SP244片段，SP193/SP207差异保持工作区原样。旧worktree保留为历史验证环境，不整分支回灌，不创建远端写入。该报告随本地main整合提交归档；提交身份由包含本文件的Git历史追溯。

已完成项退出待办：资源契约/启动选项、自动暂停、packaged路由、主屏选择、背压与引用释放、iOS逐帧pool、Android PNG。明确不采用lowram混合缩RAM及会触发蓝牙崩溃的硬件裁剪；zRAM/ArkWeb/商用Harmony trimMem均未证额外host收益。后续队列按证据推进：①采集FPS随有效订阅需求仲裁，②PNG缓冲生命周期与拷贝测量，③稳定host负载下HWUI后台缓存净收益复验；均需兼顾恢复与画面，无新增未测开关或后台定时任务。
