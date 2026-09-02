## MODIFIED Requirements

### Requirement: 设备状态消息协议

系统必须定义统一的设备状态消息格式，包含客户端标识、设备类型、状态值、时间戳等核心字段，并使用 JSON 序列化。JSON 字段 `proId` SHALL remain a **string** on the wire (Guid canonical string format). Server-side persistence MUST parse `proId` to `Guid` before writing `ClientOnlineStatus` or `ClientDeviceOnlineStatus`; unparseable or empty values MUST skip database upsert.

#### Scenario: 消息包含必填字段

- **WHEN** MaterialClient 发送设备状态消息
- **THEN** 消息 SHALL 包含 `clientId`、`proId`（string）、`proName`、`deviceType`、`status`、`timestamp`
- **AND** `proId` SHOULD be `LicenseInfo.ProjectId.ToString()`

#### Scenario: 服务端拒绝无效 ProId 持久化

- **WHEN** `UploadStatus` receives a message whose `proId` is empty or not a valid Guid string
- **THEN** the Hub MAY still accept the SignalR message for broadcast purposes
- **AND** MUST NOT upsert `ClientOnlineStatus` or device detail rows for that message
