## Why

`UrbanManagement.Admin` 当前基于 Blazor Server + 手写 Layui CSS（约 2,000 行样式、无组件库），存在多项结构性痛点：无原生表格列宽拖拽与吸顶滚动容器、手写项目搜索弹层截断长项目名、侧栏将城管与资源化平铺混排、设备详情弹窗包含不用于现场处置的地磅/摄像头信息、授权过期时间冗余展示时分秒、且与同仓 `UrbanManagement.Recycle`（Vue 3 + Element Plus）形成双前端栈分裂。

本变更为 Admin 迁移至 Vue 3 + Element Plus 三阶段路线的 Stage 1，建立全新工业运维工作台底座、后端多工控机与抓拍机聚合契约及 BFF 代理，并落地城管项目与资源化项目页面（同时保留旧 Blazor 兜底运行直至 Stage 3 统一下线）。

## What Changes

- **新建 Vue 3 + Element Plus 前端底座**：在 `repos/UrbanManagement/src/UrbanManagement.Admin/client/` 建立 Vite + Vue 3 + TypeScript + Element Plus 工程，构建输出至 `wwwroot/v2/`（Stage 1–2 期间挂载在 `/v2/` 与现有 Blazor 并存零中断，Stage 3 切换根路径并下线 Blazor）。
- **推倒重做布局壳与 3 组 Root Nav**：采用「工控运维管理平台」可折叠深色侧栏（**城管 5001 / 资源化 5020 / 工控机运维** 3 组顶层导航）+ 简洁顶栏 + 全屏三段式工作台，移除旧假多标签栏及 `/recycle/device-status` 空壳。
- **建立全站核心复用组件**：`OpsDataTable`（吸顶滚动容器 + 全表头手动拖拽调宽 + `localStorage` 列宽记忆与重置）、`ProjectRemoteSelect`（宽弹层多行完整展示长项目全称）。
- **落地城管项目与资源化项目页（落实 R2/R4/R5/R6/R7 及多工控机冗余）**：
  - 缩窄「项目地址」默认列宽（R4）、「客户端」文案改为「工控机」（R5）、移除「设备」操作按钮与弹窗并将「抓拍机」状态直出表格并丢弃地磅/摄像头 UI（R6）、授权过期时间改为 `yyyy-MM-dd`（R7）；
  - 支持 1 项目 / 1 接入码挂多台工控机：主行展示聚合计数徽标（如 `在线 2/2` / `异常 1/2`），点击展开箭头显示工控机子表（逐台展示工控机状态、抓拍机状态、版本、最后在线时间及单机日志/更新入口）。
- **补齐后端最小契约（单仓 `UrbanManagement`）**：
  - 扩展项目列表聚合接口（`GET /api/admin/projects/status-summary`），一次性聚合返回每个项目的工控机汇总、抓拍机（LPR）汇总与 `Ipcs[]` 明细数组；
  - 新增受 `UrbanAdmin.Session` Cookie 鉴权的 Admin BFF 端点：`GET /api/session`、`/api/admin/client-logs/*`、`/api/admin/client-ota/*`。

## Capabilities

### New Capabilities

- `admin-vue-workspace`: Vue 3 + Element Plus 新版 Admin 工作台底座、3 组 Root Nav、可调宽滚动表格、长项目名搜索组件、城管/资源化项目管理（含多工控机展开子表与抓拍机直出状态）以及 Admin BFF 鉴权端点。

### Modified Capabilities

## Impact

- 影响子仓库：`repos/UrbanManagement`（`UrbanManagement.Admin`、`UrbanManagement.Core` 单元测试）。
- 不修改数据库表结构，不破坏既有 Blazor Server 路由与 `/api/app/*` 契约，Stage 1–2 期间旧版 Blazor 继续可用。
