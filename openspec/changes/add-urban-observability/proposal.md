## Why

UrbanManagement 有多个独立进程，日志写在各自容器里，运行状况没有统一入口。要在同一套 compose 里看到日志、请求链路和进程指标。

## What Changes

- 为走 `UrbanServiceHost` 的服务、网关和 `UrbanManagement.XiaoShanResource` 增加 OpenTelemetry 导出。日志仍由 Serilog 写出，并增加 OTLP sink。同时导出 ASP.NET Core / HttpClient 链路，以及进程和 HTTP 指标。
- 在 `deploy/docker/compose.yaml` 增加 `otel-collector` 和 `otel-dashboard`。应用把 OTLP 发到收集器，不直接对着查看页面发。收集器不发布宿主机端口。查看页面使用 Aspire Dashboard，单独发布一个宿主机端口，不进入 `um-gateway`。
- 未配置 OTLP 端点时不导出，现有控制台和文件日志保持不变。
- 不改业务接口、登录产品码、网关路由和数据库。

## Capabilities

### New Capabilities

- `urban-observability`: 各服务把日志、链路和指标经 OTLP 送到收集器，并由独立的查看页面呈现

### Modified Capabilities

- `urban-container-deployment`: compose 增加收集器和查看页面；查看页面单独发布端口，收集器不对宿主机发布端口
- `urban-role-hosting`: 共享库增加不含数据库的遥测注册，供 Hosting、网关和 XiaoShanResource 使用

## Impact

- **子仓库**：`repos/UrbanManagement`。改动 `UrbanManagement.Hosting`、`UrbanManagement.Gateway`、`UrbanManagement.XiaoShanResource`、`deploy/docker/compose.yaml`，并新增一个不引用 Core 的遥测库。
- **分支**：Mode A — `add-urban-observability`
- **证据**：日志导出已在 138 的 Docker 上试通，见 `pipelines/graphs/.local/fev-otel-138/result.json`。查看页面、链路和指标尚未试过。
- **不动**：`um-gateway` 的业务路由、城管管理端产品 5040、资源化站点产品 5041、FdSoft.SSO、FD_Base。
