# Proposal: Refactor Client Log Pull to SignalR Command + HTTP Zip Upload

## Why

当前远程日志拉取存在多项结构性缺陷（见 `docs/2026-11-26-urban-recycle-logging-online-audit/01-日志系统代码缺陷与不合理设计.md`）：
- **L3（0 字节日志挂死）**：旧 SignalR 分片循环在 `fileInfo.Length == 0` 时计算 `totalChunks == 0` 导致永不发送完成信号，服务端苦等 120s 超时。
- **L4（路径穿越校验缺陷）**：客户端仅用 `fullPath.StartsWith(_logBaseDirectory)` 校验边界，未经过 `Path.GetFullPath` 规范化与目录分隔符封口。
- **L5（容器内存放大）**：服务端使用 `MemoryStream` 在内存中缓冲整份 SignalR 分片文件，`DownloadBatchCachedAsync` 同样用 `MemoryStream.ToArray()` 产生双倍内存峰值。
- **L7（临时 ZIP 清理竞态与上传鉴权缺失）**：`ClientLogController.DownloadBatch` 在返回 `FileStream` 之前于 `finally` 中调用 `File.Delete`，导致 Windows 句柄锁残留或 Linux 提前 unlink；同时新增 HTTP 日志上传端点必须具备一次性令牌校验。
- **D4（客户端能力未共享）**：`ClientLogPullService` 位于 `MaterialClient.Urban` 宿主中，无法被其他客户端复用。

## What Changes

1. **UrbanManagement（服务端）**：
   - 在 `DeviceStatusHub` 支持 2.0 客户端日志路由识别（`LogFormatVersion = "2.0"`），同时完整保留 1.0 客户端 `RegisterLogCapability`、`ReturnLogList`、`ReceiveFileChunk` 兼容。
   - 新增服务端流式 HTTP Zip 上传端点 `POST /api/client-log/upload-zip`（单次随机 `uploadToken` + `requestId` + `clientId` 校验，流式落盘与防 Zip Slip 解压，不使用 `MemoryStream` 缓冲大文件）。
   - `ClientLogAppService.PullLogsByDateAsync` 对 2.0 客户端下发 SignalR 控制指令 `ReceiveLogUploadRequest(requestId, clientId, dateFolder, uploadPath, uploadToken)` 并等待上传完成；对 1.0 客户端自动回退既有 SignalR 分片拉取路径。
   - 修复 `ClientLogController.DownloadBatch` 与 `ClientLogAppService.DownloadBatchCachedAsync`：直接流式写盘并通过 `FileOptions.DeleteOnClose` 自动清理临时 ZIP，消除 `MemoryStream` 双倍内存峰值与 `finally` 删除竞态。

2. **MaterialClient（客户端）**：
   - 在 `MaterialClient.Common` 新增共享 `IClientLogUploadService` / `ClientLogUploadService` 与无 DI 纯逻辑 `ClientLogZipPacker`：响应 `ReceiveLogUploadRequest`，以 `Path.GetFullPath` 严格校验边界（修复 L4），将目标日期日志（含 0 字节文件，修复 L3）流式打包为本地临时 `.zip` 并通过 `HttpClient` multipart 流式 POST 上传到服务端，结束后清理临时文件。
   - `MaterialClient.Urban` 接入共享 `IClientLogUploadService` 并移除原宿主内重复的 `ClientLogPullService`；`MaterialClient.Recycle` 宿主本单暂不修改。

## Capabilities

### New Capabilities
- `client-log-http-upload`: 基于 SignalR 控制指令与 HTTP multipart Zip 流式上传的客户端日志拉取协议、安全校验与 1.0 兼容回退机制。

## Impact

- **Repos**: `repos/UrbanManagement`, `repos/MaterialClient`
- **Compatibility**: 1.0 客户端继续沿用既有 `RegisterLogCapability` + SignalR 分片路径，不破坏现网运行；Admin `/client-logs` 页面缓存目录浏览、单文件与批量下载保持兼容。
