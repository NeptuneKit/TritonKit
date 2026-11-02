# SP-254 transport 实施与验收边界

影响层仅 CLI host 隔离 helper；不增加 SDK、HTTP、Web、真机或 secondary display 能力。现有 target、booted、geometry、Resize、ownership 的前/初始化后/发送后拒绝继续生效。modern target=0 仅在现有 singleton primary portrait 门禁之后可用，不能用它推断显示绑定。

## BDD

1. 现代 lookup 有效：同一 XPC connection 完成无事件 keyboard usageCode=0/state=2/isBarrier=true 握手，再按 uint64 phase=0/1/2、double x/y 发送 tap/swipe；结束调用有界无事件 barrier。consumed 只表示 transport 边界，不是 guest delivery 或业务成功。
2. 仅 lookup 方法缺失，或 booted 设备 lookup 返回 null 且精确 CoreSimulator SimError405，才允许创建 legacy client。port 非空附带错误、未知 lookup、符号/连接失败、握手超时一律错误，不回退。
3. 发送/结束失败保持 unknown，绝不重连、重发 down 或自动 fallback；原有执行器仅在必要时 best-effort up 一次。连接错误记为永久失败，不复活 session。
4. 纯离线 fake 验证 wire 类型、顺序、barrier 不产生字符、unsupported 分类及 no fallback/replay；真实兼容性未授权且未验证。

## 来源与许可

- Loupe 固定 `180c60584867500b93b43ca6c8b556995bf8be7b`，安全审阅目录中 `LoupeDTUHID.m`；MIT 完整通知随 native-hid 资源分发。
- 协议及 endpoint 参考 facebook/idb 固定 `c793afad2a31092628f7013cf1aa96f266c85024`，`FBSimulatorControl/HID/DTUHIDModels.swift`、`SimulatorDTUHIDConnection.swift` 和 `XPC/SimulatorXPCConnection.swift`；已读取该 SHA 的 MIT LICENSE（Meta Platforms, Inc. and affiliates），完整许可证随 native-hid 资源分发。不导入其依赖或运行代码。
- idb 当前实现存在 retry/drain/tail 等不同策略；本切片只参照 wire/endpoint/许可，采用本 space 有界 barrier、无重连重试策略，不承诺时序等价。

## 验证与交接

证据目录：`/Users/linhey/Desktop/linhay-open-sources/TritonKit-worktrees/archives/SP-254-simulator-dtuhid-transport`。默认 CLI scratch；SwiftPM 默认实际 build-system 为 Xcode（manifest.pif/out/Intermediates.noindex），不调用 xcodebuild。依赖仅从本机主仓已有 checkouts/repositories 复制，使用 `--disable-automatic-resolution --skip-update` 禁止解析更新。测试/构建单飞。不得把离线绿色写为 Simulator 兼容验收。

公共索引、长期 memory/skill、SP-207 与 SP-255 集成资料由主控更新；执行方仅维护本 space 与授权实现文件。

## 生命周期与预算补充

Session与连接状态由独立锁保护，callback仅捕获heap-owned一次性reply latch；超时/取消先标失败并唤醒pending，迟到reply不能复活。自有匿名本机XPC peer验证实际pending/cancel接线，不等同SimDevice endpoint/guest实测。parent timeout仍为150秒，原三次snapshot最多66秒、legacy sends及release最多26秒、gesture最多10秒，原48秒启动余量覆盖modern初始化/finish两次各4秒；现代发送自身不逐contact等待。父进程强制终止时不保证执行deinit或terminal-up，任何可能已输入的失败仍保持unknown，不自动重放。

send出错后session永久poison，仅允许尚未尝试的同target、自有active contact terminal-up一次；move/new-down/finish不再发送。正常完成后结束barrier只证明协议响应；barrier dictionary、XPC错误/非字典或显式error由受锁保护的reply处理，不推断业务ACK。

## 经验检查与交接限制

本轮测试抓出发送失败后session仍能继续move/new-down，已在本契约与测试固定“永久poison、仅一次terminal-up”规则。它落实既有unknown不得重放原则，无新增repo-wide规则。长期host skill/经验索引若需补充由主控在SP-255整合，不越权修改共享资料。公共DTO无backend字段，本期仅message诊断，不宣称完整backend机器契约；source/strategy/verification沿用已有契约。


## 离线验收结果

2026-11-02 focused42项/7suites及完整CLI1677项/178suites均exit0。参数拒绝两条实际helper命令均exit1且单JSON，未触及目标。当前执行分支基于44e81f5d，公共索引未登记SP-254；check-docs和verify --ci-docs均因此exit1，按主控独占登记边界保留失败，等待SP-255集成后门禁。独立只读审查没有当前单手势路径阻断项；session限定为单gesture，正常up后立即finish，不作为多手势复用连接。完整命令/退出码/hash在sibling evidence保存。
