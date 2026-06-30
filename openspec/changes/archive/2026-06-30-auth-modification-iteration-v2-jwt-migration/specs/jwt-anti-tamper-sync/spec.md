## ADDED Requirements

### Requirement: 设备变更失败的终止处理

`DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync` 收到 `VerifyJwtAsync` 返回 `Passed = false` 且 `RevocationReason = DEVICE_CHANGED`（或 `Reason` 含设备变更标记）时，SHALL 升级为「清除本地授权 + 终止运行」处理，而非当前「仅记录日志并跳过同步」。其它失败类型（签名失败、过期、项目不存在、网络超时）SHALL 保持既有「不修改 LicenseInfo、跳过同步」的可用性优先行为。

#### Scenario: 设备变更触发清除与终止

- **WHEN** `VerifyJwtAsync` 返回 `Passed = false` 且 `RevocationReason = DEVICE_CHANGED`
- **THEN** SHALL 清除 `LicenseInfo.LatestJwtToken`（置空并持久化）
- **AND** SHALL 弹出仅含在线激活入口的 `UnauthorizedNoticeWindow`（见 F1）
- **AND** SHALL 终止客户端运行（不再继续称重业务）
- **AND** SHALL 记录告警日志（含 ProId、失败原因）

#### Scenario: 其它失败类型保持跳过

- **WHEN** `VerifyJwtAsync` 返回 `Passed = false` 且 `RevocationReason` 不是 `DEVICE_CHANGED`（如 `EXPIRED`、`NOT_FOUND`、`INVALID_SIGNATURE`、网络超时）
- **THEN** SHALL NOT 清除 `LatestJwtToken`
- **AND** SHALL NOT 终止运行
- **AND** SHALL 保持既有行为：记录告警并跳过本次同步（可用性优先）

#### Scenario: 启动后首次 SignalR 验签发现设备变更

- **WHEN** 客户端启动通过本地验签、建立 SignalR 连接后首次 `VerifyJwtAsync` 返回 `DEVICE_CHANGED`
- **THEN** SHALL 触发上述「清除 + 终止」处理
- **AND** SHALL 接受「启动至首次验签」的短暂窗口期（窗口期内上传数据由 F2 `SubmitMachineCode` 可追溯）
