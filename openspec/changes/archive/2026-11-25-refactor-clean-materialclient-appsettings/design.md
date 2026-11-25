# Design: MaterialClient 配置常量收敛与 appsettings 整洁化

## Context

`repos/MaterialClient` 包含 4 个桌面宿主（`MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Urban`、`MaterialClient.Recycle`）。当前各宿主通过 ABP 自动加载 `appsettings.json`，并在各自 `PreConfigureServices`（或 `HostConfigurationComposer`）中叠加 `appsettings.secret.json`、环境变量与 DEBUG User Secrets。

本次变更作为 `docs/2026-11-25-materialclient-db-first-config/` 路线的第一阶段，目标是将**静态常量与代码默认值**统一收敛为代码内单一数据源，将 4 个宿主的 `appsettings.json` 与 `appsettings.secret.json` 精简至只保留必要的环境/站点项及显式排除的敏感项，同时保持零破坏性、支持外部覆写。

## Goals / Non-Goals

### Goals
- 所有静态常量与公共默认配置集中在 `MaterialClient.Common/Configuration/MaterialClientConfigurationDefaults.cs`（单一数据源，无 DI 注册）。
- 4 个宿主的 `appsettings.json` 精简到只剩连接串与环境/站点端点，`appsettings.secret.json` 去除冗余 `SignalR` 调优块。
- 当 `appsettings.json` 中省略已收敛的键时，程序行为与重构前完全一致；若外部 JSON、环境变量或 User Secrets 显式配置了这些键，仍以显式配置为准。
- 显式排除 `AliyunOss` 与 `Encryption:AesKey`，保持其在 `appsettings.secret.json` 中的现有结构和读取逻辑不变。

### Non-Goals
- 不引入 `SqliteConfigurationProvider` 或新建 `AppConfigs` 表（留待后续 DB-first 阶段）。
- 不修改 `AliyunOss` 与 `Encryption:AesKey` 的存储或加载方式。
- 不修改数据库路径从相对路径到 `C:\ProgramData` 的迁移逻辑。
- 不引入任何新的 DI 服务（遵循 `traits/minimal-di-trait.md`）。

## Decisions

### 1. 代码单一数据源：`MaterialClientConfigurationDefaults`

在 `repos/MaterialClient/src/MaterialClient.Common/Configuration/MaterialClientConfigurationDefaults.cs` 新增 `public static class MaterialClientConfigurationDefaults`：

- `DefaultJwtPublicKeyPem` (`string`)：现行 RSA 公钥 PEM（原 `MaterialClient.Urban` / `MaterialClient.Recycle` 的 `Jwt:PublicKey`）。
- `DefaultLowPriorityPlateColors` (`IReadOnlyList<VzvisionColorType>`)：`[VzvisionColorType.Blue, VzvisionColorType.Green]`。
- `DefaultStreets` (`IReadOnlyList<string>`)：现行 23 个街道名称数组（由 `StreetsConfig` 和 `MaterialClientSolidWasteModule` 共用）。
- `DefaultSolidWasteTypes` (`IReadOnlyList<string>`)：现行固废类型数组（由 `SolidWasteTypeConfig` 和 `MaterialClientSolidWasteModule` 共用）。
- `SignalR` 默认常量与路径派生辅助方法：
  - `DefaultSignalRHubPath = "/hubs/devicestatus"`
  - `ResolveSignalRServerUrl(string? explicitServerUrl, string? urbanManagementBaseUrl)`：若 `explicitServerUrl` 非空则直接返回；否则从 `urbanManagementBaseUrl`（为空则回退 `"http://localhost:5000"`）拼接 `"/hubs/devicestatus"`。
- `MinimalWebHost` 默认地址常量：`DefaultMinimalWebHostUrl = "http://localhost:9933"`。

> 遵循 `traits/minimal-di-trait.md`：纯常量与纯函数放在静态类中，不注册为 `ITransientDependency` / `ISingletonDependency`。

### 2. 配置项逐项归口表

| 配置键 / 配置段 | 原所在宿主 | 归口去向 | 代码回退位置 |
|---|---|---|---|
| `Jwt:PublicKey` | Urban, Recycle | **代码常量（可覆写）** | `StaticLicenseChecker`：`configuration["Jwt:PublicKey"]` 为空时回退 `DefaultJwtPublicKeyPem` |
| `Streets` | Standard, SolidWaste, Urban | **代码常量（可覆写）** | `StreetsConfig` 默认值 & `MaterialClientSolidWasteModule`（配置缺失或空时回退 `DefaultStreets`） |
| `SolidWasteTypes` | Standard, SolidWaste, Urban | **代码常量（可覆写）** | `SolidWasteTypeConfig` 默认值 & `MaterialClientSolidWasteModule`（配置缺失或空时回退 `DefaultSolidWasteTypes`） |
| `LowPriorityPlateColors` | Standard, SolidWaste, Urban | **代码常量（可覆写）** | `AttendedWeighingService`（未配置节时回退 `DefaultLowPriorityPlateColors`；若显式配置为空数组 `[]` 则保持空过滤） |
| `Logging:LogLevel:*` | 全部 4 个 | **已有代码默认值** | `SerilogFileLogConfigurator`（`Default=Information`，`Microsoft`/`EF`/`Volo.Abp=Warning`） |
| `Log:*` | 全部 4 个 | **已有代码默认值** | `SerilogFileLogConfigurator`（`Enabled=true`, `Directory="Logs"`, `FileSizeLimitMB=50`, `RetentionDays=30`, `UseDateFolders=true`） |
| `BackgroundServices:ImageCleanup:*` | 全部 4 个 | **已有代码默认值** | `ImageCleanupOptions`（`Enabled=true`, `RetentionDays=90`, `IntervalHours=24`, `InitialDelayHours=1`） |
| `BackgroundServices:Polling` | 全部 4 个 | **按宿主代码默认** | Standard / SolidWaste 默认 `false`；Urban / Recycle 默认 `true` |
| `MinimalWebHost:Urls` & `EnableOnStartup` | 全部 4 个 | **按宿主代码默认** | `Urls` 默认 `http://localhost:9933`；Standard / SolidWaste / Recycle `EnableOnStartup` 默认 `true`，Urban 默认 `false` |
| `SignalR:*` | Urban（含 secret.json） | **代码默认 + 自动派生** | `SignalRClientOptions`（`ReconnectDelays=[0,2,10,30]`, `MaxReconnectAttempts=10`, `MessageQueueSize=100`）；Urban Module 中默认 `PersistentReconnect=true`, `ReconnectResetHours=4`，`ServerUrl` 未显式设置时由 `UrbanManagement:BaseUrl` 派生 |
| `Urban:UploadPollingPeriodMs` & `UploadBatchSize` | Urban | **代码默认** | Urban `PollingBackgroundService` 默认 `UploadPollingPeriodMs = 80_000`，`UploadBatchSize = 50` |
| `UrbanAnomalyDetection:*` | Urban | **已在 SQLite `SettingsEntity` + 代码默认** | `UrbanAnomalyDetectionConfig`（主数据源为 DB `SystemSettings.UrbanAnomalyDetection`，移除 `appsettings.json` 冗余节） |
| `ProductCode`, `WeighingMode` | Recycle | **移除冗余键** | 代码已强类型固化 `ProductCode.Recycle` / `WeighingMode.Recycle` |
| `Client:Id`（空串占位） | Urban, Recycle | **移除空占位** | `ClientLogPullService` 等消费方已自带 `Environment.MachineName` 回退 |
| `RecycleSync` 重试/轮询参数 | Recycle | **已有代码默认值** | `RecycleSyncOptions`（`Enabled=true`, `PollIntervalSeconds=5`, `MaxFailCount=9`, `FailCooldownMinutes=60`, `TimeoutSeconds=30`） |
| `ConnectionStrings:Default` | 全部 4 个 | **代码固定为 exe 同目录** | `MaterialClientConfigurationDefaults.ResolveExeDirectoryConnectionString()`（固定指向 `AppContext.BaseDirectory/MaterialClient.db`，不再从 `appsettings.json` 读取） |
| `BasePlatform:BaseUrl` / `MaterialPlatform:BaseUrl` / `UrbanManagement:BaseUrl` | 各相关宿主 | **保留在 `appsettings*.json`** | 环境端点，待后续 DB-first 阶段迁入 SQLite |
| `RecycleSync:ApiUrl` / `AccessKey` / `SecretKey` / `PointNumber` | Recycle | **保留在 `appsettings*.json`** | 站点级凭证与接口地址 |
| **`AliyunOss`** | Standard, SolidWaste, Urban (`secret.json`) | **显式排除（保持原样）** | 不动 |
| **`Encryption:AesKey`** | Standard, SolidWaste, Urban (`secret.json`) | **显式排除（保持原样）** | 不动 |

### 3. 精简后的 `appsettings.json` 目标形态

- **`MaterialClient/appsettings.json`** & **`MaterialClient.SolidWaste/appsettings.json`**：
  ```json
  {}
  ```
- **`MaterialClient.Urban/appsettings.json`**：
  ```json
  {
    "UrbanManagement": {
      "BaseUrl": "http://localhost:5000"
    }
  }
  ```
- **`MaterialClient.Recycle/appsettings.json`**：
  ```json
  {
    "BasePlatform": {
      "BaseUrl": "http://192.168.3.135:8551"
    },
    "UrbanManagement": {
      "BaseUrl": "http://192.168.3.138:5333"
    },
    "MaterialPlatform": {
      "BaseUrl": "http://localhost:5000"
    },
    "RecycleSync": {
      "ApiUrl": "http://localhost"
    }
  }
  ```
- **`appsettings.secret.json`（4 宿主）**：
  - `MaterialClient` / `MaterialClient.SolidWaste` / `MaterialClient.Recycle`：保持现有项（`AliyunOss`、`Encryption:AesKey`、生产 `BaseUrl`、Recycle 站点凭证占位）。
  - `MaterialClient.Urban`：保留 `AliyunOss`、`Encryption:AesKey`、`BasePlatform:BaseUrl`、`MaterialPlatform:BaseUrl`，彻底移除整个 `SignalR` 配置段（`ServerUrl` 由 `UrbanManagement:BaseUrl` 自动派生，必要时可通过环境变量 `SignalR__ServerUrl` 覆写）。

## Risks / Trade-offs

- **风险 1：`PollingBackgroundService` 默认轮询周期差异**
  - 原 `MaterialClient.Urban/Backgrounds/PollingBackgroundService.cs` 代码回退值为 `600_000` ms，而 `appsettings.json` 设为 `80000` ms。
  - **缓解**：将代码默认值统一对齐为 `80_000` ms，确保删除 `appsettings.json` 中的 `Urban` 段后行为完全不变。
- **风险 2：`MaterialClient.Urban` 中 `MinimalWebHost:EnableOnStartup` 默认值差异**
  - 原 `MaterialClient.Urban/App.axaml.cs` 代码回退值为 `true`，而 `appsettings.json` 显式设为 `false`。
  - **缓解**：将 `MaterialClient.Urban/App.axaml.cs` 的默认回退值改为 `false`，确保删除 `MinimalWebHost` 段后 Urban 仍默认不启动诊断 WebHost，同时保留环境变量 `MinimalWebHost__EnableOnStartup=true` 覆盖能力。
- **风险 3：`MaterialClient` / `MaterialClient.SolidWaste` 的 `BackgroundServices:Polling` 默认值差异**
  - 原 `MaterialClientSolidWasteModule` 代码回退值为 `true`，而 `appsettings.json` 显式设为 `false`。
  - **缓解**：将 Standard 与 SolidWaste 的 `BackgroundServices:Polling` 代码默认值对齐为 `false`。
- **风险 4：`LowPriorityPlateColors` 区分“未配置”与“显式空数组”**
  - 若现场确实想禁用低优先级颜色过滤，应能通过配置空数组覆盖；因此仅在 `GetSection("LowPriorityPlateColors").Exists()` 为 `false` 时回退到 `DefaultLowPriorityPlateColors`。
