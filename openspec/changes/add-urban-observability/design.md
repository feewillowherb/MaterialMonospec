## Context

UrbanManagement 的接入、附件、实时、管理端、Worker 和 Migrator 都从 `UrbanServiceHost` 启动，Serilog 写控制台和 `Logs/log-.txt`。网关和 `UrbanManagement.XiaoShanResource` 各自有 `Program.cs`，资源化站点不引用 Hosting 或 Core。Compose 只把网关和资源化站点的端口发布到宿主机，日志留在各自的卷里。

2026-11-16 的实验用 `net10.0`、Serilog 4.3.0 和 `Serilog.Sinks.OpenTelemetry` 4.2.0，向 138 上的 `otel/opentelemetry-collector:0.136.0` 发送了一条 OTLP HTTP 日志，收集器收到了正文和服务名。证据在 `pipelines/graphs/.local/fev-otel-138/result.json`。这次实验没有启动查看页面，也没有发送链路或指标。

## Goals / Non-Goals

**Goals:**

- 同一套 compose 里能按服务查看日志、请求链路和进程/HTTP 指标。
- 应用只向收集器导出。查看页面单独开端口。
- 未配置导出地址时，现有控制台和文件日志照常工作。

**Non-Goals:**

- 不替换文件日志，不把日志送进业务库。
- 不把查看页面放进 `um-gateway` 或任一业务登录。
- 不做长期日志留存，不引入 Grafana、Loki 或 Prometheus。
- 不改业务接口、产品编码和网关路由。

## Decisions

### 遥测库只做注册

新增类库 `UrbanManagement.Telemetry`。它提供静态注册方法，读取导出地址，配置 OpenTelemetry 的链路、指标和 Serilog 的 OTLP sink。不注册成 DI 服务，不引用 Core、Hosting 或任何业务项目。Hosting、网关和 XiaoShanResource 都调用它。资源化站点因此不必引用 Hosting。

备选是把注册写进 Hosting，再在网关和资源化站点各抄一份。三处会很快分叉。

### 日志继续走 Serilog

`UrbanServiceHost` 已有的 Serilog 配置保留控制台和文件。导出地址存在时，再加 `Serilog.Sinks.OpenTelemetry`，协议用已试通的 OTLP HTTP。资源化站点目前没有 Serilog，这次让它使用同一套注册，这样它的日志也会进入收集器。

### 收集器在中间，查看用 Aspire Dashboard

Compose 增加 `otel-collector`，使用已试通的收集器镜像系列，只在 compose 网络里监听 4318，不把该端口映射到宿主机。应用的导出地址是 `http://otel-collector:4318`。

收集器把信号转到 `otel-dashboard`。查看页面使用 Aspire Dashboard，容器端口 18888 对外，OTLP 接收只留在 compose 网络里。宿主机端口由 `UM_OTEL_DASHBOARD_PORT` 决定，默认 18888；绑定地址由 `UM_OTEL_DASHBOARD_BIND` 决定，默认 `0.0.0.0`。生产宿主若只想本机查看，把绑定地址设为 `127.0.0.1`。

备选是应用直接把 OTLP 发给 Dashboard。Dashboard 重启时，导出会失败。收集器把应用和页面隔开。

### 导出地址为空时不导出

环境变量 `OTEL_EXPORTER_OTLP_ENDPOINT` 为空时，不注册 OTLP sink 和导出器。本地 `dotnet run` 不需要先起收集器。Compose 里为业务容器、网关和资源化站点设置该变量。

### 链路和指标的范围

链路覆盖进入 ASP.NET Core 的请求和通过 `HttpClient` 发出的调用。网关的入站请求也走这套注册。指标覆盖进程和 HTTP 服务。资源属性里的 `service.name` 使用入口程序集名，以便页面上区分 `UrbanManagement.Gateway`、`UrbanManagement.Admin`、`UrbanManagement.XiaoShanResource` 等。

## Risks / Trade-offs

- [查看页面和链路、指标还没有在 138 上试过] → 实现时先用一条日志确认 Dashboard 能看见，再确认一条请求链路和一个进程指标。日志路径以已有 FEV 为准。
- [Dashboard 默认不鉴权，端口开在宿主机上] → 不进入网关。生产环境把 `UM_OTEL_DASHBOARD_BIND` 设为 `127.0.0.1`，或由防火墙限制来源。
- [Aspire Dashboard 的默认保留是短的] → 这次接受。文件日志仍保留 30 天。以后要加留存时，只改收集器的导出，不改应用。
- [`add-xiaoshan-resource-web` 也在改容器定义和 `urban-role-hosting` 的服务清单] → 归档时合并宿主机端口，并在服务清单里同时保留 `UrbanManagement.XiaoShanResource` 和 `UrbanManagement.Telemetry`。收集器不占用宿主机端口。

## Migration Plan

先在变更分支加入遥测库和 compose 服务。138 上重新构建相关镜像并启动 `otel-collector` 与 `otel-dashboard`。业务容器增加导出地址后重启。回退时清掉该环境变量并停止这两个 compose 服务，业务日志仍在原文件里。

## Open Questions

无。查看页面的默认宿主机端口是 18888，对应 Aspire Dashboard 自己的容器端口。
