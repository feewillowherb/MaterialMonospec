## Context

- UrbanManagement（ABP / ASP.NET Core / IIS inprocess）当前管道无 HTTP 流量计量；仅 `Serilog` → Console + `Logs/log-.txt`。
- 生产卡顿排查需要按接口看 Request/Response 字节与耗时；业务日志量大，混写会干扰排查。
- 用户明确：**不做 IIS W3C**；**traffic 与业务日志必须分离**。

## Goals / Non-Goals

**Goals:**

- 在应用层按 HTTP 请求计量并记录 Method、Path（含 Query 可选）、StatusCode、RequestBytes、ResponseBytes、ElapsedMs。
- Traffic 写入独立滚动文件（默认 `Logs/traffic/traffic-.txt`），**永不**写入业务 `Logs/log-*.txt` / 业务 Console 策略。
- 可配置启用、路径包含/排除；默认覆盖 `/api`、`/Api`，排除 Blazor / SignalR hub。
- 流式计数，避免为计量整包缓冲最大 16MB body。

**Non-Goals:**

- IIS W3C / Failed Request Tracing。
- OpenTelemetry、AppInsights、Prometheus、Grafana。
- 对外公开 diagnostics HTTP API 或 Blazor 流量看板（本 change 不做；若后续需要另开 change）。
- 精确计量 WebSocket/SignalR 帧带宽（仅可记录握手类 HTTP 或直接排除）。
- 根治卡顿（本 change 只提供证据，不改业务路径）。

## Decisions

### D1: 独立 Serilog Logger 实例写 traffic 文件（强制与业务分离）

**选择**：为 traffic 单独 `LoggerConfiguration().WriteTo.File(...).CreateLogger()`，经 `IHttpTrafficMeterWriter`（或同文件 interface+impl）注入中间件；**不**走宿主 `ReadFrom.Configuration` 的业务 sinks。

**理由**：用户要求与业务日志分离；现仓未引用 `Serilog.Expressions`，仅靠 appsettings Filter 易漏配导致混写。独立 Logger 从架构上隔离。

**备选否决**：

| 方案 | 否决原因 |
|------|----------|
| 同一 Logger + Filter 分子文件 | 依赖表达式包/易配错，业务 sink 仍可能收到事件 |
| 直接 `ILogger<Middleware>` | SourceContext 仍进全局 File sink，必然混写 |

业务 `appsettings.json` 的 `Serilog` 段**不**增加 traffic SourceContext 的 File 目标（避免双写幻觉）。

### D2: 中间件挂载点

**选择**：`UrbanManagementAppModule.OnApplicationInitializationAsync` 中，`UseStaticFiles` / `UseRouting` 之后、`UseConfiguredEndpoints` 之前调用 `app.UseMiddleware<HttpTrafficMeteringMiddleware>()`。

**理由**：静态文件已短路，不计量 wwwroot/`ClientLogs`；路由已可用；覆盖 Auto API、显式 Controller、tus。

### D3: 流式 CountingStream

**选择**：包装 `Request.Body` 与替换 `Response.Body` 为只计数的 `Stream` 装饰器；`await next()` 后 flush 并写一条 traffic 记录。无 `Content-Length` 时以实际读写字节为准。

**备选否决**：读完 body 再计长度（内存与延迟风险，尤其 Legacy `/Api/Post` base64）。

### D4: 配置模型 `HttpTrafficMeteringOptions`

建议形状（实现可用 record / Options 类）：

| 属性 | 默认 | 含义 |
|------|------|------|
| `Enabled` | `true` | 总开关 |
| `PathPrefixes` | `["/api","/Api"]` | 仅计量此前缀（大小写敏感路径按 ASP.NET 惯例） |
| `ExcludePathPrefixes` | `["/_blazor","/hubs/"]` | 排除 |
| `IncludeQueryString` | `false` | Path 是否带 query（默认否，降低基数与敏感信息） |
| `LogFilePath` | `Logs/traffic/traffic-.txt` | 相对 ContentRoot |
| `RetainedFileCountLimit` | `14` | 独立于业务 30 天 |
| `RollingInterval` | `Day` | 日滚 |

未匹配前缀或命中排除：直接 `next()`，不包装 Body、不写文件。

### D5: 日志行格式

结构化属性（Serilog 属性）至少包含：

`Method`, `Path`, `StatusCode`, `RequestBytes`, `ResponseBytes`, `ElapsedMs`, `TraceIdentifier`（可选，便于与业务日志关联但不写入业务文件）。

消息模板示例：  
`HTTP {Method} {Path} → {StatusCode} in={RequestBytes} out={ResponseBytes} {ElapsedMs}ms`

### D6: DI 与生命周期

- `HttpTrafficMeteringOptions`：`IOptions` / `Configure<>` from `HttpTrafficMetering` section。
- Writer：`ISingletonDependency` 或显式 Singleton；持有独立 `ILogger`（Serilog），`IHostApplicationLifetime` / `IDisposable` 时 `Dispose`。
- Middleware：常规 ASP.NET middleware；计数逻辑可用 static/helper，**不**为纯 CountingStream 注册 DI（遵循 minimal-di）。
- 类型与 interface **同文件**，文件名 = 实现名（UrbanManagement `AGENTS.md`）。

### D7: 不暴露聚合 API

本 change 仅文件埋点。运维用文本检索 / 简易脚本按 Path 汇总。避免新增匿名 HTTP 面与鉴权讨论。

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| 高 QPS 下 traffic 文件 I/O 加重卡顿 | `Enabled` 可关；默认可后续加采样（本 change 可不做采样，先全量 API） |
| Response 未完整写出时字节偏小 | 以实际写入 CountingStream 为准；文档注明近似于应用层字节，非 NIC 线速 |
| WebSocket 升级后无 body 计量 | 默认 Exclude `/_blazor`、`/hubs/` |
| 独立 Logger 与业务时钟/级别不一致 | Traffic 固定 Information；不依赖业务 MinimumLevel |
| IIS 站点权限无法写 `Logs/traffic/` | 启动时 EnsureDirectory；写失败记一次业务 Error（用宿主 ILogger），避免每请求刷屏 |

## Migration Plan

1. 发布含中间件与默认 `HttpTrafficMetering` 的包到 IIS 站点。
2. 确认应用池身份对 `{ContentRoot}/Logs/traffic/` 可写。
3. 观察 `Logs/traffic/traffic-*.txt`；业务 `Logs/log-*.txt` 不应出现 HTTP traffic 模板行。
4. 回滚：配置 `HttpTrafficMetering:Enabled=false` 或回退上一版本；traffic 目录可保留。

## Open Questions

- （无阻塞）是否在后续 change 增加按 Path 的内存聚合与受保护的 diagnostics 端点——本 change 不做。
