# Runner feedback

For the bundled iOS product workflow, see [Runner regression](../../tritonkit-real-project-regression/SKILL.md#bundled-ios-runner-regression) and preserve `triton schema --command device.runner --json`. Target apps need no embedded SDK; the CLI includes its Runner and native USB transport without Appium/WebDriverAgent/Python/iproxy runtime dependencies. Xcode, compatible SDK, pairing, Developer Mode, signing, unlock and UI Automation authorization remain system prerequisites. Report prepare, health, prior automation proof, action receipt and business outcome separately. Safari input/navigation is not live-validated, and a TTL session is not permanent background or standalone operation.

## Runner 启动失败诊断

Runner `start` 失败的 `error.startup` 分开报告 `launch`、`transport`、`health`、`uiAutomation` 的 `verified|unverified`；transport 指本次收到经过鉴权的 Runner 响应，不代表 XCTest DTX 已就绪。已知 native XCTest driver channel refusal 返回 `ios_runner_xctest_driver_channel_refused`；启动失败、就绪前进程退出分别为 `ios_runner_native_launch_failed` / `ios_runner_native_exited`，其余仍用 `ios_runner_start_not_ready` 并指出未验证阶段。公开响应仅使用固定分类，不回传原始日志、路径、配对或签名身份。分类只读本会话 native logs 的有界尾部，未命中特征不表示无原生错误；不要假设解锁即可修复，也不据此诊断确定的 Apple 工具链问题。保留 private session，检查配对/授权/XCTest兼容性后先 stop/recover，再显式启动新会话。CLI与HTTP使用同一 service/envelope。

### Runner 观察与坐标几何

Runner `inspect` / `screenshot` 自行读取前台 App 的 `app.frame` 与 XCTest device orientation。未知方向不再丢弃已取得的层级或 PNG：结果标记 `partial=true`、`geometryAvailability=unavailable`、`coordinateActionsAvailable=false`，附固定的 `geometryError.code/message/field`，并省略 `geometry` 和 `observationID`。旧坐标观察立即失效；不得根据图像尺寸猜测方向或复用旧 ID。已返回的最新语义 selector 仍可使用。缺少有限正值 App frame 返回 `observation_window_unavailable`，App 不在前台仍返回 `cross_app_not_foreground`。`appAlertPresent` 仅覆盖该 App 的 alerts；`systemAlertDetection=not-probed` 不证明无系统弹窗。恢复已知方向并重新观察后才可使用坐标动作；截图仍是敏感的整屏证据，不保证只包含目标 App。
