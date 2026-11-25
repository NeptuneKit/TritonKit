# RECORDING-START-OWNERSHIP 录屏启动与归属

业务真源为 [设备录屏契约](../../docs-linhay/dev/20261015-mobile-device-parity.md)与 [#285 验收](../../docs-linhay/spaces/SP-295-issue-285-recording-worker-startup/README.md)。

1. 通过 PATH 或绝对路径启动相同 CLI，均能派生同一会话的 worker。启动回执须区分已认领会话和运行失败。未成功启动的 worker 仍用已有的 `recording_worker_unavailable` 失败契约。
2. 仅超时且没有 worker 或 recorder 身份的 `starting` 可被同目标下一次启动处置。正在等待或已认领的会话阻止重复启动。预留清理须核对归属、设备号、inode、类型和长度。替换文件保留原样。
3. `completed` 须有验证过实际视频样本的 MP4；注入的采集失败不能得到 `completed`。

使用 `swift test --package-path CLI --no-parallel --filter DeviceRecordingTests` 验证注入失败、立即重试、超时认领语义与实际 CLI worker 启动。最终媒体另以自有录屏或受控输入 MP4 检查，不以只收到启动回执代替。若装载的 SwiftPM 测试使用自定义 scratch，设置 `TRITON_CLI_PATH` 为同次构建的 CLI。
