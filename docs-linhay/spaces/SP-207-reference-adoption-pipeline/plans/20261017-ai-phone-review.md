# ai-phone 18 提交增量补审

完成受限范围内的静态机制补审：`38ef0c4fd81975195f37bb4ceead9efaaeaeb141` → `bd2781c17a9ad35cacae1049bfbd0975adbc758f`。`complete=true` 仅指相关增量源码/规格已审阅并明确排除项，不代表上游机制正确、全仓旧历史或运行验收完成。

18 条提交文本、9 条 Release notes 全文已读；1105 文件次、984 路径已分类。124 个产品文件次中，112 个相关机制文件次通过完整 patch 或注明的固定源码与修正 patch 覆盖，12 个 Web 页面业务实现按产品范围排除。相关待读产品源码/规格为 **0 文件、0 行**。精确提交/路径/阅读方式见 `file-review-ledger.json`。native 34、server 28、JEV 33 文件次子审报告互有交叉，不能相加当独立文件数。

主契约与升级指南已读 HEAD 全文，相关 8 个 README 文件次及公开候选 NDJSON/DTO 契约已读。测试、重复实验叙事和生成证据按清单、固定 blob、字节、哈希归档；不声称人工逐行审阅约 8.58MB 补丁中的重复日志/XML/NDJSON。原有 186 个内容响应解码 11,656,728 字节；补取 62 个图片 blob 共 6,395,621 字节，长度一致。图片未做视觉运行验收。

## 采用与本地 main 边界

- 几何实际缺口：main `CLIHostSimulatorAXDriver.devicePointSize` 的固定尺寸回退与上游 LCD 运行几何相关；父 agent 已建 SP210，记 covered，不重复立项。
- 其余机制记 observe：持久身份与地址分离、首绑回滚所有权、保护旧实例、观察与操作历史分离、从收件起预算、线程晚完成资源租约、有限并发、NDJSON 候选轮次隔离。JEV 绘制几何与点击候选分离有价值，但 main 当前 overlay 没有相同候选修改缺陷证据。
- main `d51403a69afbafd9426bd5ed6bfe3eb81a0ff0ec` 使用本机同步 Process timeout/TERM/KILL/drain；没有上游云 VM 账本、多 Agent 调度或 Web 写控制面的等价产品面。故不直接搬入云后端与页面，也不把 Python 线程取消模式当现有本地 bug。

## 必须保留的反证

Harmony `observe_instance` 仍可能把非 strict HDC 查询失败吞成空清单；bd278 只加固显式 stop / `_wait_removed`。不能概括为全部观察路径都严格。首次启动占位维护锁与真实 serial 的竞争尚未运行核实；iOS 活跃 WDA 复用 runtime 一致性依赖服务端锁定。部分同步驱动/文件系统仅前后检查 deadline，不能据此承诺所有故障下硬实时上限。详见 `native/report.md`。

原始 0e9 所有权设计必须连同 d7cb foreign-copy 冲突修正阅读，不能直接采用自动清理旧副本策略。JEV 的 unsupported 缓存、端口 TOCTOU 和 safe-region 校验边界详见 `jev/report.md`。

## 验证与剩余项

本次仅静态只读审阅；未执行第三方、测试、设备或安装，上游测试/性能不算本地证据。无原文获取失败或缺失相关机制源码。剩余非阻塞项是范围排除的 Web 页面、上游测试/生成记录，以及未来迁移时需独立验证的真实行为与竞争场景。

`review.json` 为机器入口；三个子目录保留逐文件审阅和反证。治理经验由父 agent 合入 SP207 日报，本子任务仅写授权 scratch，不改共享文档或 Git。
