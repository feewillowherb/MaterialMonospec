# Design: 服务端点 Release/Debug 代码默认值与 appsettings.json 零发布

## Context

`MaterialClient` 四个桌面宿主（Standard / SolidWaste / Urban / Recycle）在生产环境下连接统一的正式服务端，而开发/测试阶段需要指向测试环境（如 135 / 138 / localhost）。本次变更是 `refactor-clean-materialclient-appsettings` 的直接延续，进一步消除 `appsettings*.json` 中的服务端 URL 依赖。

## Decisions

### 1. 代码内 `#if DEBUG` 与 `Release` 默认地址

在 `MaterialClientConfigurationDefaults` 中显式暴露三组常量：
- `Production*` 常量（固定正式地址）：
  - `ProductionBasePlatformBaseUrl = "http://base.publicapi.findong.com"`
  - `ProductionMaterialPlatformBaseUrl = "http://mt.publicapi.findong.com"`
  - `ProductionUrbanManagementBaseUrl = "http://191.12.234.212:5233"`
  - `ProductionRecycleSyncApiUrl = "http://localhost"`
- `Debug*` 常量（开发/测试防误连地址）：
  - `DebugBasePlatformBaseUrl = "http://192.168.3.135:8551"`
  - `DebugMaterialPlatformBaseUrl = "http://localhost:5000"`
  - `DebugUrbanManagementBaseUrl = "http://192.168.3.138:5333"`
  - `DebugRecycleSyncApiUrl = "http://localhost"`
- 运行时默认常量（按 `#if DEBUG` 编译期选择）：
  - `DefaultBasePlatformBaseUrl`
  - `DefaultMaterialPlatformBaseUrl`
  - `DefaultUrbanManagementBaseUrl`
  - `DefaultRecycleSyncApiUrl`

同时提供辅助方法 `ResolveEndpointUrl(string? configuredUrl, string defaultUrl)`：当 `configuredUrl` 非空白时返回 `configuredUrl.Trim()`，否则返回 `defaultUrl`。这样即使 `appsettings.json` 中写空字符串也不会导致 `new Uri("")` 抛异常。

### 2. 消除 `appsettings.secret.json` 对测试 URL 的遮蔽

在 `PreConfigureServices` 中，`appsettings.secret.json` 在 `appsettings.json` 之后加载。移除 `appsettings.secret.json` 中的 `BasePlatform:BaseUrl` 与 `MaterialPlatform:BaseUrl` 后：
- `appsettings.secret.json` 仅保留显式排除项（`AliyunOss`、`Encryption:AesKey`）及 Recycle 站点凭证占位；
- 测试人员在 `.exe` 同目录的 `appsettings.json` 中写入任意 `BaseUrl` 时，不会被 `appsettings.secret.json` 覆盖。

### 3. `appsettings.json` 不随发布包输出

在 4 个宿主 `.csproj` 的 `<None Include="appsettings.json" ...>` 中增加 `<CopyToPublishDirectory>Never</CopyToPublishDirectory>`：
- `dotnet publish` 产物中不包含 `appsettings.json`；
- 程序启动时若目录中无 `appsettings.json`，全部走代码内置默认值；
- 测试或特殊部署若在 `.exe` 同目录手动创建 `appsettings.json`，ABP / `HostConfigurationComposer` 会自动加载并覆盖代码默认值。

## Risks / Trade-offs

- **风险**：Urban 的 `SignalRClientOptions.ServerUrl` 由 `UrbanManagement:BaseUrl` 派生；在 `Release` 下自动派生为 `http://191.12.234.212:5233/hubs/devicestatus`，在 `Debug` 下自动派生为 `http://192.168.3.138:5333/hubs/devicestatus`，与生产/测试架构完全一致。
- **风险**：单元测试在 `Debug` 配置下运行，通过同时暴露 `Production*` 与 `Debug*` 常量，可在单测中同时验证生产常量值、Debug 常量值与 `ResolveEndpointUrl` 覆写行为。
