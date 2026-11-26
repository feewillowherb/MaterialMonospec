# Design: Refactor Client Log Pull to SignalR Command + HTTP Zip Upload

## Architecture Overview

```
Admin (/client-logs)
  │ POST /internal/client-log/pull-logs-by-date
  ▼
UrbanManagement.Realtime (ClientLogAppService)
  ├─ 2.0 Client (LogFormatVersion == "2.0" or "log-http-zip" capability)
  │    1. Mint pending upload ticket (requestId, clientId, one-time 32B uploadToken, 5m TTL)
  │    2. Hub.SendAsync("ReceiveLogUploadRequest", requestId, clientId, dateFolder, "/api/client-log/upload-zip", uploadToken)
  │    3. Await TaskCompletionSource<LogUploadCompletionResult> (timeout 180s)
  │         ▲
  │         │ HTTP POST /api/client-log/upload-zip (multipart/form-data, streaming to disk)
  │    MaterialClient.Common (ClientLogUploadService + ClientLogZipPacker)
  │         • Validate dateFolder & every file via Path.GetFullPath boundary check (L4)
  │         • Pack matched .log files (including 0-byte files, L3) into temp .zip via FileShare.ReadWrite
  │         • Stream temp .zip via StreamContent to {UrbanManagement:BaseUrl}{uploadPath}
  │         • Delete local temp .zip in finally
  │
  └─ 1.0 Client (LogFormatVersion != "2.0")
       Fallback to existing RequestLogListAsync + PullAndCacheAsync (SignalR 64KB chunks)
```

## Key Technical Decisions

1. **Relative `uploadPath` over SignalR**:
   - `um-realtime` sits behind `UrbanManagement.Gateway` and may not know its public scheme/host.
   - Passing `uploadPath = "/api/client-log/upload-zip"` lets the client resolve it against its already-configured `UrbanManagement:BaseUrl` (or use as-is if absolute).
2. **One-Time Upload Token (L7)**:
   - Every `RequestLogUpload` generates a 32-byte `RandomNumberGenerator` URL-safe token bound to `(requestId, clientId)` with a 5-minute TTL and single-use consumption (`TryRemove` + `CryptographicOperations.FixedTimeEquals`).
3. **Zero `MemoryStream` Buffering (L5)**:
   - Server `POST /api/client-log/upload-zip` streams `IFormFile` directly into a temp `.zip` file on disk, enforces `MaxZipSizeBytes` (500MB), validates every ZIP entry against Zip Slip (`Path.GetFullPath`), extracts to `ClientLogs/{SafeProName}/{ClientId}/`, and deletes the temp `.zip` in `finally`.
   - `DownloadBatchCachedAsync` writes directly into a temp `.zip` `FileStream` instead of `MemoryStream.ToArray()`, and `ClientLogController.DownloadBatch` opens it with `FileOptions.DeleteOnClose` (removing the racy `finally { File.Delete(...) }`).
4. **0-Byte File & Empty Date Handling (L3)**:
   - `ClientLogZipPacker` includes 0-byte `.log` files as valid ZIP entries.
   - When 0 files exist for `dateFolder`, the client still posts `fileCount=0` (without a zip file) to `/api/client-log/upload-zip` so the server completes immediately instead of timing out.
5. **C# & DI Conventions**:
   - Multi-value return types use named `record` (`ClientLogRoute`, `LogUploadCompletionResult`, `LogZipPackResult`) — zero tuples.
   - Pure packing/path validation lives in static `ClientLogZipPacker` (no DI registration per `minimal-di`).
   - `IClientLogUploadService` / `ClientLogUploadService` lives in `MaterialClient.Common/Services/Logging/` for shared reuse across hosts.
