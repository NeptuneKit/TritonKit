# SP-195：iOS Runner 产品封装

## 边界

用户要求把常驻 XCTest Runner 统一封入产品以统一发布。影响 CLI、共享 host runtime、现有 HTTP command 入口、schema/capabilities、CLI 内置资源与双架构发布包；业务 App 不需嵌入 SDK，不依赖 Appium/WDA/Python/iproxy。Mac/Xcode、签名、设备配对/开发者模式/UI automation 授权仍是系统前提。

基线 main@df721b59；branch feat/SP-195-ios-runner-product；worktree ../TritonKit-worktrees/SP-195-ios-runner-product/。状态：产品实现与真机/Simulator验收完成；已完成本地main集成与独立产品提交，main本地门禁通过。本期准备可统一发布的本地产物，不创建远端发布。旧研究记录归档到本space的research/，不占用主仓SP-193/194正式参考文档编号；其他工作区保持原样。

## BDD 与验收

1. Given 安装后的 triton 和 Xcode，When runner prepare/start，Then 使用随包资源构建签名和启动，无需源码 checkout 或外部控制工具。
2. Given 明确 ios-real 目标与应用白名单，When start/status/stop，Then session 身份、owner、TTL、automation readiness 与进程退出可机器读取，状态不泄露 token/原始设备标识；不可用和锁屏明确失败。
3. Given 同一 session，When inspect/activate/tap/scroll/screenshot，Then 使用公共 XCTest 和最新元素观察，目标绑定、串行动作、请求去重、unknown 不自动重试，业务结果与提交结果区分。
4. Given 不同 bundle 的目标，When 切换与返回，Then 验证计算器/设置/fixture 后置状态；Safari 焦点不可靠时保留失败，不降低校验。
5. Given Release tarball/Homebrew 和离开 repo 的工作目录，When 查 schema/doctor/prepare，Then Runner 资源跟随 CLI、完整性校验通过，embedded 根包不引入依赖。
6. Given 本机 CLI 与 HTTP command 调用，Then 同一命令契约、单一 JSON envelope、生命周期/UI 副作用串行；不新增 Web 控制面。

## 实施与完成定义

- Swift 原生 host transport/client；Runner 作为 CLI 资源，不交付独立 Python 操作步骤。
- CLI 负责目标解析、会话与签名配置、启动退出、动作/状态；HTTP 复用已有 command 路径。
- focused TDD、完整 CLI/root/local gates、随包资源验收、可用 Simulator/真机测试与证据边界。
- 发布脚本、README/public skills、space/索引/dev/memory 写回。

## 链接

- [实施契约与分工](./plans/20261014-implementation.md)。
- [统一使用与状态边界](../../dev/ios-runner-product.md)。

## 当前产品证据

- [脱敏产品验收摘要](./product-verification.json)：从源码目录外调用随包CLI，真机构建/启动、计算器结果与去重、Settings导航返回、fixture跨App状态保留、截图原回执恢复、正常退出均通过；Simulator端到端通过。原生testServe326.786秒，TEST EXECUTE SUCCEEDED。
- Safari激活通过，但inspect默认18秒deadline返回transport unknown；无输入/网页导航通过结论。锁屏/断线/重启/长期后台、真实Homebrew升级、x86原生执行未作为通过项。
- CLI全量1297 Swift Testing +36 XCTest通过；新host Runner57、device协议14、打包fixture9。完整local gate、docs gate、Release arm64包仓库外验收通过。
- HTTP5条Hummingbird router contract tests通过；19421当前被其他服务占用，本期未抢占或重启既有server，未宣称真机HTTP端到端。
- [旧研究记录](./research/README.md)保留原始branch/worktree出处；研究Python不进入运行时，原始私有证据不入Git。

## 完成与发布状态

产品实现、本地门禁、真机/Simulator及arm64随包验收已完成，仍保留Safari等明确限制。详见[验收记录](./plans/20261014-product-results.md)。产品已引入本地main并通过主仓local gate；参考文档独立提交306dc42b，Runner单独提交。未推送、未创建tag或远端Release。两架构Release/Homebrew/public skills流程已准备统一分发，本期原生执行验收为arm64，x86为资源契约校验。

## Worktree收口

2026-10-14用户要求已完成worktree合入后清理；本产品与早期研究worktree已清理，源码在main@2a8b793f，私有恢复归档留同级目录。历史完成项及仍在进行的两个工作区见[收口记录](./plans/20261014-worktree-closeout.md)。
