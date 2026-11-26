# Tasks: refactor-client-log-http-zip-upload

## 1. UrbanManagement (Server)
- [x] 1.1 Update `DeviceStatusHub` to track `LogFormatVersion` (registering 2.0 log upload capability automatically in `RegisterSession` and exposing `TryGetLogRouteForClient` with named `record ClientLogRoute`) while keeping 1.0 `RegisterLogCapability` / `ReturnLogList` / `ReceiveFileChunk` compatible
- [x] 1.2 Implement pending upload ticket store, `POST /api/client-log/upload-zip` streaming receiver (with one-time token verification, 500MB cap, Zip Slip protection, and temp zip cleanup), and 2.0 `PullLogsByDateAsync` dispatch in `ClientLogAppService` & `ClientLogController`
- [x] 1.3 Fix `ClientLogAppService.DownloadBatchCachedAsync` (stream directly to temp file without `MemoryStream.ToArray()`) and `ClientLogController.DownloadBatch` (`FileOptions.DeleteOnClose` instead of racy `finally` `File.Delete`), plus 0-byte chunk completion guard in `OnServerFileChunk`

## 2. MaterialClient (Client)
- [x] 2.1 Add `OnReceiveLogUploadRequest` callback registration to `IDeviceStatusSignalRClient` / `DeviceStatusSignalRClient` and include `"log-http-zip"` capability in `ClientHeartbeatBackgroundWorker`
- [x] 2.2 Implement static `ClientLogZipPacker` (L4 `Path.GetFullPath` boundary validation + L3 0-byte file packing with `FileShare.ReadWrite`) and shared `IClientLogUploadService` / `ClientLogUploadService` in `MaterialClient.Common/Services/Logging/`
- [x] 2.3 Wire `MaterialClient.Urban` (`MaterialClientUrbanModule`) to `IClientLogUploadService` and remove obsolete host-specific `MaterialClient.Urban/Services/ClientLogPullService.cs`

## 3. Verification
- [x] 3.1 Add unit tests in `MaterialClient.Common.Tests` covering `ClientLogZipPacker` (0-byte file packing, `Path.GetFullPath` traversal rejection, empty date folder)
- [x] 3.2 Run sequential `dotnet build` & `dotnet test` on `MaterialClient` and `UrbanManagement` (`UrbanManagement.Admin`, `UrbanManagement.Realtime`) and verify 0 errors
