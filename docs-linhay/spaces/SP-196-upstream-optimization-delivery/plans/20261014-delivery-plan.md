# 实施与验证计划

主控隔离当前Runner工作；所有产品源码写入SP-196 worktree，主仓只写SP-196及索引/memory。任务按文件所有权分派，测试scratch路径由主控协调，设备动作串行Triton-first。

## 切片

- A：服务catalog/计划/恢复安全；保护旧receipts。
- B：Resize状态查询/parser、touch guard、观察metadata，HTTP复用同核心。
- C：selected Xcode framebuffer加载与helper取消/ownership。
- D：WebView受控输入/secure读回与真实WKWebView失败场景。
- E：通用prepared test产物/缓存身份与新result bundle。
- F：typed App defaults、skill更新/config迁移。
- G：前景命中/证据时间线、network/App Map范围与完整性审计，只补已证明差距。

所有新增配置需默认/环境/非法值测试，CLI schema输出同步；无副作用的dry-run先行。既有实现沿用，未发现缺口的优化保留审计证据而非机械新增。

## 验证顺序

每组focused失败/绿色后，由主控在隔离tree串行完整CLI/root/build验证；UIKit必须真实iOS destination。可用设备只读事实先保存，变更仅专用目标。最终总门禁、文档和source diff检查，记录每项状态/限制。
