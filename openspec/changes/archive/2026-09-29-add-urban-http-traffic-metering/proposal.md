## Why

UrbanManagement 生产机（IIS in-process）出现明显卡顿，需要按接口确认请求/响应体流量消耗；当前仅有混在业务文件中的 Serilog，无法按 Path 汇总带宽，排查会被业务日志淹没。

## What Changes

- 新增 ASP.NET Core HTTP traffic metering 中间件：按请求统计 Method、Path、StatusCode、RequestBytes、ResponseBytes、ElapsedMs
- Traffic 事件写入**独立日志文件**（与 `Logs/log-*.txt` 业务日志分离），使用固定 SourceContext，不进入业务 File sink
- 通过 `HttpTrafficMetering` 配置开关、路径前缀包含/排除；默认仅计量 API 路径，排除 Blazor/SignalR hub 长连接握手噪音
- 流式计数，不整包缓冲请求/响应体；不引入 AppInsights / OpenTelemetry / Prometheus（本 change 范围外）
- **不**采用 IIS W3C 日志方案

## Capabilities

### New Capabilities

- `urban-http-traffic-metering`: UrbanManagement 应用内按 HTTP 接口计量请求/响应字节并写入独立 traffic 日志

### Modified Capabilities

- （无）

## Impact

- **子仓库**：`repos/UrbanManagement`（`UrbanManagement.App` 中间件注册与 Serilog 配置）
- **部署**：IIS in-process 发布后生效；运维查看 `Logs/traffic/`（路径可配置），与业务 `Logs/log-*.txt` 分开轮转与保留
- **性能**：中间件流式包装 Body，额外开销应保持较低；可通过配置关闭
- **分支**：Mode A — 各涉及仓自 trunk 切出同名分支 `add-urban-http-traffic-metering`
