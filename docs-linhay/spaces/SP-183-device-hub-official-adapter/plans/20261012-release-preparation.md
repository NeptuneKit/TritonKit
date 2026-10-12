# v0.2.24 发版准备

用户要求合入主分支、整理skills并准备发版。已有SP183实现和实测修复均已合入main（基线16452dad），工作区干净。GitHub最新已发布版本v0.2.23，下一patch准备v0.2.24。范围仅本地整理、版本对齐、发布说明、验收和合并；不推送、不打tag、不创建Release、不推送CocoaPods。

## 内容与边界

- 整理public skills的Device Hub参考路由，消除重复和实施阶段历史矛盾；internal治理流程不打入公共包。
- 对齐podspec和Web两个manifest到0.2.24；CLI/public skill版本由发布打包脚本stamp，SwiftPM使用Git tag。
- 具备物理证据：iPhone元数据、App/Group SDK绑定、pair/unpair、测试App安装启动、诊断安全私有发布。非iOS物理与watch/tv输入不随之升级。
- 临时域真实创建未验收；watch/tvOS专门runner已编译但输入待runtime；visionOS空间/macOS Device Hub仍unsupported。
- 操作状态遗留：13 Pro Max已解除配对但尚未重新发现，未恢复；16 Pro配对/测试App保留。不是整个Device Hub接入完成。

## 发布门禁

版本脚本先RED（0.2.23不匹配0.2.24）再对齐；需验证version/release automation/public skill命令及打包、Web build、CocoaPods lint、local、docs/diff。双架构实际发布资产、checksum、Homebrew与安装smoke在正式发布后才能验收，本轮不声称完成。

## 本轮结果

- 版本对齐、发布自动化、公开命令、44 个包内链接、skills 打包/安装回归、`--ci-docs`、Web build 和 `--local` 全部通过。Web 依赖按锁文件安装，未改变依赖版本。
- local 含 314 个 Swift Testing 与 7 个 XCTest、release CLI 构建和 CLI/Harmony/runtime smoke；通用 Simulator Xcode build 显式跳过，未重复设备动作。此前完整 CLI 1154 + 26 的结果保留在能力验收记录，本次另核 public skill schema 一致性。
- 三份 skills 的重复 Device Hub 段落归并为共享契约与反馈/验收路由，dev-feedback 71 行，消除包外仓库路径。四个公开 skills 整包安装，内部治理不打包。
- 标准 CocoaPods lint 被 Xcode 27 不接受 iOS 13 deployment target 阻塞。临时 iOS 15 构建覆盖下 lint 退出 0 且明确通过；产品最低版本未改。原始 iOS 13 lint 随后由 main c3887682 的 CI 38201067605 标准 Podspec job 通过，解除该缺口；不是用覆盖后的成功替代。
- 仅本地提交并合并 main；skills 候选包从干净合并提交生成，不代表 Git tag 或正式 Release 已存在。保留验收工作树中的私有证据，不归档删除。

## 正式发布推进

用户后续明确授权推送、tag 和发布。main c3887682 已推送；正式发布以 v0.2.24 为目标，等待 main CI 的标准 CocoaPods lint 补齐本机旧最低版本门禁。发布前发现旧 CI 仍有可执行 tag 发布任务，与独立 Release 重复上传同名资产；本次停用全部旧 CI 发布任务并补防回归断言，保持 Release 为唯一发布路径。实际 tag/资产/安装结果在完成后写回。

## 发布结果

- v0.2.24 已发布，tag 固定指向 9c687b59c7a8b010208d0f7ccaffe5c5e479c5ab；main 已推送。
- [Release 38201287688](https://github.com/NeptuneKit/TritonKit/actions/runs/38201287688) 全部通过：arm64/x86_64、skills、checksum、两次 Homebrew tap 更新。main 完整 CI 38201067605（含原始标准 pod lint 明确 passed validation）、发布防重复修复 CI 38201255534、tag CI 38201287807 均通过。
- 重新下载三份正式 tar.gz，SHA-256 全匹配；Mach-O 分别验证 arm64/x86_64。正式技能包四个技能均 0.2.24，BUILD_INFO 绑定正确 tag/commit；私有证据不在包内。
- Homebrew 从 0.2.22 升至 0.2.24，brew test 通过；仓库外 version 与 Web packaged mode 正确。独立端口启动正式 Web，首页与两项静态资源 HTTP 200，随后停止本任务监听。此项仅验证打包和服务，不是业务输入验收。
- [GitHub Release](https://github.com/NeptuneKit/TritonKit/releases/tag/v0.2.24) 已写入本次能力边界说明。SwiftPM 使用 v0.2.24；podspec 已对齐且 lint 通过，未推 CocoaPods trunk。
- 继续保留 Temporary 真实创建、watch/tv 专门输入、原目标配对恢复等前述缺口；发布不等于全平台能力完成。
