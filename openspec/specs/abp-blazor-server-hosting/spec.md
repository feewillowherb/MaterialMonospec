# ABP Blazor Server Hosting Specification

## Purpose

定义 UrbanManagement 项目中 ABP Blazor Server 集成的基础设施，包括 NuGet 包引用、服务注册、端点映射、宿主页面和基础页面脚手架，以及 MaterialClient 设备在线状态 HTTP API。

## Requirements

### Requirement: Blazor Server NuGet 包引用
`UrbanManagement.App.csproj` MUST 引用 `Volo.Abp.AspNetCore.Components.Server` NuGet 包以启用 ABP Blazor Server 集成。`UrbanManagement.Core.csproj` MUST NOT 引用此包。

#### Scenario: App 项目包含 Blazor 包
- **WHEN** 检查 `UrbanManagement.App.csproj` 的包引用
- **THEN** MUST 包含 `Volo.Abp.AspNetCore.Components.Server` 的 `PackageReference`

#### Scenario: Core 项目不含 Blazor 包
- **WHEN** 检查 `UrbanManagement.Core.csproj` 的包引用
- **THEN** MUST NOT 包含 `Volo.Abp.AspNetCore.Components.Server` 的 `PackageReference`

### Requirement: Blazor Server 服务注册
`UrbanManagementAppModule` MUST 在 `ConfigureServices` 中注册 Blazor Server 服务。`UrbanManagementCoreModule` MUST NOT 注册 Blazor Server 服务。

#### Scenario: AppModule 注册 AddServerSideBlazor
- **WHEN** `UrbanManagementAppModule.ConfigureServices` 执行
- **THEN** MUST 调用 `context.Services.AddServerSideBlazor()` 注册 Blazor Server 服务

#### Scenario: CoreModule 不注册 AddServerSideBlazor
- **WHEN** `UrbanManagementCoreModule.ConfigureServices` 执行
- **THEN** MUST NOT 调用 `context.Services.AddServerSideBlazor()`

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

#### Scenario: SignalR Hub 端点保留
- **WHEN** 应用启动完成
- **THEN** MUST 仍然映射 `endpoints.MapHub<DeviceStatusHub>("/hubs/devicestatus")` 供 MaterialClient SignalR 客户端使用

### Requirement: Blazor Server 宿主页面
UrbanManagement MUST 包含 `_Host.cshtml` 作为 Blazor Server 的宿主页面。

#### Scenario: _Host.cshtml 页面结构
- **WHEN** Blazor Circuit 初始化
- **THEN** MUST 存在 `_Host.cshtml` 页面包含 `<component type="typeof(App)" render-mode="ServerPrerendered" />` 标签
- **AND** MUST 包含 `<script src="_framework/blazor.server.js"></script>` 脚本引用

### Requirement: Blazor 全局 Using 指令
UrbanManagement MUST 包含 `_Imports.razor` 文件定义 Blazor 组件的全局命名空间。

#### Scenario: 全局 Using 内容
- **WHEN** 任何 Blazor 组件编译
- **THEN** `_Imports.razor` MUST 包含 `@using Microsoft.AspNetCore.Components.Routing` 和 `@using UrbanManagement.App.Pages` 命名空间

### Requirement: Blazor 根组件
UrbanManagement MUST 包含 `App.razor` 作为 Blazor 组件树的根。

#### Scenario: Router 配置
- **WHEN** `App.razor` 渲染
- **THEN** MUST 包含 `<Router>` 组件配置 `AppAssembly`
- **AND** MUST 设置 `Found` 模板渲染 `MainLayout`
- **AND** MUST 设置 `NotFound` 模板渲染 404 提示

### Requirement: Blazor 主布局组件
UrbanManagement MUST 包含 `MainLayout.razor` 作为 Blazor 页面的共享布局。

#### Scenario: 布局结构
- **WHEN** 任何 Blazor 页面渲染
- **THEN** `MainLayout.razor` MUST 包含 `<body>` 标签
- **AND** MUST 包含 `@Body` 占位符用于渲染页面内容
- **AND** MUST 包含基础 HTML 结构（html, head, title）

### Requirement: Blazor 错误页面
UrbanManagement MUST 包含 `Error.razor` 用于处理 Blazor 运行时错误。

#### Scenario: 错误页面内容
- **WHEN** Blazor 组件发生未处理异常
- **THEN** MUST 渲染错误描述信息
- **AND** MUST NOT 暴露堆栈跟踪（非 Development 环境）

### Requirement: MaterialClient 设备在线状态 HTTP API
MaterialClient.Urban 的 `MinimalWebHostService` MUST 新增设备在线状态查询 API 端点。

#### Scenario: 获取设备在线状态
- **WHEN** 发送 `GET /api/device/online-status` 请求
- **THEN** MUST 返回 JSON 响应，包含各设备类型的在线/离线状态
- **AND** 响应格式 MUST 为 `{ "devices": [ { "deviceType": "...", "isOnline": true/false, "deviceName": "..." } ] }`

#### Scenario: 设备类型覆盖
- **WHEN** 查询设备在线状态
- **THEN** 返回的设备类型 MUST 至少包含：`Scale`（地磅）、`Camera`（摄像头）、`Lpr`（车牌识别）、`Printer`（打印机）

#### Scenario: 服务不可用时降级
- **WHEN** `DeviceManagerService` 未初始化或设备未注册
- **THEN** 对应设备 MUST 返回 `isOnline: false`
- **AND** MUST 返回 HTTP 200（非 5xx 错误）
