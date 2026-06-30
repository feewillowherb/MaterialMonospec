## ADDED Requirements

### Requirement: 激活成功后请求进程重启

MaterialClient.Urban SHALL 在在线激活成功且 `LicenseInfo` 已持久化有效 JWT 后，请求重启整个应用进程，MUST NOT 在同进程内继续显示称重主界面或启动后台服务（SignalR、轮询上传、设备管理器等）。

#### Scenario: 启动门禁恢复路径激活成功

- **WHEN** 启动授权无效且用户在 `UrbanLicenseRecoveryService` 启动恢复流程中在线激活成功
- **THEN** SHALL 设置进程重启请求标志
- **AND** SHALL 调用应用 `Shutdown` 退出当前进程
- **AND** MUST NOT 在同进程打开 `UrbanAttendedWeighingWindow`
- **AND** MUST NOT 在同进程启动 `IDeviceStatusSignalRClient`

#### Scenario: F4 设备变更重激活成功

- **WHEN** 运行时收到 `LicenseDeviceRevokedEto` 且用户在线重激活成功
- **THEN** SHALL 采用与启动恢复相同的进程重启请求机制
- **AND** MUST NOT 仅记录日志后继续同进程业务

#### Scenario: 用户取消激活不重启

- **WHEN** 用户关闭或取消激活窗且未完成激活
- **THEN** SHALL 关闭应用
- **AND** MUST NOT 设置重启请求标志
- **AND** MUST NOT 启动新进程

### Requirement: Mutex 安全的新进程拉起

`Program.Main` SHALL 在 Avalonia 桌面生命周期结束且单实例 Mutex（`MaterialClient_Urban_SingleInstance_Mutex`）释放后，才启动新的应用进程实例。

#### Scenario: 重启顺序

- **WHEN** 应用退出且重启请求标志为 true
- **THEN** `StartWithClassicDesktopLifetime` SHALL 正常返回
- **AND** Mutex `using` 块 SHALL 释放
- **AND** THEN SHALL 使用 `Environment.ProcessPath` 启动新进程
- **AND** MUST NOT 在 Mutex 仍被当前进程持有时启动新进程

#### Scenario: 新进程获得单实例锁

- **WHEN** 重启拉起的新进程启动
- **THEN** SHALL 成功获得 `MaterialClient_Urban_SingleInstance_Mutex`
- **AND** SHALL 执行完整冷启动授权检查与服务初始化

#### Scenario: 正常退出不拉起新进程

- **WHEN** 用户正常关闭应用且重启请求标志为 false
- **THEN** `Program.Main` SHALL NOT 启动新进程

### Requirement: 重启前资源清理

请求进程重启时，MaterialClient.Urban SHALL 走正常应用退出清理路径（`OnApplicationExit`），包括 ViewModel 释放、Urban minimal web host 停止、硬件设备关闭、ABP `ShutdownAsync`。

#### Scenario: 启动恢复路径退出清理

- **WHEN** 启动恢复激活成功触发重启
- **THEN** SHALL 注册并执行 `OnApplicationExit` 清理逻辑后再退出 `Main`
- **AND** SHALL 避免 COM 口等资源被旧进程占用导致新进程初始化失败
