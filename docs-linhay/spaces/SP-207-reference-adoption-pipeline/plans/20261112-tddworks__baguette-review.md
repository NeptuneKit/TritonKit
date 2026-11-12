# Baguette 候选复核 · 2026-11-12

裁决：revise_first，不直接采用。绑定actual main `0ec972e6151eb27372b3bdf5aa940940c56c30b0`；import base `8930ac601e38e04540cb3cad9547347c160882e4`，checkpoint=null。昨日审阅窗口94b78d36→593a1b4a；今日HEAD仍593a1b4ae699e87bbab444d0d821e45a74b4bc79/v0.2.14、许可全文hash未变。昨日790份证据逐项size/hash复核通过，未修改冻结归档；旧未读及二进制来源缺口仍在，不推进完整checkpoint。

事实：native semantic set-text的request/response无verify/expectedValue/postcondition；runtime clear后重新resolve、insertText并通知，直接ok，未读取最终value。因此“同对象精确回读能力缺失”成立，“现有ok错误宣称业务已验证”未成立。shared输入契约明确submission与verification分离；独立wait/assert/verify能确认可见条件。其role/count/within并非同对象原子精确value，因此也不能把候选写成完全已覆盖。

已有针对性验证面：SP196 WebView同DOM对象即时及50ms读回，Harmony type --verify唯一stable-id/原始完整value/focus/secure拒绝/有界一次提交。native应先证明实际吞键/改写需求和独立验证不足，再选择是否扩展；上游Fill存在不构成立项的充分理由。范围可在现有CLI/HTTP/embedded内，但本轮没有实现授权外推、设备运行或失败测试。

窄化合同：默认旧调用保持动作提交语义；显式验证独立字段，exact不忽略标点/空白；绑定target/runtime generation/具体UI对象/OID及前台状态，clear后的对象替换不得继续输入；secure/masked/不可读UIKeyInput拒绝精确验证，不以长度证明且不输出值；回读只读、有总deadline，任何unknown/部分输入不重放、不补paste。相等只证明当前字段状态，不证明因果/业务完成。BDD与后续候选文件面见review.json。

SP192 freshness/settle/health、SP196 WebView、SP200身份与no-replay、SP281 receipt/evidence分别去重。SP281当前资料是未提交WIP，只用于避免重排，不冒充main交付。

经验检查完成：候选存在不等于采用必要；验证面的缺失与当前成功语义错误须分开证明。供主控回写原采用登记，不新建实现space。
