# Change: 在 UrbanManagement.Gateway 挂载 `/updates/` Velopack 静态 OTA 包源

## Why

`MaterialClient.Urban` 已完成客户端侧 Velopack OTA 引擎接入（`add-urban-velopack-ota`），默认从 `{UrbanManagement:BaseUrl}/updates/urban` 拉取 `releases.win.json`、`*-full.nupkg` 与 `*-delta.nupkg`。当前 `UrbanManagement.Gateway` 的 YARP `fallback` 路由会把 `/updates/**` 透传到 `um-admin` Blazor 页面，导致客户端无法获取静态更新清单与安装包。

按 [`07-2.0演进并存与局部隔离策略.md`](../../docs/2026-11-25-urban-admin-client-management-consistency/07-2.0演进并存与局部隔离策略.md) 的「零新增微服务、复用现有网关」策略，直接在 `UrbanManagement.Gateway` 暴露 `/updates/` 静态包目录即可打通服务端数据面，并天然支持未来按产品子目录扩展（`/updates/urban`、`/updates/recycle` 等）。

## What Changes

- **在 `UrbanManagement.Gateway` 挂载 `/updates` 静态文件服务**：
  - 支持通过 `OtaFeed:RootPath` 配置物理目录（默认 `{ContentRootPath}/Updates`，Docker 中挂载 `/app/Updates`）；
  - 配置 Velopack 所需 MIME 映射（`.nupkg` / `.exe` / `.zip` / `.json`，并允许无扩展名的 `RELEASES` 清单文件返回 `text/plain`）；
  - 对清单文件（`*.json`、`RELEASES`）返回 `Cache-Control: no-cache`，防止客户端读到过期版本清单；
  - 对 `/updates/**` 下不存在的文件直接返回 `404 Not Found`，绝不回落到 YARP `um-admin` Blazor fallback 页面（避免 Velopack 把 HTML 当 JSON 解析报错）。
- **更新 Docker Compose 部署编排**：
  - 在 `deploy/docker/compose.yaml` 的 `um-gateway` 增加 `OtaFeed__RootPath: /app/Updates` 与只读目录挂载 `${UM_UPDATES_HOST_PATH:-./updates}:/app/Updates:ro`（零新增容器）。

## Capabilities

### Modified Capabilities
- `urban-gateway`: 新增 `/updates/` Velopack 静态 OTA 包源托管与防 fallback 404 隔离要求。

## Impact

- **受影响仓库**：仅 `repos/UrbanManagement`（Mode A：Trunk-direct，分支名 `add-gateway-velopack-ota-feed`）。
- **受影响文件**：`src/UrbanManagement.Gateway/Program.cs`、`deploy/docker/compose.yaml`。
- **兼容性**：非破坏性。现有 `/api/**`、`/hubs/devicestatus/**`、`/_blazor/**` 与页面路由完全不受影响。
