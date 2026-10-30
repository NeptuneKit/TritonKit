# 第五轮：预览自动暂停与恢复

2026-10-30。用户授权实现隐藏停止采集、显示自动重连，并继续真实验证。状态：实现已同步主工作区；源码Web真实Android验收通过，未提交或发布。真实重连反证同时推动了既有Swift HTTP生命周期修复。

## 边界和状态

- 修改现有Web只读预览、Node dev代理、Android/Harmony已有HTTP framebuffer生命周期；没有新增设备控制操作、HTTP路由、依赖或默认设备设置。
- 连接意图与实际订阅分离。页面hidden/pagehide、viewport离屏/零面积、祖先display/visibility/hidden/opacity及CSS动画完成后不可见，状态为paused并释放网络图片；显示后产生新URL，保留目标/FPS/检查上下文。
- 状态为offline/paused/connecting/live，只有当前网络图像真实首帧可用才标LIVE；透明占位图不能作为首帧。首帧探测有界且在暂停/卸载后清理。失焦但仍可见不会主动暂停。
- 多预览分别订阅；最后订阅释放才停止后端采集。采集超时的同一session保持terminal，不隐式自动重启；后续显式订阅创建可用session，旧连接迟到释放不得影响它。

## 失败证据与修复

- 可见性模块先红后绿；额外发现StrictMode ref cleanup将原DOM src替换为占位图后setup未恢复，补失败测试后修复；CSS transition/animation完成也补红绿用例。共12项前端focused tests。
- Node原实现等到upstream headers后才监听request.close；真实随机端口HTTP夹具7项中5失败。改为从响应开始监听res.close/req.aborted并联动AbortSignal，覆盖等待readiness/headers、已开始流、多个订阅、iOS polling fallback。最终10项通过（补最后订阅关闭后首截图失败不得启动第二路截图）；健康探测可完成但取消后不再发framebuffer，已执行的单次iOS原生fallback允许结束，之后不再排新采集。
- 首轮原生浏览器16阶段/19断言通过，但采集观察期间19421由原PID退出后被Vite重建，旧PID观察不能证明后续停止；保留原记录并拒绝该部分证据。
- 复测出现200 multipart无首帧（direct 8秒超时），proxy也超时，而同一设备Triton单次截图成功。旧无帧连接和terminal session复用有源码可达路径；没有保存确切触发capture超时的运行日志，不把推测写成已证单一根因。
- 一次zero-size后恢复超时未保留失败DOM状态，无法明确归因；验证脚本随后保留原有position样式、显式激活目标页、保存失败时document/viewport/image状态。后一次真实connecting失败保留了空currentSrc/自然宽0及native screenshot成功证据。

## 环境及证据边界

- 使用同一SP-244 sibling worktree，主仓HEAD起点30185dc2；6个Web拥有文件逐字节同步main，其他任务的SP-193/SP-207差异保留。
- 浏览器只筛选真实registry返回的本轮Android目标，不伪造设备信息或画面；首个准备阶段曾读取默认iOS流，随后立即关闭并将registry也加入目标过滤，未发送设备输入或发布该画面。
- Chrome通过独立profile启动，Playwright用noDefaults CDP连接；默认focus emulation会让后台页显示visible。hidden状态的wait使用数值轮询，避免requestAnimationFrame停摆导致验证脚本误超时。
- 观察脚本绑定实际server PID，按目标筛选screencap子进程，采样间隔为0.08秒加ps耗时；只能证明观察窗口内活动/未观察到，不声称精确截图次数或即时缓存归零。
- Android原先为本轮新建实例，期间其他任务启动scrcpy使用它；清理仅限本轮预览/HTTP/Vite，保留被外部使用的模拟器和scrcpy。
- 原始日志/JSON/脚本位于私有`.triton/sp244-preview/`，测试构建日志位于worktree同名目录。截图放本space screenshots；不公开原始目标清单或私有内容。

## 打包模式的既有边界

共享前端随Web/dist打包。本轮浏览器验收覆盖源码Web/dev bridge。现有CLIWebRuntime只注册packaged iOS MJPEG，Android/Harmony缺少已注册的MJPEG路由；第五轮仅源码判断，第六轮真实基线确认返回404/空body，属于既有路由缺口；此次不新增这些路由，不宣称packaged Android/Harmony已可用。packaged iOS采用独立进程内framebuffer路径，未真实验证。iOS dev上游native framebuffer也未做真实回归；其既有body前start/无帧循环取消边界未在本轮Android/Harmony生命周期修复中重构。Node三平台HTTP fixture只证明代理取消，不能替代iOS采集器验收。

源码复核未发现前端/Node阻塞缺陷；可见性不覆盖任意外部遮挡、直接CSSOM改规则或DOM重挂后只变新祖先样式，现有布局没有这些隐藏路径。LIVE表示当前请求已经取得真实帧，不是持续健康探测。

## 最终验证

- Web全量100项通过；TypeScript/Vite build通过，仅保留既有bundle大于500KB提醒。AntD usage/lint通过，5条既有InspectorCard静态反馈警告与本次改动无关。
- Swift旧逻辑等价抽取4项中3失败（6断言）；修复后17项专项通过。完整CLI回归158 XCTest + 1605 Swift Testing通过，含Android/Harmony terminal session替换及真实随机端口HTTP无首帧断连；真实iOS指定模拟器与Bonjour场景按既有开关跳过。
- 最新release二进制运行真实Android API34预览，原生Chrome 16阶段/19断言通过：初始后台不请求；显示1080×2400；5FPS偏好、目标及fresh URL恢复；祖先display/visibility、离屏、零尺寸、opacity transition；重复事件/blur不重连；双预览独立暂停/恢复/卸载；无页面错误、无横向溢出。截图：`screenshots/20261030-preview-live-v2.png`、`screenshots/20261030-preview-restored-v2.png`。
- 绑定同一实际HTTP PID与二进制SHA256观察。下表均排除前1–2秒过渡；计数是观察到的不同采集子进程下界，不是精确帧数或内存结果。

| 阶段 | 有效采样数 | 观察到的不同采集PID |
| --- | ---: | ---: |
| 初始后台 | 10 | 0 |
| 单窗格可见 | 5 | 2 |
| 页面后台 | 22 | 0 |
| 页面恢复 | 6 | 2 |
| 双窗格可见 | 10 | 4 |
| 仅第二窗格可见 | 10 | 4 |
| 两窗格隐藏 | 28 | 0 |
| 两窗格恢复 | 9 | 2 |
| 卸载一个、保留另一个 | 9 | 6 |
| 最后预览卸载 | 39 | 0 |
| 页面退出 | 26 | 0 |

- 本轮未另启Harmony/iOS设备；两平台Swift service和三平台Node代理通过真实HTTP夹具，实际浏览器/设备画面只验收Android。既有第四轮Harmony断连实验属于历史证据，不能算本轮GUI验收。
- 自有Chrome/profile、HTTP、Vite、观察器均已退出；19421/34127已释放。Android已被外部scrcpy使用，保留该实例及scrcpy；没有改变其配置。清理回执为私有`cleanup-final.json`。
- 本地门禁中root7+401、release构建/smoke、fake Harmony host、mock iOS observe通过。第一次最终门禁在并行SP-245新space尚未同步INDEX时失败，保留原日志；其索引随后完成，最终`verify.sh --local`、`verify.sh --ci-docs`、`check-docs.sh`与`git diff --check`全部通过；worktree文档门禁同样通过。
- 主工作区并行SP-193/SP-207/SP-245差异保留。Web package与Web skill后续有SP-245独立变更，不反向覆盖；本轮仅合入自己的测试入口和preview验收段。

后续范围：本轮未验收的鸿蒙源码、packaged各平台及iOS原生释放由[第六轮真实验收](20261030-harmony-packaged-preview.md)接续；这里保留第五轮候选与当时结论，不作为新候选的完成证明。
