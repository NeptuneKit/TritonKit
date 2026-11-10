# SP271 验收与审阅

## Requested / Observed

closed #139新评论确认实际runtime路由正确，错误envelope拼接绝对URL并给出iOS恢复动作。保持请求路径/方法/body不变，共用client requestURL生成诊断；direct-runtime错误使用WebView envelope保留action/platform/target。HTTP503 provider错误保留完整typed字段，取消与非transport错误不伪装成功。

## Evidence

- 基线edffb45e；旧安装0.2.39双listener fixture：provider200保留，provider503上下文丢失，diagnosticsAccepted=false，server listener零请求。
- RED：4测试中2失败，共15个预期诊断断言；默认server与Harmony缺URL控制通过。
- GREEN：55测试/4suite，新suite10测试；Harmony/direct iOS、absolute/relative、provider可选字段、取消/非URL、非法URL、text与Android unsupported覆盖。
- 完整CLI：162 XCTest +1751 Swift Testing/185 suites通过，3原条件测试跳过（真实Simulator/NetService），不当真实设备验收。
- 主控使用持久[HTTP fixture](http-fixture.py)在候选进程复验通过：200与503原provider保留，实际POST /v2/runtime/webview/snapshot仅2次，server选项listener零请求，完整endpoint/action/platform/target正确。脚本默认显式断言，--baseline仅供保留旧错。
- 原始日志及SHA清单位于同级archives/SP271；主控fixture binary SHA见controller-fixture-v2/result.json。首次主控fixture使用不存在的native风格binary路径失败，改用实际swiftbuild CLI/.build/debug/triton后通过；属于验收入口失败，不是产品RED。首轮docs缩写link不满足精确label，恢复规范链接后通过，未放松门禁。

## 审阅

独立只读审阅无P1/P2，主控复查实际3产品diff及新测试。产品diff SHA256 a7ac76ff74200e5560877efc54d5fba339b480d4c67b1bfe1d40f484c9e46644；新测试SHA256 9a45395002dd7ec9201981ebfcf2855cfe6840caf687ae88ae34e4a091a71d0a。fixture原仅记录布尔字段的建议已补为强制断言并实际复跑。

## Gaps / Remaining risk

没有真实App/provider可用性断言，不说明原现场完整恢复。完整local发布门禁/标准Pod/remote CI/正式发布与安装仍属后续SP272；在通过前不发tag。SP270只占号登记，不纳入产品。保留#214暂停/#224未知/#246人工依赖排除，不关闭issue。
