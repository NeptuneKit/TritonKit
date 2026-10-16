# Runner 鉴权强化实施

基线：`dd613a994abe45aa14e072c381662a0e3d868f03`；候选位于 `feat/SP-205-ios-runner-auth-hardening` 独立同级 worktree。影响 CLI Runner transport 与随包 XCTest Runner；不改变 serve、Bonjour、embedded SDK、远端产品面。共享索引与 memory 由分派主控维护，本 space 保存可合并交付记录。

## 既有保护

源码确认保留完整 target、唯一 USB Serial、每次 SecRandomCopyBytes 32 字节 token / UUID session、资源 fingerprint、request/session 关联、单 deadline、unknown 不重放、bundle allowlist 与进程归属。当前认证 Bearer 在首包直接发送，HTTP envelope echo 不证明服务持密；服务过期只有外层 run loop，没有逐请求/排队执行前检查。

## BDD / 失败证据

1. Given 恶意监听器抢占配置 loopback 端口，When CLI 交换 health，Then 不发送可复用 token、伪 echo 不成功，且仅一次连接。先让同一断言在旧实现出现行为失败，再验证新实现。
2. Given 随包真实 server/router 与执行计数 spy，When 对 health/probe/snapshot/screenshot/tap/receipt/stop/home/activateFixture/crossApp/environment 分别发送错密钥、错 session、过期、错 method，Then UI 与 stop 执行为零；合法请求控制组必须真正经过路由。
3. Given 排队时未过期但执行时已过期，Then 不调用 UI executor；身份认证必须在 ledger / body / UI 分发前。
4. Given 旧 HTTP 服务、伪 proof、篡改 body/response、重放跨连接密文、反射或错 session，Then fail closed，保持 unknown/no retry；合法真实 socket 返回业务错误和回包关联不变。

## 协议方案（待审计验证）

本机/USB 每次连接仅一请求。v2 客户端先发固定版本标识与 32 字节随机 nonce；服务端回 32 字节随机 nonce 与 HMAC-SHA256 持密证明（域、session、双 nonce 绑定）。CLI 验证后才发请求，使用 CryptoKit HKDF-SHA256 按方向派生 AES-GCM keys，HTTP request/response 均加密认证。secret 只来自已有私有 xctestrun/session 交付，从不放到网络。每连接新 nonce 和方向 key 防跨连接重放/反射；保留 request ledger。旧服务失败，不降级明文。

CryptoKit 已用于 CLI resource digest，是 Apple 系统框架，无新 package 依赖。原语使用系统实现，不手写 HMAC/HKDF/AES。此方案证明共享密钥持有、保护请求/回包，不证明某个进程/物理设备身份、不防读取本用户凭据文件的攻击者，也不排除透明转发或 DoS；不扩远端信任。

生产 network/router 与 UIKit 执行器分离，使 macOS 离线测试编译并运行随包真实鉴权调用链。设备 UI/签名/DDI 不执行，真实设备行为明确未测。
