## Context

Stage 1–2 已将 Vue 3 + Element Plus 工作台部署在 `/v2/` 并通过构建校验。Stage 3 完成最后两个运维工具页（客户端日志、客户端更新），并将整个 Admin 切回根路径 `/`，与 `UrbanManagement.Recycle` 完全同构（Razor `Login.cshtml` + `UseStaticFiles()` + `MapFallbackToFile("index.html").RequireAuthorization()`）。

## Goals / Non-Goals

**Goals:**
- `ClientLogsView.vue` 与 `ClientUpdatesView.vue` 均使用 `OpsDataTable`（R2 滚动容器 + 全表头拖拽调宽）与统一状态徽标。
- 彻底移除 Blazor Server 依赖、SignalR Circuit 路由 `/_blazor` 与手写 Layui CSS/JS 债务。
- 保留 `wwwroot/login/*`、`wwwroot/fd-ico.ico` 以及 `Pages/Login.cshtml` 完整可用。

**Non-Goals:**
- 不改变 `UrbanManagement.Realtime` 内部接口协议或 Velopack 客户端更新机制。

## Decisions

1. **静态资产保留策略**：`vite.config.ts` 设 `outDir: '../wwwroot'` 与 `emptyOutDir: false`，并在构建前清理旧 `wwwroot/assets`（或保持覆盖），确保 `wwwroot/login/*` 与 `wwwroot/fd-ico.ico` 不被误删。
2. **批量 ZIP 下载**：客户端日志批量下载继续使用 Gateway 暴露的 `/api/client-log/download-batch`（`POST` 返回 ZIP 流），前端用原生 `fetch` + `Blob` + `URL.createObjectURL` 触发下载，彻底告别 `site.js` JS Interop。
3. **Gateway 路由清理**：从 `UrbanManagement.Gateway/appsettings.json` 删除 `blazor` 路由项（`/_blazor/{**rest}`），其余 `/api/**`、`/hubs/devicestatus/**`、fallback `/{**rest}` 保持不变。

## Risks / Trade-offs

- **构建产物归位**：删除 `wwwroot/v2/` 后，所有旧链接 `/`、`/weighing`、`/recycle-projects` 等均由 Vue Router 根路径直接承接并自动重定向至新分组路由，无断链风险。
