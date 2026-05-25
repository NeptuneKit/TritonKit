# 20260524 iOS WebView Snapshot Real Smoke

## 目标

验证本轮新增的 iOS `webview snapshot` 能在真实 `WKWebView` Demo 页面返回受限 DOM、文本、表单与链接摘要，并保持 redaction / truncation 边界。

## 环境

- Simulator：`TritonKit Dedicated iPhone 17`
- UDID：`0333546D-2AC6-4C22-AF01-293E2F4BA5BC`
- App：`Examples/TritonKitDemo/TritonKitDemo.xcodeproj`
- Scheme：`TritonKitDemo`
- Triton server：`127.0.0.1:19421`

## 执行命令

```bash
.build/cli/debug/triton xcode build --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --jsonl --timeout 180
.build/cli/debug/triton serve --host 127.0.0.1 --port 19421
.build/cli/debug/triton xcode run --project Examples/TritonKitDemo/TritonKitDemo.xcodeproj --scheme TritonKitDemo --configuration Debug --simulator 0333546D-2AC6-4C22-AF01-293E2F4BA5BC --jsonl --timeout 180
.build/cli/debug/triton webview list --platform ios --json
.build/cli/debug/triton webview snapshot --platform ios --include metadata,dom,text,forms,links --max-dom-nodes 20 --max-text-bytes 2048 --json
```

## 结果

1. `triton xcode build` 成功完成 iOS Simulator Debug 构建。
2. `triton xcode run` 成功安装并启动 Demo，Demo 连接本机 `triton serve`。
3. `webview list --platform ios --json` 返回 1 个 `webview-provider` 候选。
4. `webview snapshot --platform ios --include metadata,dom,text,forms,links --max-dom-nodes 20 --max-text-bytes 2048 --json` 成功返回：
   - `action=webview.snapshot`
   - DOM node summary：5 个
   - form summary：1 个
   - `redaction.secureText=length-only`
   - form `valueRedaction=length-only`
   - `truncation.truncated=false`

## 结论

iOS `WKWebView` provider 已从 metadata-only 推进到可真实读取 bounded snapshot。该能力仍是 DEBUG runtime 内的固定摘要脚本，不开放任意 JavaScript eval；`webview wait`、Harmony ArkWeb provider snapshot、evidence/replay 接入仍属于后续阶段。
