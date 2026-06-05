## MODIFIED Requirements

### Requirement: Blazor Server 端点映射
`UrbanManagementAppModule` MUST 在 `OnApplicationInitializationAsync` 中映射 Blazor Server 端点，使其作为主 UI 入口。LegacyApiController 的 MVC 路由 SHALL 作为仅存的 MVC 端点保留。

#### Scenario: Blazor hub endpoint 已映射
- **WHEN** 应用启动完成且 `UseConfiguredEndpoints` 执行
- **THEN** MUST 调用 `endpoints.MapBlazorHub()` 映射 Blazor Server SignalR circuit endpoint
- **AND** MUST 调用 `endpoints.MapControllers()` 映射 LegacyApiController 的 MVC 路由

#### Scenario: Blazor fallback 作为默认路由
- **WHEN** 根路径 `/` 或任何非 API 路由被请求
- **THEN** MUST 通过 `endpoints.MapFallbackToPage("/{**catchall}", "/_Host")` 将所有非 API 请求 fallback 到 `_Host.cshtml` 页面
- **AND** MUST NOT 使用 `/blazor` 前缀隔离

#### Scenario: _Host.cshtml 页面结构
- **WHEN** Blazor Circuit 初始化
- **THEN** MUST 存在 `_Host.cshtml` 页面包含 `<component type="typeof(App)" render-mode="ServerPrerendered" />` 标签
- **AND** MUST 包含 `<script src="_framework/blazor.server.js"></script>` 脚本引用

#### Scenario: SignalR Hub 端点保留
- **WHEN** 应用启动完成
- **THEN** MUST 仍然映射 `endpoints.MapHub<DeviceStatusHub>("/hubs/devicestatus")` 供 MaterialClient SignalR 客户端使用

## REMOVED Requirements

### Requirement: Blazor fallback 到 _Host.cshtml (旧版 /blazor 前缀)
**Reason**: Blazor 成为主 UI 框架，不再需要 `/blazor` 路由前缀隔离。所有页面路由直接从根路径开始。
**Migration**: `_Host.cshtml` fallback 从 `/blazor/{**catchall}` 变更为 `/{**catchall}`。所有 Blazor 页面路由移除 `/blazor` 前缀（如 `/blazor/device-status` → `/device-status`）。
