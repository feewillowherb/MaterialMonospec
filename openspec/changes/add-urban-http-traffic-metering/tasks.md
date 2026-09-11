## 1. Options and dedicated traffic logger

- [x] 1.1 Add `HttpTrafficMeteringOptions` (+ bind section `HttpTrafficMetering`) with defaults from design (Enabled, PathPrefixes, ExcludePathPrefixes, IncludeQueryString, LogFilePath, RetainedFileCountLimit)
- [x] 1.2 Implement `IHttpTrafficMeterWriter` / `HttpTrafficMeterWriter` in one file: own Serilog `LoggerConfiguration` → File only; EnsureDirectory; Dispose on shutdown; **do not** use host business Serilog sinks
- [x] 1.3 Register Options + writer in `UrbanManagementAppModule.ConfigureServices` (Singleton / `ISingletonDependency` as appropriate); add `HttpTrafficMetering` defaults to `appsettings.json`

## 2. Middleware and pipeline

- [x] 2.1 Implement stream counting helper + `HttpTrafficMeteringMiddleware` (path filter → wrap bodies → `next` → write one traffic event); no full-body buffering for size alone
- [x] 2.2 Register middleware after `UseRouting` (after static files) and before `UseConfiguredEndpoints` in `OnApplicationInitializationAsync`
- [x] 2.3 Confirm business `Serilog` File path remains `Logs/log-.txt` only; traffic never configured into that sink

## 3. Verify

- [x] 3.1 Hit a sample `/api/app/...` (or `/Api/Post`) request: traffic file gains a line with Method/Path/bytes/status/elapsed
- [x] 3.2 Confirm same request does **not** add that traffic template line to `Logs/log-*.txt`
- [x] 3.3 Confirm excluded path (e.g. `/_blazor` or static) and `Enabled=false` produce no traffic line
