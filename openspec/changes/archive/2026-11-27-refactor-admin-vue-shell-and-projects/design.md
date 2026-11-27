## Context

`UrbanManagement.Admin` 当前由 Blazor Server 提供管理 UI，同时通过 `UrbanServicePipeline.ExposeCoreAppServices` 暴露大部分管理 `/api/app/*` 自动接口，并由 `Login.cshtml` + `UrbanAdmin.Session` HttpOnly Cookie 负责 SSO 鉴权。同仓 `UrbanManagement.Recycle` 已验证 Vite + Vue 3 + Element Plus 打包至 `wwwroot` 的单容器部署模式。

## Goals / Non-Goals

**Goals:**
- 建立 `src/UrbanManagement.Admin/client/`（Vue 3.5 + TypeScript + Vite 7 + Element Plus 2.11 + Vue Router 4），输出至 `wwwroot/v2/`，并在 `AdminSsoAuthentication.Map` 中将 `/v2/{**rest}` 映射至 `v2/index.html`（`.RequireAuthorization()`），实现 Stage 1–2 期间与旧 Blazor 无缝并存。
- 落地 3 组 Root Nav 布局壳（城管 / 资源化 / 工控机运维）、`OpsDataTable`（R2）、`ProjectRemoteSelect`（R3）及城管项目/资源化项目页（R4/R5/R6/R7 + 多工控机冗余展开子表）。
- 补齐后端 `AdminBffEndpoints`（`/api/session`、`/api/admin/projects/status-summary`、`/api/admin/client-logs/*`、`/api/admin/client-ota/*`），全部受 `UrbanAdmin.Session` 鉴权保护。

**Non-Goals:**
- 本 Stage 不迁移称重记录、异常审批、卡口/成品进出、客户端日志、客户端更新页面（分别在 Stage 2 与 Stage 3 完成）。
- 本 Stage 不移除 Blazor Server 与 Gateway `/_blazor` 路由（在 Stage 3 完成）。
- 不修改数据库表结构。

## Decisions

1. **过渡期挂载策略（`/v2/`）**：Stage 1 与 Stage 2 期间 Vite `base: '/v2/'`、`outDir: '../wwwroot/v2'`，Admin 映射 `/v2` 及 `/v2/{**rest}` 到 `v2/index.html`（需登录鉴权）；Stage 3 所有页面迁移完毕后切为 `base: '/'`、`outDir: '../wwwroot'` 并下线 Blazor。
2. **多工控机与抓拍机状态聚合（API-2）**：
   - 新增纯逻辑静态聚合器 `ProjectIpcStatusAggregator`（遵循 `minimal-di` 与 `type-owned-methods`，不注册 DI，不引入 tuple，全部使用命名 `record`：`ProjectStatusSummaryDto`、`ProjectIpcSummaryDto`、`ProjectLprItemDto`）；
   - `GET /api/admin/projects/status-summary` 调用 `IDeviceStatusService.GetLiveClientConnectionsAsync()` 与 `GetAllLiveClientDevicesAsync()`，按 `ProId`（匹配 `SourceProId` 与 `Id`）聚合返回每个项目的 `IpcOnlineCount`、`IpcTotalCount`、`IpcStatus`、`LprOnlineCount`、`LprTotalCount`、`LprStatus`、`LastOnlineAt` 与 `Ipcs[]`；
   - 仅保留 `DeviceType == "LPR"` 的设备状态，过滤并丢弃 `Scale` 与 `Camera` 的 UI 聚合展示；老客户端无 LPR 记录时 `LprStatus = "Unreported"`。
3. **Admin BFF 端点（API-3）**：
   - 在 `UrbanManagement.Admin` 新增静态端点映射 `AdminBffEndpoints.Map(IEndpointRouteBuilder endpoints)`，挂载于 `.RequireAuthorization()` 组：
     - `GET /api/session`：返回当前登录用户名；
     - `GET /api/admin/projects/status-summary`：返回项目级工控机与抓拍机聚合字典；
     - `/api/admin/client-logs/*`：代理 `IClientLogAppService`（在线客户端、查询列表、按日期/勾选拉取、目录浏览、单删/批删）；
     - `/api/admin/client-ota/*`：代理 `IOtaPackageCatalogService` 与 `IClientOtaAppService`（包目录、在线客户端、触发推送）。
4. **前端工程规范**：
   - 统一封装 `src/api/http.ts`，遇到 `401` 自动跳转 `/login?returnUrl=...`；
   - `OpsDataTable` 基于 `el-table border` + `height="100%"`，监听 `header-dragend` 按 `tableKey` 写入 `localStorage`，底栏提供「重置列宽」；
   - 严格遵守业务文案红线，页面仅使用业务与运维名词。

## Risks / Trade-offs

- **静态文件与 Razor 回退顺序**：`/v2/assets/*` 需由 `UseStaticFiles()` 优先提供，`/v2/{**rest}` 回退到 `wwwroot/v2/index.html` 且不得拦截 `/api/**` 或 Blazor `/_blazor/**`。通过将 `/v2/{**catchall}` 放在 `MapFallbackToPage` 之前并限定 `/v2` 前缀规避。
- **多工控机匹配口径**：历史上部分客户端上报 `ProId = GovProject.Id`，部分上报 `GovProject.SourceProId`；聚合索引以归一化 `ProId` 字符串键返回，前端优先按 `sourceProId` 查、回退 `id` 查，确保 5001 与 5020 均不查漏。
