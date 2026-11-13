# Maestro 2026-11-13

完整审阅6提交、25路径、2035行增量与相关完整录制源码/新增测试，Apache-2.0固定许可，Release cli-2.12.1未变；头部CHANGELOG为Unreleased，不能冒充已发布。

结论observe/covered，无新采用。VFR编码按screen/text事件合并、深拷贝解码buffer、时间驱动keyframe，Skia缓存静态层/字体；异常仍finish索引但原异常保留。上游性能倍数未经本地验证。Triton现有simctl/adb原始录制无该合成链；不能以对方修复证明本地媒体错误。

ANSI终端与overlay双视图、parsed command analytics、取消CI的!cancelled均已读；本地ci.yml唯一always是最终汇总gate，与上游保留always的e2e-gate一致，不盲改。记录本身已本地执行，无远端renderer要移除。

若未来添加overlay派生视频，BDD应分开原始视频与转换产物，验证事件时间、索引/失败partial、缓存尺寸失效及真实性能，不因图像重复删原事实。仅静态审阅/hash核对，未执行上游、设备、构建、发布；本仓未写。固定main及hash在review.json/local-main-manifest。
