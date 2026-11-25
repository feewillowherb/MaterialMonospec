# Tasks: refactor-clean-materialclient-appsettings

> 目标仓库：`repos/MaterialClient`（Mode A：Trunk-direct，Apply 前切到同名分支 `refactor-clean-materialclient-appsettings`）。
> 显式排除：`AliyunOss` 与 `Encryption:AesKey` 本次不修改。

## 1. 公共配置常量与默认值单一数据源（`MaterialClient.Common`）

- [x] 1.1 在 `repos/MaterialClient/src/MaterialClient.Common/Configuration/MaterialClientConfigurationDefaults.cs` 新增静态类 `MaterialClientConfigurationDefaults`，集中定义：`DefaultJwtPublicKeyPem`、`DefaultStreets`、`DefaultSolidWasteTypes`、`DefaultLowPriorityPlateColors`、`DefaultMinimalWebHostUrl`、`DefaultSignalRHubPath` 以及 `ResolveSignalRServerUrl(string? explicitServerUrl, string? urbanManagementBaseUrl)`。
- [x] 1.2 更新 `StreetsConfig` 与 `SolidWasteTypeConfig` 属性默认值引用 `MaterialClientConfigurationDefaults`；更新 `StaticLicenseChecker` 在 `Jwt:PublicKey` 未配置或为空时回退到 `MaterialClientConfigurationDefaults.DefaultJwtPublicKeyPem`。
- [x] 1.3 更新 `AttendedWeighingService`：当 `IConfiguration.GetSection("LowPriorityPlateColors").Exists()` 为 `false` 时回退到 `MaterialClientConfigurationDefaults.DefaultLowPriorityPlateColors`；显式配置时以配置值为准。

## 2. 4 个宿主代码默认值对齐

- [x] 2.1 更新 `MaterialClient.SolidWaste/MaterialClientSolidWasteModule.cs`：`Streets` / `SolidWasteTypes` 未配置时回退内置默认字典，`BackgroundServices:Polling` 默认值对齐为 `false`。
- [x] 2.2 检查并对齐 `MaterialClient/MaterialClientModule.cs`（及 `PollingBackgroundService` 启动处）：`BackgroundServices:Polling` 默认值对齐为 `false`。
- [x] 2.3 更新 `MaterialClient.Urban`：
  - `MaterialClientUrbanModule.cs`：`SignalRClientOptions` 绑定前应用 Urban 默认值（`PersistentReconnect = true`、`ReconnectResetHours = 4`），并在未显式配置 `SignalR:ServerUrl` 时通过 `MaterialClientConfigurationDefaults.ResolveSignalRServerUrl` 从 `UrbanManagement:BaseUrl` 派生；
  - `App.axaml.cs`：`MinimalWebHost:EnableOnStartup` 默认回退值改为 `false`；
  - `Backgrounds/PollingBackgroundService.cs`：`Urban:UploadPollingPeriodMs` 默认回退值对齐为 `80_000`。
- [x] 2.4 检查 `MaterialClient.Recycle`：`MinimalWebHost:EnableOnStartup`、`BackgroundServices:Polling` 与 `RecycleSyncOptions` 默认值与原 `appsettings.json` 一致（无需额外 JSON 重复声明）。

## 3. 精简 4 个宿主的 `appsettings.json` 与 `appsettings.secret.json`

- [x] 3.1 精简 `repos/MaterialClient/src/MaterialClient/appsettings.json`（移除 `ConnectionStrings`、`Logging`、`Log`、`BackgroundServices`、`MinimalWebHost`、`Streets`、`SolidWasteTypes`、`LowPriorityPlateColors`，收敛为 `{}`；SQLite 连接固定在 exe 同目录 `MaterialClient.db`）。
- [x] 3.2 精简 `repos/MaterialClient/src/MaterialClient.SolidWaste/appsettings.json`（同 3.1）。
- [x] 3.3 精简 `repos/MaterialClient/src/MaterialClient.Urban/appsettings.json`（仅保留 `UrbanManagement:BaseUrl`）与 `appsettings.secret.json`（保留 `AliyunOss`、`Encryption:AesKey`、`BasePlatform:BaseUrl`、`MaterialPlatform:BaseUrl`，彻底移除整个 `SignalR` 配置段）。
- [x] 3.4 精简 `repos/MaterialClient/src/MaterialClient.Recycle/appsettings.json`（仅保留 `BasePlatform:BaseUrl`、`UrbanManagement:BaseUrl`、`MaterialPlatform:BaseUrl`、`RecycleSync:ApiUrl`；移除 `ConnectionStrings`、`ProductCode`、`WeighingMode`、`Logging`、`Log`、空 `Client:Id`、`BackgroundServices`、`MinimalWebHost`、`Jwt` 及 `RecycleSync` 默认重试字段）。
- [x] 3.5 核对 `MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Recycle` 的 `appsettings.secret.json`，确认 `AliyunOss` 与 `Encryption:AesKey` 保持原样未修改。

## 4. 单元测试与构建验证

- [x] 4.1 补充单元测试覆盖：`StaticLicenseChecker` 无配置回退内置公钥与显式配置覆写、`ResolveSignalRServerUrl` 自动派生与显式覆写、`LowPriorityPlateColors` 缺省回退与显式覆写、`Streets` / `SolidWasteTypes` 缺省回退。
- [x] 4.2 在 `repos/MaterialClient` 执行 `dotnet build MaterialClient.sln -o .build-verify` 与相关 `dotnet test`，确保全部 4 个宿主编译通过、测试全绿。
