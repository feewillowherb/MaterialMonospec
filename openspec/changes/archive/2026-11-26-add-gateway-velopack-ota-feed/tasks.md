# Tasks: add-gateway-velopack-ota-feed

> 目标仓库：`repos/UrbanManagement`（Mode A：Trunk-direct，Apply 前切到同名分支 `add-gateway-velopack-ota-feed`）。

## 1. Gateway 静态 OTA 包源实现

- [x] 1.1 更新 `repos/UrbanManagement/src/UrbanManagement.Gateway/Program.cs`：读取 `OtaFeed:RootPath`（默认 `{ContentRootPath}/Updates`），挂载 `/updates` 静态文件服务（含 `.nupkg`/`.exe`/`.zip`/`.json`/`RELEASES` MIME 与缓存头），并在静态文件未命中时对 `/updates/**` 直接返回 `404`。
- [x] 1.2 更新 `repos/UrbanManagement/deploy/docker/compose.yaml`：在 `um-gateway` 增加 `OtaFeed__RootPath: /app/Updates` 环境变量与 `${UM_UPDATES_HOST_PATH:-./updates}:/app/Updates:ro` 挂载。

## 2. 编译与验证

- [x] 2.1 在 `repos/UrbanManagement` 执行 `dotnet build src/UrbanManagement.Gateway/UrbanManagement.Gateway.csproj` 验证编译 0 错误，并启动本地 Gateway 验证 `/updates/urban/releases.win.json`（200 + `no-cache`）与缺失文件（404）行为。
