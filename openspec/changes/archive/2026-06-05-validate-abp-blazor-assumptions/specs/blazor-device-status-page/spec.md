## MODIFIED Requirements

### Requirement: 设备状态页面组件
UrbanManagement MUST 包含 `DeviceStatus.razor` Blazor 页面，展示客户端设备在线状态。页面 MUST 仅通过 `IDeviceStatusAppService` 访问缓存数据，MUST NOT 直接注入 `IDistributedCache<>` 实例。

#### Scenario: 页面初始加载从缓存读取数据
- **WHEN** `DeviceStatus.razor` 的 `OnInitializedAsync` 执行
- **THEN** MUST 通过 `IDeviceStatusAppService.GetClientListAsync` 获取所有已注册客户端
- **AND** MUST 逐客户端调用 `IDeviceStatusAppService.GetClientDevicesAsync` 获取设备状态
- **AND** MUST NOT 直接注入或使用任何 `IDistributedCache<T>` 实例

#### Scenario: 展示客户端连接信息
- **WHEN** 设备状态页面渲染
- **THEN** MUST 展示每个客户端的 `ProName`
- **AND** MUST 展示客户端的连接状态（在线/离线）
- **AND** MUST 展示该客户端下各设备类型的最新状态
