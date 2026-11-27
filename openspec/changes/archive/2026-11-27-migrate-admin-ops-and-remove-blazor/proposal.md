## Why

Stage 1 与 Stage 2 已完成 Vue 3 + Element Plus 工作台壳、项目管理（5001/5020）、称重记录、异常审批、卡口进出与成品进出页面的迁移。目前仅剩「客户端日志」与「客户端更新」两页停留在 Blazor Server，且旧 Blazor 壳与 `/_blazor` SignalR Circuit 仍在运行。

本变更为三阶段迁移的收口阶段（Stage 3），完成最后两页运维工具迁移，并将 `UrbanManagement.Admin` 正式切换为根路径 Vue 3 SPA，彻底移除 Blazor Server、旧 Layui CSS、遗留 JS（含无效外链 ECharts CDN 与 `eval` 下载）以及 Gateway `/_blazor` 路由。

## What Changes

- **迁移客户端日志页（`/ops/client-logs`）**：实现 `ClientLogsView.vue` 与 `src/api/clientLogs.ts`，全部调用受 Cookie 鉴权的 `/api/admin/client-logs/*` BFF；支持 `?clientId=` 自动预选工控机、宽弹层工控机选择、按日期/勾选拉取、持久可关闭结果横幅（不被刷新冲掉）、缓存目录浏览、单文件与批量 ZIP `Blob` 下载及删除。
- **迁移客户端更新页（`/ops/client-updates`）**：实现 `ClientUpdatesView.vue` 与 `src/api/clientOta.ts`，调用 `/api/admin/client-ota/*`；展示服务端安装包清单与在线 2.0 工控机表（均接入 `OpsDataTable`）、高级推送折叠项与推送前确认弹窗。
- **切换根路径 SPA 并下线 Blazor Server**：
  - `vite.config.ts` 切换为 `base: '/'`、`outDir: '../wwwroot'`（保留 `wwwroot/login/*` 与 `fd-ico.ico`）；
  - `AdminSsoAuthentication.Map` 切换为 `MapFallbackToFile("index.html").RequireAuthorization()`，移除 `MapBlazorHub()` 与 `/v2` 过渡路由；
  - `UrbanManagementAdminModule.cs` 移除 `AddServerSideBlazor()` 与 `IPageFilterStateStore`；
  - `UrbanManagement.Admin.csproj` 移除 `Volo.Abp.AspNetCore.Components.Server` 与 `Microsoft.AspNetCore.Mvc.Razor.RuntimeCompilation`；
  - 删除全部旧 `.razor` 页面/组件、`_Host.cshtml`、旧 `wwwroot/css/`、`wwwroot/js/`、`wwwroot/public/`、`wwwroot/v2/` 及 Blazor 专用模型/服务；
  - `UrbanManagement.Gateway/appsettings.json` 移除 `/_blazor` 路由，并更新 `deploy/docker/Dockerfile` 构建注释说明。

## Capabilities

### New Capabilities

### Modified Capabilities

- `admin-vue-workspace`: 补全客户端日志与客户端更新 Vue 页面，并正式接管 Admin 根路径 `/` 与下线 Blazor Server。

## Impact

- 影响子仓库：`repos/UrbanManagement`（`UrbanManagement.Admin`、`UrbanManagement.Gateway`、`deploy/docker/Dockerfile`）。
- 保留 `Login.cshtml` 与 `UrbanAdmin.Session` Cookie 鉴权流程不变，无数据库结构变更。
