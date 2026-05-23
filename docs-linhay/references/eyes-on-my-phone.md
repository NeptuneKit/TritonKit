# Eyes-on-My-Phone Reference

- GitHub: `https://github.com/karminski/eyes-on-my-phone`
- 主题：Android 端 MCP 代理，提供 on-device vision-language inference，把手机变成 Claude Code 的远程眼睛和耳朵。

## 对 TritonKit 的参考价值

1. 直接 HTTP MCP 暴露工具，而不是依赖桌面桥。
2. 以 `phone_look`、`phone_listen`、`phone_watch_*` 这类稳定工具名组织能力面。
3. 把模型推理、watchdog、配对认证、远程访问和 demo scripts 分层。
4. 明确原始音视频不上传云端，偏向本地推理和受控传输。

## 结构观察

- `android-app/`：Kotlin MCP server + capture + inference + watchdog。
- `mcp-schemas/`：工具 JSON schema。
- `prompts/`：VL / safety / watchdog prompt 模板。
- `docs/`：架构、教程、配置与排障。
- `skills/eyes-on-phone/`：可复用的 agent 侧技能材料。

## 结论

这个仓库更适合作为“移动端本地推理 + MCP 工具暴露”的参考，而不是 TritonKit 当前本机 simulator / emulator host adapter 的直接实现模板。
