# serve-sim 2026-11-11 部分评估

## Requested / Observed

固定base `ede4c21ee3021a36fbee1fec106b388a50a5ce4e` → head `5f6dee52834351ae2d765dfda02e540248a9b663`，actual main `607410fb3d44bfe02274c13822170c3015c63a99`。22提交/140路径/284全文版本已严格TLS官方获取、git blob hash及UTF8校验。提交分页至base、每parent树无truncated，无二进制或身份文件下载。旧raw缺失来源未知，此为当前固定SHA采集副本。

## Evidence / 已审机制

[固定增量](https://github.com/EvanBacon/serve-sim/compare/ede4c21ee3021a36fbee1fec106b388a50a5ce4e...5f6dee52834351ae2d765dfda02e540248a9b663)。diff达26,922行，采集完整不等于全部语义审阅完成。

已审安全子集：SpringBoardLauncher为不可取消direct launch设置timeout，单独队列弃置且不堆叠后续direct；这是上游专用Home路径，Triton无同样direct SpringBoard actor调用，不从其fallback行为推定可在发送未知后重放。HID输入增加setupTask等待、bool交付报告和WS ACK，避免缺client时CLI仍exit0；main内置DTUHID/legacy helper已明确失败/unknown和不重放边界，不凭该上游缺陷推定本机同源。键盘sequencer按提交序列处理down/up、关闭时追踪modifier释放与迟到down；Triton不是该持久Node keyboard会话，观察其生命周期方法但尚无本地复现。booted inventory和内存probe改异步/in-flight共享以避免Node event-loop阻塞；SSE loopback保留viewer Host/proto/auth但目的地址仍固定127.0.0.1，Triton不提供其exec-ws远端shell面，不照搬控制面。

## Gaps / Remaining review

尚未完整审读：新增AX refs/changes-after-settle及全部反例测试；录制frame/event index与离线frame/diff/changes；rolling frame buffer与UI scrub/hooks的预算/生命周期；合成摄像头movie output swizzling和device-set全链路。不能用提交标题、完整blob下载或部分安全子集对照替代这几组完整语义评估。当前observe、complete_review=false，保留semantic_review_incomplete，不推进成功检查点，不新增开发切片。

LICENSE固定全文SHA256 `9024cdf56dfe7e66523698a9f63d3a0061eb15f43bd5ea8e3833a56017ae37fd`已核验Apache-2.0；官方Release分页没有非draft Release。全部源码与未读增量仍持久存review-manifest/review-source/review-increment.diff，便于继续，无需再取固定blob。未执行上游代码/测试、依赖、设备、发布或Git mutation，只写指定仓外目录。
