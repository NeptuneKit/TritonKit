# #204 受控输入验证

## 候选与根因

基线远端 main `dd2ef7a6e2f6901cb2908c872ae6778e60de2057`。旧 legacy input/textarea 直接 `element.value = nextValue`，同步更新 React own value tracker，后续 input 事件不能再观察差异；页面 DOM 暂时变化但 state 未消费。以真实 React19.2.7、独立state/onChange/强制rerender/validation复现，未从私有现场猜测唯一根因。多 WKWebView 的选择错误被旧 catch-all 丢弃，独立真实双视图反例确认。

最小修改：native prototype setter，不碰 React 内部 tracker；保留事件/caret/contenteditable。即时及50ms原对象读回，回退/拒绝失败且不自动重放；typed ambiguity 在写前拒绝。错误不回显文本，成功仍标业务验证 required/not-verified。strict opt-in不变。影响iOS embedded SDK；CLI安装升级不改变旧App嵌入代码。

## RED / GREEN

| 门禁 | 实际结果 |
| --- | --- |
| JSCore旧实现 | 8tests/16失败断言；controlled state、回退、detach、只读与异常隐私失败，selection/password/contenteditable三对照通过 |
| 真实旧iOS App-host | 6tests，4失败/2对照通过，20失败断言；React input/textarea state/onChange/rerender/validation与ambiguity复现 |
| 旧Xcode流程终态 | 测试本体4.15s结束后结果收尾未退出，600s host_command_timeout，exit1；xcresult缺Info.plist，不能称正常exit65或完整bundle；后续status无活动进程。等待原因未归因 |
| 新JSCore | 9tests全部通过，含单次readback消费与延后回滚 |
| 新真实iOS App-host v1 | 7tests/0失败/0跳过，Triton xcode test正常exit0，xcresult解析passed；原6场景加queued回滚。主控复审发现legacy正例页面默认仍opt-in，不能据此证明未opt-in页面；保留首轮结果，仅以无opt-in v2补足该边界 |
| 完整根包 | 7 XCTest +413 SwiftTesting/65 suites通过 |
| 新真实iOS App-host v2 | 默认无opt-in；每项测试前断言根属性缺失、全局开关非true。7tests/0失败/0跳过，正常exit0且完整xcresult解析passed；JS行为源码不变，HTML模板hash变更单独保存 |
| 完整CLI与local门禁 | 162 XCTest +1741 SwiftTesting/184 suites通过（3条件集成skip明确保留）；verify.sh --local通过，含根包/CLI release build/合成smoke/文档门禁。泛用Xcode开关关闭，真实SDK验收由上述独立App-host覆盖 |

真实宿主使用前景UIKit/WKContentView及当前local SDK，非hostless或macOS条件跳过。queued负例先记录新DOM及React state接受，再异步回滚DOM，真实provider必须失败/unknown且不泄漏输入。无私有App、登录、IME或业务提交。fixture部署目标从16调整17仅匹配当前XCTest链接要求，不改变SDK最低版本，也不作为旧收尾超时归因。

## 审阅与复现

独立审阅无P1/P2；生产diff相对基线SHA256 `544af0a052714c2de8a2b11e28a38c513bbcb41d2fa335b1852a8b8d6571c181`。未直接跑timer expiry/cross-realm专门反例；token2s清理/消费前删除与realm setter路径静态检查，不能夸称这些额外场景实测。

[可复现fixture源码](fixture/README.md)只存小源码；复制包外再生成工程/Reactbundle/DD/xcresult。实际React bundle SHA256 `b483f31c14d992501d50431fbc4a5803bc17843dfa102e40afa66c4587d44765`，便携副本生成同hash；React19.2.7/react-dom19.2.7/esbuild0.27.7。原始本机证据同级 `archives/SP269`：red-manifest、green-manifest、root与iOS日志、完整GREEN summary；历史RED和旧源码归档保持。包外原工程 `SP-269-ControlledInput-AcceptanceHost` 保留。

0.2.39尚未tag/发布；最终远端CI、标准pod lint、发布/安装与公开包验收另见SP264，未完成项不写通过。原私有现场保持历史未验，不因自有fixture成功而宣称恢复。
