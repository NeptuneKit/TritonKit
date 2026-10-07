# SP-180 Xcode27 Simulator framework compatibility

2026-10-04至10-06，加载器实现与全量门禁通过；真实宿主命中仍未封口。用户授权最小兼容修复在指定主工作区完成；不创建branch/worktree、不Git写、不发布、不修改Xcode bundle或全局选择。

## 2026-10-07 整理提交与复验

用户明确授权整理提交，历史“不Git写”约束仅标记此前修复过程；本次只提交加载器、8项红→绿测试、保持全部断言的HTTP请求拼接编译修复、space/索引/memory，不推送/发布。Overloaded UI另仓提交eb77dfba，未复制私有业务receipt/AX/截图。

[提交前复验](<submission-verification.json>)：标准并行CLI首次全量993项出现12issues（Harmony有界时间及进程全局stdout/stderr捕获），重试再次失败且挂起，取消后按精确日志fd识别并清理本任务孤儿SwiftPM/helper，不删锁/缓存、不停其他进程。保持同一源码与全部断言，`swift test --package-path CLI --no-parallel`完整993/79＋14XCTest、0fail，22.961s。串行调度通过不等于已修并行suite或证明唯一根因；stdout重定向/全局环境/墙钟预算的回归应显式记录调度，不能重试绿后隐去首轮失败。

`TRITON_VERIFY_XCODE=0 docs-linhay/scripts/verify.sh --local`正式exit0：SDK50＋219、Release CLI、标准CLI/Harmony/iOS observe smoke、文档/diff通过；可选SDK UIKit Xcode构建明确skip，不借App构建冒称覆盖。宿主HID导航仍保持未通过的边界，加载器与UI bridge业务交付分账。

## 边界与BDD

CLI宿主进程层：baguette0.1.70仍dlopen旧Developer/Library/PrivateFrameworks路径；Xcode27将SimulatorKit移动到Contents/SharedFrameworks。新位置dlopen、类/选择器/符号探针成功；进程级DYLD_FRAMEWORK_PATH已令Triton tap真实从服务器根页打开Qbit服务页。并非HID类被删除。

- Given选中Xcode27且真实SharedFrameworks SimulatorKit存在，When调用baguette（包括layout/tap/持久swipe），Then仅该子进程获得框架搜索目录，保留原DYLD目录优先级，不改变全局环境。
- Given旧Xcode、目录/框架缺失或非baguette子进程，Then不注入搜索路径；不扫描/切换其他Xcode。
- Given显式DEVELOPER_DIR或TRITONKIT_BAGUETTE_BIN，Then尊重所选开发目录及适配器，不硬编码系统安装。
- 单元测试先失败再实现；真实受控模拟器导航后置条件与tap/swipe验证，ACK不代替业务验证。工具修复后继续Overloaded大字号截图验收。

现代UITab路由提前guard、模拟器SDK endpoint被设备plist覆盖是独立候选，暂不混入此路径修复。子agent只读审查，没有共同写入。

## 验证

- 手动进程级框架路径probe与真实Triton导航已成功。5个环境单测红→绿；CLI 990个SwiftTesting回归与完整本地门禁通过（SDK50+219，Release CLI/smoke/文档/diff；可选SDK simulator build未跑，真实App代验）。
- 2026-10-06首次无父DYLD变量实机模拟器tap仍报missing-framework。继续核验发现本机不存在此前假定的`/var/db/xcode_select_link`，但`xcode-select -p`能返回已选SDK；不能把手动路径回退冒称自动修复验收。新增BDD：无DEVELOPER_DIR时使用受支持的只读xcode-select查询，不依赖私有symlink；显式环境仍优先，不查询其他SDK。先新增选择器红测试，再重新集成与运行态。
- 选择器新测试实际1红→8全绿；最终完整CLI 993 SwiftTesting/79 suites+14 XCTest通过，verify --local exit0（SDK50+219、Release CLI/smoke/docs/diff；可选SDK UIKit build明确skip，并不由App构建冒称覆盖）。
- 新binary无父DYLD变量tap不再报加载器/缺类错误；Search导航AX超时，仍不接受ACK为成功。主项目改用已修复现代DEBUG route与精确simulatorUDID应用内bridge，build13真实任务和最大字体详情截图通过；不是宿主HID全闭环。
- 只读源码发现纯sim坐标路径丢弃width/height、Chrome.screen取皮肤光栅cutout而非真实逻辑点。此偏差不独立证明未命中唯一原因，保留脱敏后续几何BDD，不盲改Web缩放行为。
- 私有UDID/bundle/AX/密码留在业务工作区忽略目录，不复制进本space。
