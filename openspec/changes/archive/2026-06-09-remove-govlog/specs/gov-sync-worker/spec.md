# Delta Spec: Government Sync Worker

This is a delta spec file that modifies `openspec/specs/gov-sync-worker/spec.md`.

## REMOVED Requirements

### Requirement: Sync logging

**Reason**: GovLog 功能已被移除，统一使用 Serilog 作为日志记录机制。GovLog 提供的同步操作日志信息（SyncTime、SyncResult、SyncCode、SyncMsg）完全可以通过 Serilog 结构化日志记录和查询。保留 GovLog 导致系统中存在两套日志机制，增加了架构复杂度和维护成本。

**Migration**:
- 同步操作日志现在通过 Serilog 记录到文件系统 (`Logs/log-.txt`)
- 现有的 Serilog 日志已包含完整信息：RecordId、响应码、响应消息
- 如需查询同步历史，使用 Serilog 日志文件或日志分析工具
- API 端点 `GET /api/app/gov-sync-data/logs` 已删除

**以下是原始需求内容（已废弃）**:

The system SHALL create a `GovLog` record for each sync attempt, containing: `SyncId` (the UrbanWeighingRecord Id cast to int? or stored as string), `SyncNumber` (current attempt count), `SyncTime` (current time), `SyncSource` (JSON payload sent), `SyncResult` (success/failure), `SyncCode` (response code), and `SyncMsg` (response message).

#### Scenario: Logging a successful sync
- **WHEN** a record is successfully forwarded to the government API
- **THEN** a `GovLog` entry SHALL be created with the response details and a success indicator

#### Scenario: Logging a failed sync
- **WHEN** a forward attempt fails
- **THEN** a `GovLog` entry SHALL be created with the failure reason and response code
