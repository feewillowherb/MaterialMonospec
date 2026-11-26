# Tasks: enhance-device-health-and-camera-polling

## 1. MaterialClient (Client)
- [x] 1.1 Create `DeviceHealthSnapshot.cs` (`DeviceEndpointHealthItem`, `DeviceGroupHealthSummary`, static `DeviceHealthSnapshotFormatter`) in `MaterialClient.Common/Models/`
- [x] 1.2 Expose read-only `GateIoHealthSnapshot GetHealthSnapshot()` on `IGateIoControlService` / `GateIoControlService`
- [x] 1.3 Implement shared `IDeviceHealthProbeService` / `DeviceHealthProbeService` in `MaterialClient.Common/Services/` probing Cameras (`IHikvisionService`), LPR (`ILprDeviceOnlineStatusService`), and GateIo (`IGateIoControlService`), and wire periodic invocation into `ClientHeartbeatBackgroundWorker`

## 2. UrbanManagement (Server & Admin)
- [x] 2.1 Add `"GateIo"` to `DeviceStatusService.ValidDeviceTypes` and create `DeviceHealthDetailDtos.cs` (`DeviceHealthDetailParser.TryParse`) in `UrbanManagement.Core/Models/`
- [x] 2.2 Enhance `ProjectManagement.razor` device detail modal to display `"GateIo"`, `"Degraded"`, per-channel structured device details, and an abnormal-only filter toggle

## 3. Verification
- [x] 3.1 Add unit tests in `MaterialClient.Common.Tests` for `DeviceHealthSnapshotFormatter` (all online, partial degraded, all offline, empty) and `DeviceHealthProbeService`
- [x] 3.2 Run sequential `dotnet build` & `dotnet test` across `MaterialClient` and `UrbanManagement` (`UrbanManagement.Realtime`, `UrbanManagement.Admin`) and verify 0 errors
