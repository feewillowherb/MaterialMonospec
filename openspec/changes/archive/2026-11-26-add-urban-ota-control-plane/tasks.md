# Tasks: add-urban-ota-control-plane

> 目标仓库：`repos/UrbanManagement` 与 `repos/MaterialClient`（Mode A：Trunk-direct，双仓均切到同名分支 `add-urban-ota-control-plane`）。

## 1. `repos/UrbanManagement` 服务端控制面

- [x] 1.1 在 `UrbanManagement.Core/Models/ClientOtaDtos.cs` 新增 `ClientOtaStatusReportDto`、`OnlineClientOtaDto`、`TriggerClientOtaInputDto`、`TriggerClientOtaResultDto` 与 `ClientOtaInternalApi`。
- [x] 1.2 扩展 `UrbanManagement.Core/Hubs/DeviceStatusHub.cs`：新增 `_otaStatusRegistry`、`ReportOtaStatus`、`GetOnlineOtaClients`、`TryGetOtaConnectionId` 及断线自动清理。
- [x] 1.3 新增 `UrbanManagement.Core/Services/ClientOtaAppService.cs`（`IClientOtaAppService` + `ClientOtaAppService`）。
- [x] 1.4 新增 `UrbanManagement.Realtime/Controllers/ClientOtaInternalController.cs` 与 `UrbanManagement.Admin/Services/RemoteClientOtaAppService.cs`，并在 `UrbanManagementAdminModule.cs` 注册。
- [x] 1.5 新增 `UrbanManagement.Admin/Pages/ClientUpdates.razor`（`/client-updates`）并在 `AdminLayout.razor` 添加「客户端更新」导航项。

## 2. `repos/MaterialClient` 客户端上报与远程触发

- [x] 2.1 扩展 `MaterialClient.Common/Services/DeviceStatusSignalRClient.cs`（`IDeviceStatusSignalRClient` + `DeviceStatusSignalRClient`）：新增 `ClientOtaStatusReport`、`ReportOtaStatusAsync` 与 `OnReceiveOtaTriggerCommand`。
- [x] 2.2 扩展 `MaterialClient.Urban/Services/Updates/UrbanUpdateService.cs`：`CheckAndDownloadUpdateAsync` 支持可选 `feedUrlOverride` 灰度源。
- [x] 2.3 新增 `MaterialClient.Urban/Services/Updates/ClientOtaControlService.cs`，并在 `MaterialClientUrbanModule.cs` 启动初始化（注册回调、监听重连自动上报、响应远程触发指令）。

## 3. 双仓单元测试与编译验证

- [x] 3.1 在 `UrbanManagement.Core.Tests` 与 `MaterialClient.Urban.Tests` 补充单元测试覆盖 OTA 注册表/触发指令与客户端远程触发流程。
- [x] 3.2 分别在 `repos/UrbanManagement` 与 `repos/MaterialClient` 执行 `dotnet build` 与 `dotnet test`（`MaterialClient.sln` 0 错误、`MaterialClient.Urban.Tests` 11/11 通过；`UrbanManagement.Admin` 与 `UrbanManagement.Realtime` 0 错误；`UrbanManagement.Core.Tests` 中本次新增的 `ClientOtaAppServiceTests` 编译无误，测试执行受存量无关文件 `RecyclePersistenceRulesTests.cs:93` 阻塞）。
