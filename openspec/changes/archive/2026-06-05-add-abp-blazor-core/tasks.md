## 1. UrbanManagement — NuGet 包引用与 Blazor 服务注册

- [x] 1.1 在 `Directory.Packages.props` 中添加 `Volo.Abp.AspNetCore.Components.Server` 版本定义（与 ABP 10.0.1 一致）
- [x] 1.2 在 `UrbanManagement.Core.csproj` 中添加 `Volo.Abp.AspNetCore.Components.Server` 的 `PackageReference`
- [x] 1.3 在 `UrbanManagementCoreModule.ConfigureServices` 中调用 `context.Services.AddServerSideBlazor()` 注册 Blazor Server 服务

## 2. UrbanManagement — Blazor 端点与路由配置

- [x] 2.1 在 `UrbanManagementAppModule.OnApplicationInitializationAsync` 的 `UseConfiguredEndpoints` 回调中添加 `endpoints.MapBlazorHub()`
- [x] 2.2 添加 Blazor fallback 路由 `endpoints.MapFallbackToPage("/blazor/{**catchall}", "/_Host")`，确保不影响现有 MVC 路由

## 3. UrbanManagement — Blazor 基础页面脚手架

- [x] 3.1 创建 `Pages/_Host.cshtml` — Blazor Server 宿主页面，包含 `<component>` 标签和 `blazor.server.js` 脚本引用
- [x] 3.2 创建 `Pages/_Imports.razor` — 全局 using 指令（Routing、App.Pages 命名空间）
- [x] 3.3 创建 `Pages/App.razor` — Blazor 根组件，配置 `<Router>`（Found → MainLayout，NotFound → 提示页）
- [x] 3.4 创建 `Pages/MainLayout.razor` — 主布局组件，包含 HTML 结构和 `@Body`
- [x] 3.5 创建 `Pages/Error.razor` — 错误处理页面

## 4. UrbanManagement — 设备状态 Blazor 页面

- [x] 4.1 创建 `Pages/DeviceStatus.razor` — 设备状态监控页面
- [x] 4.2 实现 `OnInitializedAsync`：通过 `IDeviceStatusAppService` 获取客户端列表，逐客户端读取设备状态
- [x] 4.3 实现设备状态聚合逻辑：按设备类型分组，提取最新状态和时间戳
- [x] 4.4 实现 SignalR 连接：连接 `/hubs/devicestatus` Hub，订阅设备状态变更广播
- [x] 4.5 实现 SignalR 消息处理：收到广播后更新对应设备 UI 状态并调用 `StateHasChanged()`
- [x] 4.6 实现 SignalR 断线重连逻辑和缓存状态恢复
- [x] 4.7 实现空状态展示（无设备数据时的提示）
- [x] 4.8 实现 `IAsyncDisposable` 清理 SignalR 连接

## 5. MaterialClient — 设备在线状态 HTTP API

- [x] 5.1 在 `MinimalWebHostService.cs` 中添加 `GET /api/device/online-status` 端点
- [x] 5.2 注入 `SharedDeviceStatusTracker` 获取实时设备状态
- [x] 5.3 实现响应格式 `{ "devices": [ { "deviceType", "isOnline", "deviceName" } ] }`
- [x] 5.4 确保设备类型覆盖 Scale、Camera、Lpr、Printer
- [x] 5.5 确保服务不可用时降级返回 `isOnline: false` 而非 5xx 错误
