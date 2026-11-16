## 1. 遥测库

- [x] 1.1 新增 `UrbanManagement.Telemetry`，用静态方法按 `OTEL_EXPORTER_OTLP_ENDPOINT` 注册链路、指标和 Serilog 的 OTLP sink。地址为空时不导出。不引用 Core 或 Hosting，不注册为 DI 服务
- [x] 1.2 在 `Directory.Packages.props` 加入 OpenTelemetry 和 `Serilog.Sinks.OpenTelemetry` 的版本

## 2. 三个入口

- [x] 2.1 `UrbanServiceHost` 在现有控制台和文件日志之外调用遥测注册，`service.name` 使用入口程序集名
- [x] 2.2 网关的 `Program.cs` 调用同一注册，覆盖入站请求
- [x] 2.3 `UrbanManagement.XiaoShanResource` 调用同一注册，不引用 Hosting 或 Core

## 3. Compose

- [x] 3.1 增加 `otel-collector`，只在 compose 网络提供 `4318`，不映射宿主机端口。配置随仓库提交，不含密钥
- [x] 3.2 增加 `otel-dashboard`，使用 Aspire Dashboard。UI 端口为 `UM_OTEL_DASHBOARD_PORT`，默认 18888，绑定地址为 `UM_OTEL_DASHBOARD_BIND`，默认 `0.0.0.0`。不进入 `um-gateway`
- [x] 3.3 为网关、业务服务和 XiaoShanResource 设置 `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318`。收集器和查看页面不依赖 `um-migrator`

## 4. 验证

- [x] 4.1 导出地址为空时，服务可以启动，且不连接收集器
- [x] 4.2 收集器在运行时，Admin 的一条日志、网关的一条请求链路、一个进程指标能在 Dashboard 上按服务名看到
- [x] 4.3 运行 `openspec validate add-urban-observability --strict`
