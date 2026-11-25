# Tasks: update-materialclient-endpoint-defaults

> 目标仓库：`repos/MaterialClient`（Mode A：Trunk-direct，Apply 前切到同名分支 `update-materialclient-endpoint-defaults`）。
> 显式排除：`AliyunOss` 与 `Encryption:AesKey` 继续保留在 `appsettings.secret.json` 中不变。

## 1. 服务端点默认常量与解析辅助（`MaterialClient.Common`）

- [x] 1.1 在 `MaterialClientConfigurationDefaults.cs` 中定义 `Production*` / `Debug*` 与 `#if DEBUG` 切换的 `DefaultBasePlatformBaseUrl`、`DefaultMaterialPlatformBaseUrl`、`DefaultUrbanManagementBaseUrl`、`DefaultRecycleSyncApiUrl`，以及 `ResolveEndpointUrl(string? configuredUrl, string defaultUrl)`。
- [x] 1.2 更新 `RefitClientRegistrationExtensions.cs` 使用 `ResolveEndpointUrl` 与 `DefaultBasePlatformBaseUrl` / `DefaultMaterialPlatformBaseUrl`。
- [x] 1.3 更新 `MaterialClientUrbanModule.cs` 与 `MaterialClientRecycleModule.cs` 使用 `ResolveEndpointUrl` 与 `DefaultUrbanManagementBaseUrl` / `DefaultRecycleSyncApiUrl`。

## 2. 清理 4 个宿主 `appsettings*.json` 与 `.csproj` 发布规则

- [x] 2.1 将 `MaterialClient.Urban/appsettings.json` 与 `MaterialClient.Recycle/appsettings.json` 清空为 `{}`（4 个宿主统一为 `{}`）。
- [x] 2.2 从 4 个宿主的 `appsettings.secret.json` 中移除 `BasePlatform` 与 `MaterialPlatform`（保持 `AliyunOss`、`Encryption:AesKey` 及 Recycle 凭证占位不变）。
- [x] 2.3 在 4 个宿主 `.csproj` 的 `appsettings.json` 项上添加 `<CopyToPublishDirectory>Never</CopyToPublishDirectory>`。

## 3. 单元测试与验证

- [x] 3.1 在 `MaterialClientConfigurationDefaultsTests.cs` 补充测试验证 `Production*`、`Debug*` 常量、`ResolveEndpointUrl` 覆写与回退、`ResolveSignalRServerUrl` 派生。
- [x] 3.2 执行 `dotnet build MaterialClient.sln -o .build-verify` 与 `dotnet test`，确保全量编译与单测通过。
