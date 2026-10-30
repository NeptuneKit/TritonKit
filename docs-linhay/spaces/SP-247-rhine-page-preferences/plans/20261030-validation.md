# SP-247 页面偏好验收（2026-10-30）

阶段：独立候选设计验收通过，已同步主目录并完成142/142测试、生产/设计构建复验。未提交、推送或发布。

## 制品与范围

实际固定 npm `@linhey/rhine-design@0.11.3`，来源 `https://registry.npmjs.org/@linhey/rhine-design/-/rhine-design-0.11.3.tgz`；完整摘要沿用 SP-245 制品记录。lockfile 和随包 skill 与开工基线逐字节一致，无依赖漂移；package.json 仅新增树回归测试入口。React19/Vite7/Node24.21.0。

四个官方 review 场景复用实际 StreamPanel、InspectorPanel、RunWorkbenchView、WorkspaceCanvas/WorkspaceShell。设计与合成数据仅在 Web/design，正式构建仍由隔离 guard 防止导入。预览命令 `cd Web && npm run design:build && npm run design:preview`，地址 http://127.0.0.1:34128/ 。

## 通过

- Node24 + `TRITONKIT_TRITON_BIN` 绑定本机现有 triton：Web 全套142/142通过；设计类型检查及构建通过。主目录生产/设计构建均通过。
- 4场景×3主题×400/520/880×100%/200% CSS zoom，72组长文本无页面/关键控件横溢出。最终44px树命中区与删除修复后，层级页长文/26层深树另复验36组，0溢出。
- 相同1280画布、754高、外窗1600×1050：设备viewport从top333/height403变为top206.3/height539；树起点从517变为329.3。独立菜单工具栏2→0。正文尺寸不减；前后截图为合成数据，不是设备帧率或真实性能测量。
- 运行页：任务/唯一身份/目标/partial或unknown/Provider未就绪/暂停常显；失败、读取中保留旧数据；全部页签、折叠详情、路径来源与命令可达，长命令不撑开页面。复制仍以Promise结果为准，不执行。
- 设备页：400px/200%下FPS Popover在画布内（x12–386/398），15→30更改实际图像请求参数；空/图像失败及重试入口；隐藏释放img、恢复重新显示。原控制器取消/geometry/偏好逻辑保留。
- 层级页：三主题400px/200%下固定/跟随与来源Popover保持在画布内，当前固定值常显；Harmony单源说明保留。加载/错误保留旧节点，空结果明确；节点Dialog全部Geometry/View/Layer/AX/Raw页签可达，复制失败可见，Escape回到节点详情按钮。AX文本输入自身编辑滚动不计页面溢出，未缩字号或截去值。
- 窗格Menu合入标题，真实浏览器操作更换→选择运行页、左右/上下分割、关闭；菜单四动作保持；关闭后焦点到工作台。无独立空工具栏。
- 树嵌套group、单Tab停靠、方向键只移焦点、Home/End显露实际行（非含子树wrapper）。深叶删除恢复到deep-22（实测y614–674/视口754），显式blur后刷新保持BODY，外部刷新按钮不被抢焦点。
- 真实动态：第一次高亮约66→217ms，连续更新约67ms重新开始；treeitem DOM身份与焦点保持，仅视觉行重建，1秒后清理。系统/手动减少动态均animation:none，保留“已更新”文字。树不提供paused；流可见性暂停/恢复另实测。卸载timer清理由现有测试覆盖，浏览器场景反复卸载未见残留标记。

## 发现、修复及反证

- 各写入面先新增失败断言再实现；最终142项通过。第一次联合设计构建在子任务尚未添加headerActions时类型失败，冻结候选后通过。
- 真实删除最深节点最初落焦BODY，而恢复模型测试为绿。浏览器在DOM detach前focusout，此时isConnected仍true；修复结合待提交可见节点集，新增失败回归再通过，浏览器重验父节点恢复及显式blur不抢焦点。没有把模型测试当真实焦点证明。
- 同节点连续刷新旧动画不重启：增加revision重建视觉行，treeitem稳定。移除只暂停CSS、不暂停寿命timer的旧paused规则。
- 单独旧highlight测试未设置triton路径时启动失败；完整Web命令显式绑定triton后该项通过，不归为产品断言缺陷。

## 上游回流与剩余边界

[信息层级/多窗格组合 #14](https://github.com/linhay/rhine-design/issues/14#issuecomment-6515899375) 与 [树规范回接/真实焦点发现 #117](https://github.com/linhay/rhine-design/issues/117#issuecomment-6515924782) 已脱敏提交并逐字回读，草稿与回执同目录保存。#117规范已接受/源码已实现，registry仍旧0.11.3；产品组合已验证，未声称npm已发布或升级。后续固定可消费制品覆盖并验等价后移除临时适配，纯配方可能仍需保留产品实现。

未执行：真实设备/MJPEG运行、UIKit/Wails、Swift/CLI全套及verify --local（本轮仅Web）；浏览器原生200%缩放、读屏、全树删除到空结果的真实焦点恢复。全树空状态由EmptyState接管，模型空树停靠有单测，不能扩称浏览器验证。静态SVG与CSS zoom不替代上述边界。

## 主目录接回

以开工快照（非旧HEAD）逐文件三方整合39项实现/文档/证据变更；EXPERIENCE并行变更干净三方合并，未覆盖原生/CLI或其他space工作。锁文件、固定依赖、随包skill不变。主目录静态生产制品在1280和400px浏览器烟测：三页菜单都在真实header内、没有旧空toolbar或review入口、默认arknights、无页面横溢出。请求由浏览器注入空DTO拦截，不连设备；RunCard保留已有mock，不宣称真实Run服务接入。

主目录文档门禁通过（结果见本报告末尾）；未执行Git提交。

文档首检发现路线总览的顶部与表格重复使用完整space链接标签，不符合唯一索引规则；已保留表格唯一标准链接，顶部改简短说明标签后复验。

最终主目录 `verify.sh --ci-docs`、`check-docs.sh`（247 spaces）、`git diff --check` 全部通过；本次新增/已修改文本另按完整文件检查空白无错误。Web候选与主目录文件逐字一致，摘要见[候选SHA256](20261030-candidate-sha256.json)，lock与随包skill逐字保持开工版本。最终设计预览由主目录dist-review提供，浏览器回读标题/菜单/主题正确。
