# Revyl CLI 2026-10-28 固定增量复审

结论：observe；没有可直接派发的本机 CLI 产品缺口。影响候选为 agent skill 导入说明；云组织认证和 hosted computer 不进入 TritonKit 当前本机控制面。

## 来源与变化

- 上游固定范围：`6e66797f4a5c60167bde443f6bffa47d0bb70038...8ecfb9f8b1591ac35ad3a3576e9d1df016dd2c33`。GitHub 官方 API compare 第1页6提交、第2页0提交；6份完整 commit 文本文件清单/patch 均保存。共31路径，27文本按路径筛选后下载固定SHA完整源码，4个`__pycache__/*.pyc`仅保留API metadata，未下载、反编译或执行。
- [固定 compare](https://github.com/RevylAI/revyl-cli/compare/6e66797f4a5c60167bde443f6bffa47d0bb70038...8ecfb9f8b1591ac35ad3a3576e9d1df016dd2c33)。证据：compare-page-{1,2}.json、commit-*.json、commit-patches.txt、patches.txt、source-*.txt、path-screening.json。
- release观察v0.1.192→v0.1.195；releases-1.json中本段只列出v0.1.193/v0.1.195，完整body见release-notes.txt，两者均是安装、standalone computer、skill与checksum说明，没有功能changelog；没有假设不存在于列表的v0.1.194发布。固定head的VERSION/npm/Python实际已0.1.196，latest release不是head版本。
- `649f24c`新增375行import-tests skill、三份格式参考与agent manifest，并接入embed/catalog/help/base skill路由。它要求全套case清点、source→目标映射、不可转步骤REVIEW、保留断言及scope/count、secret不写文件/命令、明确组织写入授权、有界运行与失败分类。这是指导agent手工/LLM转换到Revyl goal-level YAML的流程，并非新增Playwright/Maestro/Appium解析器。
- `ac965d4`把computer与device start --computer从隐藏改为实验opt-in可见；错误提示指导组织owner/admin在Settings请求开通。e2e仅改变hosted mock所patch方法为异步computer_os_enabled_for_org，没有提供hosted实现。
- `31891ed`新增REVYL_AUTH_DIRECTORY，以trim后的目录/相对路径绝对化覆盖默认~/.revyl，统一隔离credentials、client identity、Cloud context，并使login输出实际路径；新增默认路径及隔离测试。它不是通用sandbox或多worktree设备状态隔离实现。
- `8ecfb9f`只把workflow文档并发cap范围由iOS/Android改为iOS/Android/Web；其余两个提交只有pyc变化。版本同步在三个文本功能提交中，不重复算成三项产品能力。

## 实际 main 去重与收益边界

对照实际main `a0d187ace03d6e56b79b50a7a601c91b359b7955`；local-main-evidence.txt保存当前导入实现与命令文本。

1. **测试套件导入：观察。** Triton现有CLITestImportRuntime只接受已编译、未截断、capability可支持的`.tritontestcase`→`.tritontest.yaml`，显式bundle/platform，P0仅ios-simulator，拒绝覆盖/摘要漂移；它不是第三方suite translator。上游提供清点/追溯/不削弱断言的流程启发，有利于未来降低迁移漏项，但没有同执行模型的解析器可移植。Revyl目标是云端agent解释意图，Triton是显式本机确定性动作/断言，不能照搬“丢弃selector、wait、scroll、fresh-install/login假设”到现有replay；网页→mobile语义转换同样不能自动宣称等价。保留为未来用户明确请求第三方case导入时的独立需求，不据此新增通用LLM执行器或当前实现任务。
2. **认证目录覆盖：观察。** Triton的本机runner/bridge授权不是Revyl组织登录。没有云org、API key登录与Cloud context，不能为拥有同名环境变量而新增认证系统；将来确有跨worktree身份串扰再针对真实状态面设计。SP-196的安装/config备份、冲突、原子替换已交付，不重新派发为本次认证目录优化。
3. **Cloud computer/实验入口/Web并发：拒绝采用。** SP-200明确排除cloud fleet/远端预订/MCP；上游此次没有本机设备能力新增。实验入口显式说明边界是好说明方式，但不构成Triton新增Settings/组织控制台理由。Web并发文案不证明执行调度新实现。
4. **已交付去重。** SP-192已交付alias新鲜度、预算、settle/OCR/UI健康；本次未改变这些机制。SP-196已有foreground/证据、测试复用、配置/skill安全迁移；SP-200本机环境/录屏/诊断/归档安装/输入/终端镜像已进入main。上述不因上游导入指导或cloud help可见重新计为gap，也不重复创建space。

## 完整性与不确定性

- 今日**允许采集的文本增量**已审完：compare分页穷尽、6个commit文件数均小于100且未达到API上限、27文本完整保存、净patch与commit中间patch均检查。未执行上游、安装依赖、调用设备、读实际身份材料或远端写入；没有真实运行/收益证明。
- 4个今日pyc变化无法从文本证明语义，不下载二进制的约束下保持未知；不能将文本复审完成描述为仓库全部内容完整可审。历史pyc/hosted源码缺口继续保留。
- license.error-0.txt为官方licenses接口HTTP404。README MIT badge与Pythonlicense=MIT不是许可证全文；全文、归属与授权无法核实，不直接复制源码/skill。此历史partial不会被complete_review覆盖。
- `complete_review=true`只表示本轮固定范围内可允许文本复审完成；overall完整性仍partial（license、pyc、hosted）。没有新增实现，BDD采用验收不适用。未来采用必须新建/更新space并先证明source-case清单完整、断言语义保真、unsupported fail-closed、secret不落盘及目标平台/执行边界，再单独实现与验收。
- 本轮仅写隔离证据目录；没有共享docs/state/产品变更，因此不运行共享构建或docs门禁。可复用判断已写本review供主控SP-207治理记录，未产生需另增权威规则的新经验。
