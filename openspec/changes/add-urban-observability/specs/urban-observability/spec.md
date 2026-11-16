## ADDED Requirements

### Requirement: Services export OpenTelemetry when configured

When `OTEL_EXPORTER_OTLP_ENDPOINT` is set, each process that uses `UrbanServiceHost`, the gateway, and `UrbanManagement.XiaoShanResource` SHALL export logs, traces, and metrics to that endpoint. Logs SHALL continue to be written by Serilog, including the existing console and file sinks, and SHALL also be exported with the OpenTelemetry sink. Traces SHALL include incoming ASP.NET Core requests and outgoing `HttpClient` calls. Metrics SHALL include process and HTTP server metrics. The resource attribute `service.name` SHALL be the entry assembly name.

#### Scenario: Admin log reaches the collector

- **WHEN** the Admin service is running with `OTEL_EXPORTER_OTLP_ENDPOINT` set to `http://otel-collector:4318` and it writes an information log
- **THEN** the collector SHALL receive that log with `service.name` equal to `UrbanManagement.Admin`

#### Scenario: Gateway request is traced

- **WHEN** a request arrives at the gateway while the endpoint is set
- **THEN** the gateway SHALL export a trace for that incoming request with `service.name` equal to `UrbanManagement.Gateway`

### Requirement: Export stays off without an endpoint

When `OTEL_EXPORTER_OTLP_ENDPOINT` is empty, the process SHALL start without an OTLP exporter and SHALL keep its existing console and file logging.

#### Scenario: Local run without a collector

- **WHEN** a service starts without `OTEL_EXPORTER_OTLP_ENDPOINT`
- **THEN** the process SHALL start
- **AND** it SHALL NOT require a reachable collector

### Requirement: Collector and dashboard stay beside the gateway

The compose stack SHALL run `otel-collector` and `otel-dashboard`. Application services SHALL send OTLP only to `otel-collector`. The collector SHALL NOT publish a port on the host. `otel-dashboard` SHALL be an Aspire Dashboard and SHALL publish host port `UM_OTEL_DASHBOARD_PORT`, default 18888, on bind address `UM_OTEL_DASHBOARD_BIND`, default `0.0.0.0`. The dashboard SHALL NOT be a destination of `um-gateway`.

#### Scenario: Dashboard is reached on its own port

- **WHEN** the stack is started with the default dashboard settings
- **THEN** the dashboard UI SHALL be reachable on host port 18888
- **AND** `um-gateway` SHALL NOT route that UI

#### Scenario: Collector is only inside the compose network

- **WHEN** the stack is started
- **THEN** the collector SHALL accept OTLP from other compose services at `otel-collector:4318`
- **AND** that port SHALL NOT be published on the host
