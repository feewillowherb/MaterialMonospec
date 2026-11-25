# Change: 精简 MaterialClient 4 个宿主的 appsettings 并将常量与默认配置收敛到代码

## Why

当前 `repos/MaterialClient/src/` 下全部 4 个桌面宿主（`MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Urban`、`MaterialClient.Recycle`）的 `appsettings.json` 与 `appsettings.secret.json` 充斥大量本应由代码固化或已有代码默认值的配置项（如 23 个街道数组、固废类型数组、7 行 JWT 公钥 PEM、标准日志与清理策略、SignalR 重连参数、未使用的 `ProductCode`/`WeighingMode` 及空 `Client:Id` 占位等）。

这导致：
1. 配置文件冗长、跨宿主重复拷贝，现场人工查看或排查环境端点时噪声极大；
2. 不可变业务常量与静态公钥暴露在外部 JSON 中，增加现场误改或断电损坏导致的故障面；
3. 作为向「代码内置默认值 + SQLite DB」演进（见 `docs/2026-11-25-materialclient-db-first-config/`）的第一步，需要先将常量与默认值收敛到代码单一数据源，让 `appsettings*.json` 保持整洁。

## What Changes

- **建立代码内配置常量与默认值单一数据源**：在 `MaterialClient.Common/Configuration/` 下新增静态类 `MaterialClientConfigurationDefaults`（不注册 DI），集中定义公共静态常量与默认配置（`Jwt:PublicKey`、`Streets`、`SolidWasteTypes`、`LowPriorityPlateColors`、SignalR 默认重连参数等），并按宿主固化各自默认差异（`BackgroundServices:Polling`、`MinimalWebHost:EnableOnStartup`、`Urban` 上报轮询参数）。
- **补齐代码侧默认值回退**：
  - `StaticLicenseChecker` 在未配置 `Jwt:PublicKey` 时回退到内置公钥常量；
  - `MaterialClientSolidWasteModule` 在未配置 `Streets` / `SolidWasteTypes` 时回退到内置默认字典；
  - `AttendedWeighingService` 在未配置 `LowPriorityPlateColors` 时回退到内置默认低优先级车牌颜色（`Blue`、`Green`）；
  - `MaterialClientUrbanModule` 绑定 `SignalRClientOptions` 时应用 Urban 默认策略，并在未显式配置 `SignalR:ServerUrl` 时自动从 `UrbanManagement:BaseUrl` 派生 `{BaseUrl}/hubs/devicestatus`；
  - `MaterialClient.Urban` 的 `PollingBackgroundService` 与 `App.axaml.cs`、`MaterialClient.Recycle`、`MaterialClient`、`MaterialClient.SolidWaste` 对各自宿主的默认开关（`BackgroundServices:Polling`、`MinimalWebHost:EnableOnStartup`、`Urban:UploadPollingPeriodMs`）使用明确的宿主默认值。
- **精简全部 4 个宿主的 `appsettings.json` 与 `appsettings.secret.json`**：
  - 移除已在代码中固化或与代码默认值完全一致的冗余配置段（`ConnectionStrings`、`Logging`、`Log`、`BackgroundServices`、`MinimalWebHost`、`Streets`、`SolidWasteTypes`、`LowPriorityPlateColors`、`Jwt`、`SignalR`、`Urban`、`UrbanAnomalyDetection`、`ProductCode`、`WeighingMode`、空 `Client:Id`、`RecycleSync` 默认重试参数）；
  - SQLite 数据库连接字符串由代码固定解析到可执行文件（`.exe`）同目录下的 `MaterialClient.db`（`AppContext.BaseDirectory`），不再依赖 `appsettings.json` 中的 `ConnectionStrings:Default`；
  - 保留必要的环境与站点配置（各服务端 `BaseUrl`、Recycle 站点同步端点与凭证占位）；
  - 除固定在 exe 同目录的 SQLite 路径外，其余已移除配置项仍可通过外部 `appsettings*.json`、环境变量、命令行参数或 User Secrets 显式覆写，确保向后兼容。
- **显式排除范围**：
  - **`AliyunOss`**（`appsettings.secret.json`）本变更不修改，留待后续专项处理；
  - **`Encryption:AesKey`**（`appsettings.secret.json`）本变更不修改，留待后续专项处理；
  - 本变更不引入 `SqliteConfigurationProvider` 或 DB 存表改造（仅完成「常量/默认值入代码 + `appsettings` 整洁化」阶段）。

## Capabilities

### New Capabilities
- `client-configuration-defaults`: 定义 MaterialClient 4 个桌面宿主的代码内置配置常量、默认值回退、SignalR 地址自动派生以及精简后的 `appsettings*.json` 契约（显式排除 `AliyunOss` 与 `Encryption:AesKey`）。

### Modified Capabilities
- 无现有 spec 修改。

## Impact

- **受影响仓库**：仅 `repos/MaterialClient`（Mode A：Trunk-direct，分支名 `refactor-clean-materialclient-appsettings`）。
- **受影响项目**：
  - `MaterialClient.Common`（新增 `MaterialClientConfigurationDefaults`，调整 `StaticLicenseChecker`、`AttendedWeighingService` 等默认值回退）
  - `MaterialClient`、`MaterialClient.SolidWaste`、`MaterialClient.Urban`、`MaterialClient.Recycle`（宿主 Module / 启动默认值对齐 + `appsettings.json` 与 `appsettings.secret.json` 精简）
- **兼容性**：非破坏性重构。存量现场若仍保留旧版完整 `appsettings*.json` 或环境变量覆写，`IConfiguration` 优先级保持不变，不会破坏既有部署。
- **数据层**：无数据库 Schema 或迁移变更。
