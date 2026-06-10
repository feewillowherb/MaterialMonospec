## ADDED Requirements

### Requirement: Client list page rendering
`ClientList.razor` SHALL render a paginated table of connected clients with real-time SignalR updates, consuming `IDeviceStatusAppService` via DI injection.

#### Scenario: Initial page load
- **WHEN** the user navigates to `/clients`
- **THEN** the page SHALL call `IDeviceStatusAppService.GetClientListAsync()` with default pagination
- **AND** SHALL render a table with columns: 客户端名称, 连接状态, 连接时间, 断开时间, 操作
- **AND** SHALL display a "详情" link for each client navigating to `/clients/{proId}`

#### Scenario: Real-time client connection updates
- **WHEN** a SignalR `ClientConnectionUpdate` event is received
- **THEN** the page SHALL update the corresponding client row without full page reload
- **AND** SHALL update the last heartbeat timestamp display

#### Scenario: Client list keyword search
- **WHEN** the user enters a keyword and submits the search form
- **THEN** the page SHALL call `GetClientListAsync` with the keyword in the request
- **AND** SHALL reset pagination to page 1

#### Scenario: SignalR connection status indicator
- **WHEN** the page is loaded
- **THEN** a connection status badge SHALL display the current SignalR state (连接中/实时更新/重连中/连接断开)
- **AND** the badge SHALL update automatically on connection state changes

#### Scenario: Fallback polling on SignalR disconnect
- **WHEN** the SignalR connection is lost
- **THEN** the page SHALL start polling `GetClientListAsync` every 30 seconds as a fallback
- **AND** SHALL stop polling when SignalR reconnects

### Requirement: Client device detail page rendering
`ClientDetail.razor` SHALL render device status cards for a specific client identified by ProId.

#### Scenario: Page load with ProId
- **WHEN** the user navigates to `/clients/{proId}`
- **THEN** the page SHALL call `IDeviceStatusAppService.GetClientDevicesAsync(proId)` to load device statuses
- **AND** SHALL render a card for each device type: 地磅 (Scale), 摄像头 (Camera), 车牌识别 (LPR), 音响 (Sound), 打印机 (Printer)

#### Scenario: Real-time device status updates
- **WHEN** a SignalR `DeviceStatusUpdate` event is received for the current ProId
- **THEN** the corresponding device card SHALL update its status and timestamp
- **AND** the last heartbeat SHALL update

#### Scenario: Device cards show status
- **WHEN** device data is loaded
- **THEN** each card SHALL display: device icon, device type name, status (Online=🟢在线, Offline=🔴离线, Busy=🟡忙碌, 未上报=⚪), last update time
- **AND** cards without data SHALL show "⚪ 未上报" status

#### Scenario: Back navigation
- **WHEN** the user clicks "返回列表" button
- **THEN** the page SHALL navigate to `/clients`

#### Scenario: ProId not found
- **WHEN** the user navigates to `/clients/` (empty ProId)
- **THEN** the page SHALL redirect to `/clients`
