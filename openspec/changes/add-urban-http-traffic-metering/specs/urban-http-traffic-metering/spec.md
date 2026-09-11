## ADDED Requirements

### Requirement: Per-request HTTP traffic metering

The UrbanManagement ASP.NET Core host SHALL meter eligible HTTP requests for request body bytes read, response body bytes written, elapsed milliseconds, HTTP method, path, and status code after the request completes pipeline execution.

#### Scenario: Eligible API request is metered

- **WHEN** metering is enabled and the request path matches a configured include prefix and does not match an exclude prefix
- **THEN** the host records one traffic event containing Method, Path, StatusCode, RequestBytes, ResponseBytes, and ElapsedMs

#### Scenario: Ineligible path is not metered

- **WHEN** the request path does not match any include prefix, or matches an exclude prefix
- **THEN** the host MUST NOT wrap request/response bodies for metering and MUST NOT write a traffic event for that request

#### Scenario: Metering disabled

- **WHEN** `HttpTrafficMetering:Enabled` is `false`
- **THEN** the host MUST NOT write traffic events

### Requirement: Traffic logs separated from business logs

Traffic metering events MUST be written only to a dedicated rolling log file configured for traffic metering. Traffic events MUST NOT be written to the business Serilog file sink used for `Logs/log-*.txt` (or equivalent business log path).

#### Scenario: Traffic file receives metering events

- **WHEN** an eligible request is metered successfully
- **THEN** a corresponding line or structured entry appears under the configured traffic log path (default under `Logs/traffic/`)

#### Scenario: Business log file excludes traffic events

- **WHEN** traffic metering emits an event
- **THEN** that event MUST NOT appear in the business application log file produced by the host Serilog configuration for general application logging

### Requirement: Streaming byte counts without full-body buffering

The metering implementation MUST count bytes via stream wrappers (or equivalent streaming counters) and MUST NOT buffer the entire request or response body solely to compute sizes.

#### Scenario: Large request body is counted while streaming

- **WHEN** an eligible request carries a large body within the host size limit
- **THEN** RequestBytes reflects bytes read through the metering wrapper without requiring a full in-memory copy of the body for metering alone

### Requirement: Configurable path filters and file retention

The host SHALL bind options from configuration section `HttpTrafficMetering`, including at least: Enabled, PathPrefixes, ExcludePathPrefixes, LogFilePath, and RetainedFileCountLimit. Defaults MUST include API path prefixes and exclude Blazor/SignalR hub path prefixes.

#### Scenario: Default filters cover Auto API and Legacy Api

- **WHEN** configuration uses defaults
- **THEN** paths under `/api` and `/Api` are eligible and paths under `/_blazor` and `/hubs/` are excluded

#### Scenario: Operator changes traffic file retention independently of business logs

- **WHEN** `HttpTrafficMetering:RetainedFileCountLimit` differs from the business Serilog file retention
- **THEN** the traffic rolling file sink uses the traffic-specific retention value
