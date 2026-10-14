# 2026-10-14：跨 App 与多场景实验

用户追加：“你试试更多的 app 和场景”。沿用SP-193独立worktree和已选择的有线iPhone；主控串行设备动作，Runner/host workers仅独立文件实现与离线测试。产品CLI/HTTP/embedded不改变。

## BDD与边界

1. Given同一Runner会话，When依次activate fixture→设置→计算器→Safari→fixture，Then分别采集该App的UI及截图，验证目标前台/特征元素；禁止单用host启动返回值判成功。
2. Given已观察的唯一selector与expectedBundle，When发送点击/输入，Then在执行前重查target与selector并用后置状态验证；不匹配/缺失/歧义不执行。
3. Given计算器公开按键，When完成一个简单算式，Then根据实际显示或AX公开输出验证结果。
4. Given设置公开导航，When进入一个普通页面/滚动/返回，Then验证页面元素变化；不改变开关、账号、隐私、网络或开发设置。
5. GivenSafari，When通过当前地址栏导航固定example.com，Then验证示例页面及滚动/输入；不访问私人tabs/账号/消息，不提交任意URL或用户数据。
6. Given离开fixture后返回，Thencounter状态保持；旧selector未重新inspect时拒绝，重复同ID不再次执行。
7. Given错误app/bundle/op、无inspect、过大预算或错误token，Then先协议失败，不误报业务通过。

范围固定fixture+设置+计算器+Safari。该实验不覆盖用户业务App、任意第三方App、系统安全页面、后台/锁屏永久运行。私有原始树及截图不公开；只归档审核过的公共页面/fixture证据。

## 执行记录

保存新Triton-firststatus/doctor/capabilities/schema/plan、设备列表和锁屏状态。plan对于自由文字请求可能unsupported，保留失败，不伪装成功；标准xctestrun测试env仍需nativefallback。每次启动新session，构建/真机动作串行。单测先失败再实现，真机结果独立于Simulator。

当前状态：本轮实验已完成，实际部分通过。Calculator 7+8=15 / 重复请求去重、Settings 滚动 / General / 返回、fixture AX 状态保留通过；Safari 激活 / AX 通过，输入焦点返回 cross_app_focus，网页导航与网页滚动未通过。全屏截图存在 App 归属不匹配，不能用 endpoint 元数据替代画面验收。最后真机 testServe 179.109s / exit0；旧失败保留。52 条离线测试通过。详见 [结果报告](./20261014-cross-app-results.md) 和 [脱敏 JSON](./20261014-cross-app-summary.json)。
