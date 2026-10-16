# SP-201 方案与交互设计验证

- 日期：2026-10-15；主仓 `<repo-root>`，HEAD `dd613a99`，本轮未提交候选为 SP-201、技术设计及索引/memory。SP-193 原有 WIP 未修改。
- 阶段：需求/方案/离线浏览器交互设计。没有 SDK 实现、iOS 编译、设备操作、主线集成或发布。
- 原型：[picker-design.html](../picker-design.html)，单文件无外部依赖。仅 `127.0.0.1:34128` 静态预览，没有设备/agent 连接；为评审保留预览服务。

## 通过

- `docs-linhay/scripts/verify.sh --ci-docs`：文档结构、201 spaces、经验路由及已有隔离检查、版本/打包/发布契约均通过。
- `docs-linhay/scripts/check-docs.sh`、`git diff --check`：通过。
- 原型 JavaScript 静态语法检查：通过。
- Playwright Chromium，1380px 桌面与 390px 窄屏；[交互验证脚本](./20261015-browser-check.js) 14 项断言通过：
  1. 拖动到按钮可标记。
  2. 拖选后业务点击为 0。
  3. 模拟读取再执行后业务点击准确为 1。
  4. 读取后重选，旧 revision 执行被拒绝。
  5. 拒绝后业务点击不增加。
  6. 模拟目标失效后拒绝执行。
  7. 切换父层级后仅观察，不可执行点击。
  8. Esc 取消拖动保留旧标记版本。
  9. 点击圆点展开菜单。
  10. Esc 关闭菜单。
  11. 清除后旧目标执行被拒绝。
  12. 390px 窄屏没有横向溢出。
  13. 窄屏拖选可标记。
  14. 窄屏拖选不触发业务点击。
- 补充检查：移动入口的键盘方向键不改变 selection revision/业务计数；桌面文档宽度等于 viewport；最终重载无 console error/page error。
- 最初静态预览的 favicon 请求 404，已改内嵌 data favicon，最终重载零错误；`file:` 导航被浏览器工具阻止，改用固定 preview 端口读取静态文件。
- 桌面及窄屏截图已实际打开核对，文字/控件无横向溢出。窄屏的浏览器测试使用鼠标指针模拟，不等价于真实触屏验收。

## 证据与复跑

- [桌面已选中设计截图](../screenshots/20261015-picker-desktop-selected-v01.png)
- [窄屏已选中设计截图](../screenshots/20261015-picker-mobile-selected-v01.png)
- [初始设计截图](../screenshots/20261015-picker-idle-design-v01.png)
- 截图为 mock 设计，不是原生运行证据；截图目录沿用项目忽略规则，文件在本地。
- 在仓库根目录用静态 HTTP server 将本 space 服务于 `127.0.0.1:34128`，打开 `/picker-design.html`，再执行 `playwright-cli -s=sp201-design run-code --filename=docs-linhay/spaces/SP-201-sdk-floating-picker/plans/20261015-browser-check.js`。脚本只操作本地 mock，不接设备；浏览器需已导航到该页面。

## 未执行与后续

- Swift/CLI/App-hosted/UIKit/Release/真实设备测试未执行：本轮按用户要求交付方案与交互设计，未改产品实现。
- SDK 浮层窗口排除、跨 scene、触摸泄漏、cell 内容身份、真实 agent/HTTP 闭环仍待实现验证；浏览器原型不能替代。
- 经验已回写 [原技术方案](../../../dev/20261015-sdk-floating-picker.md) 的风险和下次检查；未修改 repo-wide 规则或重复新增经验索引行。
