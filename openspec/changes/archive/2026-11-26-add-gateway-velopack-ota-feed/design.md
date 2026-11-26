# Design: UrbanManagement.Gateway `/updates/` 静态 OTA 包源

## Context

`UrbanManagement.Gateway` 是唯一的对外 HTTP 入口（生产 `5233`、138 实验室 `5333`）。在 `Program.cs` 中注册 `UseStaticFiles`（位于 `MapReverseProxy` 之前）并拦截未命中的 `/updates/**` 请求直接返回 404，即可在零新增容器的前提下提供完整的 Velopack 静态源服务。

## Decisions

### 1. 静态目录与产品子目录约定

- 配置键：`OtaFeed:RootPath`（未配置时默认 `Path.Combine(app.Environment.ContentRootPath, "Updates")`）。
- 若目录不存在且可写，启动时自动创建；若目录以只读卷挂载且已存在，直接使用；若只读且不存在，跳过静态挂载但仍对 `/updates/**` 返回 404（不崩溃）。
- 目录结构：
  ```text
  /app/Updates/
  ├── urban/      ← GET /updates/urban/releases.win.json, *.nupkg, Setup.exe
  └── recycle/    ← 预留给 MaterialClient.Recycle
  ```

### 2. MIME 与缓存策略

- 显式注册 `.nupkg` → `application/octet-stream`、`.exe` → `application/octet-stream`、`.zip` → `application/zip`、`.json` → `application/json`。
- 开启 `ServeUnknownFileTypes = true` 且 `DefaultContentType = "text/plain"`，保证 Velopack 兼容文件 `RELEASES`（无扩展名）可被正常下载。
- `OnPrepareResponse`：
  - `.json` 或文件名 `RELEASES`：`Cache-Control: no-cache, no-store, must-revalidate`；
  - `.nupkg` / `.exe` / `.zip`：`Cache-Control: public, max-age=86400`。

### 3. 阻止 `/updates/**` 回落到 Blazor fallback

在 `UseStaticFiles` 之后、`MapReverseProxy` 之前增加拦截中间件：凡是仍未命中静态文件且路径以 `/updates` 开头的请求，直接返回 `404 Not Found`，避免 YARP 将请求转给 `um-admin` 返回 HTML。
