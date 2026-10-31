# mirroir-mcp 2026-10-30 固定增量评估

结论：observe，无新采用切片。3提交、83个净变化文本路径，主要是iPhone Mirroring键盘修复、测试诚实性、SCK dropped-handler与Rust iOS block预算；未发现可复现到Triton实际main的新缺口。

## 来源与覆盖

固定base `317dc15fa21b63cf3e6b997784bd1c4ce6607392` → head `20223a9a7f3707513c9bbaf740773ead1f181ce1`。官方来源 https://github.com/jfarcand/mirroir-mcp/commit/20223a9a7f3707513c9bbaf740773ead1f181ce1 ，其余提交为b127c05adf039df8ca44925c02e68099260341ef（serde_json）及03ef82b8895dd1e943752a0eb2c8da11864637d2（网站依赖）。

base/head及两中间提交均通过git trees recursive读取，truncated=false。固定head commits列表per_page=100，第1页找到旧base，得到3提交；逐提交树差异并集无额外临时/回滚路径，83项均为用途允许的文本。未请求compare/commit文件patch，未下载资产、二进制、身份、密钥或证书内容。先路径用途审查，再文本扩展白名单和2MB上限，随后获取固定blob，验证UTF-8且无NUL，保存于texts/base和texts/head共151版本；新增路径无base。inventory.json、commit-tree-coverage.json、text-coverage.json与text-manifest.json保存范围和hash；safe-local.diff完全由已筛选文本本地生成。

采集器已有metadata、固定HEAD Apache-2.0 LICENSE.full及sha256 `52327c57e955a3e63f872960938e814acc19eb1b77c501999f5fd1e543b21346`，分页release共1页。最新非draft仍runner-v0.4.0；mirroir-v0.41产品系列与runner标签不可混同。完整review只表示本次固定delta覆盖与评估，不证明全史安全或上游测试通过。

## 对照实际main

main `30185dc277ed305483aa789cb2d8c8b06fa21fe4`，git show main固定文件保存main-text/。未以工作目录WIP替代main。

| 上游机制 | 本机对照及判断 |
| --- | --- |
| Canadian-CSA字符→实际keycode/shift、dead-key组合、无映射字符走Universal Clipboard；iPhone Mirroring Safari Cmd+L开放 | Triton现有Simulator/embedded/Android/Harmony输入不走iPhone Mirroring硬件键盘布局表；main Sources及CLI测试无UCKeyTranslate/IPHONE_KEYBOARD_LAYOUT。不可从上游CSA修复推断Triton字符替换缺陷，不引入Universal Clipboard副作用或真机镜像transport。 |
| global settings按key合并local，local缺键保留global | main CLIHostRuntime.swift:330只读workspace内typed host-defaults.json，无上游global/local两文件首选一份的链；存储校验与原子替换已有独立契约。没有同源复现，不照搬新的全局配置层。 |
| AI-only verify/remember等必须NOT EVALUATED并令整skill失败；无hints步骤live执行；非法/不可用步骤运行前拒绝；dry-run拒绝report-json；未知flag退出2 | TKReplayAction封闭Codable枚举没有这些AI-only动作；readReplayPlan拒绝空计划，runReplayPlan预生成全部命令，实际失败停止；dry-run明确带dryRun=true，不解析runtime，测试有覆盖。SP-196已交付skip/dry-run不当业务通过原则。没有SKILL.md解释器和Playwright报告链，不新增AI evaluator。 |
| 指纹记录于step1前；test不再自动重编译/写回baseline，不以屏幕变化自我批准 | Triton是单一typed .tritonplan，无旁置compiled坐标文件、来源hash双链或自动学习baseline写回。SP-192 alias/observe新鲜度已有独立目标/树身份校验。上游还删除test的实时screen-fingerprint drift判断，不能称新版本提供更强的运行时坐标新鲜度保证；不迁移其geometry安全策略。 |
| SCK回调释放未回复由sentinel deinit立即判handler_dropped；10秒上限；计数SCK与fallback，CI强制fallback=0 | main Sources/CLI测试无ScreenCaptureKit或SCScreenshotManager使用；Simulator framebuffer与host截图源不同。上游提到replayd同二进制多进程冲突未在本机验证；不引入SCK API只为套用优化。可保留为将来新增该provider时的设计参考。 |
| Rust iOS block以steps预算、显式较长wait/measure、scroll倍数和最终截图额度，超预算kill自有process group并收日志 | Triton无Rust mirroir-mcp子进程block。SP-223已交付独立host pipe post-exit drain deadline，main CLIHostProcessDrain.swift已有0.25秒共享deadline、非阻塞read/poll、EOF不足明确host_output_incomplete且不重放。不能把上游Rust预算当本地新缺陷。上游drain仍read_to_end后无独立join deadline，正常child退出而后代持pipe的形态不能由其block child.wait timeout证明已覆盖；不倒退本机已有保障。 |
| serde_json1.0.151→1.0.154、Astro7.4及npm锁文件修订 | Triton CLI为Swift，Web mock无同一Rust/Astro依赖链。上游advisory声明未本地审计验证，不自动安装升级依赖。 |

SP-192/196/200权威README及10月28日评估已读；SP-200排除云fleet/MCP server，不新增上游MCP技能/云控制面。SP-223现有采用登记已交付，不重复分派。未发现需要新BDD/文件面的真实缺口；若以后明确新增iPhone Mirroring或SCK provider，应另建space，先覆盖非US URL/组合键、回调丢失/迟到、source provenance、baseline不可自动批准与预算后副作用unknown。

验证阶段：官方只读API/固定源码/测试文本审阅；未运行上游、未构建、未运行Triton测试、未设备/性能验证。仅写本仓证据子目录，未改result.json、正式docs或成功state。主控负责最终完整性与通知/状态提交。
