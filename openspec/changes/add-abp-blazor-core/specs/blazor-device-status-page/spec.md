## ADDED Requirements

### Requirement: 设备状态页面组件
UrbanManagement MUST 包含 `DeviceStatus.razor` Blazor 页面，展示客户端设备在线状态。

#### Scenario: 页面初始加载从缓存读取数据
- **WHEN** `DeviceStatus.razor` 的 `OnInitializedAsync` 执行
- **THEN** MUST 通过 `IDeviceStatusService` 或 `IDistributedCache<ClientRegistryCacheItem>` 获取所有已注册客户端 ID
- **AND** MUST 逐客户端查询设备状态缓存（`IDistributedCache<DeviceStatusCacheItem>`）
- **AND** MUST 将缓存数据聚合为设备在线状态列表展示

#### Scenario: 展示客户端连接信息
- **WHEN** 设备状态页面渲染
- **THEN** MUST 展示每个客户端的 `ProName`
- **AND** MUST 展示客户端的连接状态（在线/离线）
- **AND** MUST 展示该客户端下各设备类型的最新状态

### Requirement: SignalR 实时更新
`DeviceStatus.razor` MUST 订阅 SignalR Hub 的设备状态广播，实现实时 UI 更新。

#### Scenario: SignalR 连接建立
- **WHEN** `DeviceStatus.razor` 的 `OnInitializedAsync` 执行
- **THEN** MUST 建立 SignalR 连接到 `/hubs/devicestatus`
- **AND** MUST 订阅 `DeviceStatusChanged` 事件

#### Scenario: 收到设备状态变更广播
- **WHEN** SignalR Hub 广播 `DeviceStatusChanged` 事件
- **THEN** MUST 更新对应设备的 UI 状态
- **AND** MUST 调用 `StateHasChanged()` 触发重新渲染

#### Scenario: SignalR 断线重连
- **WHEN** SignalR 连接断开
- **THEN** MUST 自动尝试重连
- **AND** 重连成功后 MUST 重新订阅 `DeviceStatusChanged` 事件
- **AND** MUST 从缓存重新加载最新状态

### Requirement: 设备状态数据聚合
`DeviceStatus.razor` MUST 将原始缓存消息聚合为设备维度的在线状态。

#### Scenario: 按设备类型聚合
- **WHEN** 某客户端有多个设备类型的状态消息
- **THEN** MUST 按设备类型（Scale、Camera、Lpr、Printer 等）分组展示
- **AND** 每个设备类型 MUST 展示最新的状态值（Online/Offline）和时间戳

#### Scenario: 无数据时的空状态
- **WHEN** 某客户端无缓存设备状态数据
- **THEN** MUST 展示"暂无设备数据"提示
- **AND** MUST NOT 抛出异常
