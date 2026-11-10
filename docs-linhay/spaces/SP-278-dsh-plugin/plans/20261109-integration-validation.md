# SP-278 · 2026-11-09 提交与整合验证

## 当前阶段

用户13:02追加授权“验证，提交，合并，推送”。0.1.1实现、安全修复和CI接线已通过精确合并提交 `f4efd202` 推送到远端main，DSH plugin与主CI均成功；当前归档只更新交付记录，不改runtime。

- 原主目录保持 `main@d94213c4` 及原有WIP；其15条远端未包含的历史提交不在本次推送范围。
- 本插件初始提交 `1c346611` 保留于 `archive/SP-278-initial-candidate`；仅将该提交相对原基线的增量重放到远端 `d592ea058101a4bf175139d7d2da652de81779c7`，生成 `7bc7fac4`。
- 冲突只在编号索引、主记忆和2026-11-09当日记忆；保留远端SP252～277登记与发布事实，只增加本插件信息，不带回原分支DTUHID/参考采用旧结论。

## 独立审查与修复

合并前只读审查在29项绿色测试之外发现普通名称alias P1与打包回归覆盖P2：

1. CLI alias用普通名称（例如phone），且先于raw ID匹配。旧过滤仅拒绝保留词/alias:，仍可能在排队后读取变化的映射。
2. 0.1.1强制所有目标使用discovery命名空间sim:/ios-real:/android:/harmony:/triton:；裸名称、裸serial/UUID拒绝，不再normalize回裸ID。CLI alias名称语法不允许冒号，相关resolver能精确匹配discovery ID。
3. 新负例首先真实失败，补生产边界后通过；覆盖query/action/verify在进程lookup前拒绝，以及各平台namespaced ID保持同一argv。
4. 新增真实npm pack与tar清单回归；package.files声明也显式测试。当前归档恰含8文件，不把源码存在误当packed完整。
5. 新增独立Node 22 workflow；DSH-only运行Node与contracts，混入Swift/Pod/未知路径保留原升级规则，分类测试先红再绿。

## 本地验证

- Node **32/32通过**、两个runtime语法检查通过：[整合测试日志](20261109-integration-tests.log)。包含实际npm打包，不只mock。
- `verify.sh --ci-docs`完整通过，278个space结构通过、经验测试28项通过，版本/skill/release契约通过：[整合文档日志](20261109-integration-docs.log)。旧编号失败已由真实远端登记整合解决，旧失败日志保留为历史。
- Homebrew契约、CI分类正负例、workflow YAML解析、`git diff --check`通过。
- 没有Swift/CLI实现改动；未再构建SDK/Runner、重跑Swift全量或执行真实设备动作。新工作区的Swift产品以远端main权威版本为准。

## 当前profile运行接替

- 按plugin_manager的already-installed指示，正式移除旧包并重装同一来源，最终`@neptunekit/dsh-tritonkit-host@0.1.1`、application=applied、warnings为空，无build scripts或豁免。
- 新guard验证使用`verify(target=phone,text="")`：无论旧/新版本都应在解析阶段失败，不会启动CLI；实际返回新namespaced目标错误，证明新guard在当前实例运行。
- 重装后version真实调用：CLI0.2.42、exit0、success=true、cleanup=confirmed。先前本轮status复验也通过；没有启停共享服务或操作App。
- GUI实际metadata渲染仍因认证限制未验，不读取token/cookie。四工具、中英locale和SVG静态/打包契约通过。

## 新版产物

- 本地构建产物（不纳入Git）：`DSH/dist/neptunekit-dsh-tritonkit-host-0.1.1.tgz`，12158字节。
- SHA-256：`c38bda450de89b3cab57412b70681372a5c2fc09479900cb16b3d2482658b1d9`。
- [新版包验收与来源hash](20261109-package-v0.1.1-verification.json)。0.1.0原始报告与hash保持历史，不用于证明0.1.1。
- profile为目录link，保留源码worktree；未发布npm、创建tag或GitHub Release。

## 推送与CI

- 实现提交：`7bc7fac4`；安全/分发修复与整合验收：`4dd8f334`。
- 干净整合分支 `integrate/SP-278-dsh-plugin` 从精确远端base建立，以 `--no-ff` 合并插件；合并提交 `f4efd202dbddcc092d5fc6235d3f6fb34cf8dd6f`，合后Node32、完整ci-docs与Homebrew契约再次通过；DSH tree与受测插件分支完全一致，CI分类为contracts。
- `git push origin HEAD:main`成功；`git ls-remote origin refs/heads/main`回读同一完整SHA，无force push。
- [DSH plugin CI](https://github.com/NeptuneKit/TritonKit/actions/runs/42567027803)：精确SHA f4efd202，completed/success，Node22契约与真实打包测试。
- [主CI](https://github.com/NeptuneKit/TritonKit/actions/runs/42567027625)：精确SHA f4efd202，completed/success。
- 原主目录仍为main@d94213c4，工作区status清单摘要与任务开始一致：`cc9c6a0c5b6fecfb5a5798c769e0b002b800754c20720796b75e119e5826c3c8`。未reset、stash、切走该主目录分支或捎带15条无关提交；故本地主目录main仍与远端分叉，这是保护WIP的明确边界，不冒充其已同步。
- 本次归档更新只涉及文档/记忆/索引；提交与推送后仍需核对它自己的CI，不能以f4的CI替代。source link worktree保留；没有npm/tag/Release发布，也未触碰设备或共享服务。
