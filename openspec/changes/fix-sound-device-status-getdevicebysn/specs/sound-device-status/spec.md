## MODIFIED Requirements

### Requirement: 设备状态 API 集成

系统 MUST 通过 ls21 业务服务器 API 查询音柱设备状态，并将响应映射为设备在线状态。

#### Scenario: 调用远程 API 查询设备状态
- **WHEN** 音柱设备序列号为 `"020021EA63AC"` 且 `LocalIP` 为 `"192.168.1.100"`，调用 `SoundDeviceService.IsOnlineAsync()`
- **THEN** 系统应将序列号格式化为 `"ls20://020021EA63AC"`，以 BaseURL `"http://192.168.1.100:17808"` 调用 `POST /api/devices/getDeviceBySN`，JSON body 为 `{ "type": "req", "app": "ls20", "sn": "ls20://020021EA63AC" }`，超时 5 秒

#### Scenario: 解析在线状态响应
- **WHEN** 远程 API 返回 `{ "status": 1, "tasks": [] }`
- **THEN** 系统解析为 `SoundDeviceStatusDto`，将 `status == 1 || status == 2` 判定为在线并返回 `true`

#### Scenario: 解析离线状态响应
- **WHEN** 远程 API 返回 `{ "status": 0, "tasks": [] }`
- **THEN** 系统将 `status` 非 1/2 判定为离线并返回 `false`

#### Scenario: 解析任务中状态响应
- **WHEN** 远程 API 返回 `{ "status": 2, "tasks": [...] }`
- **THEN** 系统将 `status == 2` 判定为在线并返回 `true`，并记录调试日志 “Device is busy with tasks”

#### Scenario: 解析关机状态响应
- **WHEN** 远程 API 返回 `{ "status": 3, "tasks": [] }`
- **THEN** 系统将 `status == 3` 判定为离线并返回 `false`，并记录警告 “Device is powered off”

#### Scenario: 设备未找到时视为离线
- **WHEN** 远程 API 返回 HTTP 200 且 body 为 `{ "msg": "device not found" }`（无 `status` 字段）
- **THEN** 系统判定为离线并返回 `false`
