# SP-142 Web Readonly Contract Plan v0.1

## 目标

将 Web mock 实现收敛到已声明的只读 DTO / 诊断边界，保留 CLI 与通用 HTTP 控制入口。

## 顺序

1. 以 route / HTML / bridge focused tests 固定 red contract。
2. 复用统一 readonly error factory，拒绝 `/web/*` 写路由。
3. 去除 React、embedded HTML 和 Vite bridge 的 write dispatch。
4. 运行 Swift + Node + build + docs 验证；只创建本地 checkpoint。

## 拒绝项

- 不将 Web fallback 改为隐式调用 `triton act`。
- 不启动任何 Web/server/Simulator/设备进程作验收。
- 不触碰 #164，亦不将 SP-141 未集成内容复制进本 branch。
