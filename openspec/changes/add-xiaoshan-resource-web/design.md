## Context

城管管理端是 Blazor Server，Cookie 为 `UrbanAdmin.Session`，产品编码来自 `AdminSso:WebProductCode`（已用 5040）。网关把 `/_blazor/**`、`/api/**` 和其余路径兜底到 `um-admin`。`UrbanManagement.Hosting` 会带上 Core、数据库和全站 `appsettings`。

萧山资源化利用网页端是另一个站点。调研见 [`docs/2026-11-13-xiaoshan-resource-utilization/`](../../../docs/2026-11-13-xiaoshan-resource-utilization/00-调研总览.md)。用户已确认工程名 `UrbanManagement.XiaoShanResource`、产品编码 5041、产品名称「萧山资源化利用网页端」，以及业务页使用 Vue 3 + Element Plus。

## Goals / Non-Goals

**Goals:**

- 独立进程提供登录页和三块 Vue 画面。
- 登录协议与城管管理端相同，产品编码固定为配置中的 5041，Cookie 名为 `XiaoShanResource.Session`。
- 车辆管理、合同管理、新建合同对话框按参考图还原布局，数据只在浏览器内存中。

**Non-Goals:**

- 不建业务表，不把 mock 放进 Core，不把 PDF 送到 Attachment。
- 不改网关路由、城管管理端、MaterialClient、FdSoft.SSO。不把本站接进现有服务的数据库或共享 `appsettings.Production.json`。
- 不实现参考图里未打开的菜单页面。
- 不解析批量导入文件，不上报合同。

## Decisions

### 独立 Web 项目，不引用 Hosting

`UrbanManagement.XiaoShanResource` 使用 `Microsoft.NET.Sdk.Web`，不导入 `UrbanService.props`。这样不会引用 Admin，也不会启动 UrbanManagement 数据库。SSO 登录类型复制在本项目内，不抽到 Core。备选是把登录客户端下沉到 Core 并让两个站点共用；那会改城管管理端的引用，本变更不做。

### Vue 3 + Element Plus 只负责登录后的页面

登录页是 Razor Page `/login`。Vue 用 Vite 构建到该项目的 `wwwroot`。筛选、表格、分页、标签、按钮、对话框和上传使用 Element Plus。顶栏背景按参考图使用紫色，顶栏和浏览器标题使用「萧山资源化利用网页端」。登录页标题使用同一名称。备选是业务页也用 Blazor；现有管理端皮肤与参考图不是同一套组件，还原度不够。

### 会话与静态页的边界

未登录访问页面时重定向到 `/login`。`/health/live` 与 `/health/ready` 匿名，且不检查数据库。`POST /logout` 删除本站 Cookie 并回到登录页。`GET /api/session` 只返回当前 Cookie 里的用户名，供顶栏显示。车辆和合同由本站已登录 API 提供，例如 `GET /api/vehicles` 与 `GET /api/contracts`，写入使用同一组资源上的创建、更新和删除。这些 API 不进入 `UrbanManagement.Core`，也不注册成 AppService。

### 页签由前端状态维护

登录后打开车辆管理，页签栏只有「车辆管理」。从菜单打开合同管理后才出现「合同管理」。关闭页签即去掉该标签。新建合同是合同页上的 `ElDialog`，没有路由。

### mock 行为

种子数据放在 `UrbanManagement.XiaoShanResource` 进程里。Vue 打开页面时从本站 API 取列表。搜索和分页在取回的结果上完成，也可以由 API 接受查询参数。录入、编辑、删除和保存调用本站 API，改的是同一份进程内 mock。刷新页面后再次从 API 获取，因此能看到本次进程里保存过的修改；进程重启后回到种子。批量导入按钮不读取文件。批量上报不调用城管或外部系统，已勾选行的上报状态保持「已发送」。PDF 只在请求里带文件名，限制 `.pdf` 且不超过 20MB，不写入 Attachment。

## Risks / Trade-offs

- [5041 尚未在 FD_Base 核验] → 本变更不写产品数据。SSO 拒绝时登录页显示失败，不建会话。补产品数据另案处理。
- [登录客户端与 Admin 各有一份] → 本变更不改 Admin。以后若两处协议分叉，再单独抽出共享类型。
- [参考图没有色值和完整合同列] → 使用 Element Plus 默认控件密度，顶栏用紫色。被截断的合同字段只保留图上可见文字。
- [同机部署 Cookie 不区分端口] → Cookie 名使用 `XiaoShanResource.Session`，不复用 `UrbanAdmin.Session`。

## Migration Plan

本地先在 `client/` 执行 `npm run build`，再发布 `UrbanManagement.XiaoShanResource`。138 与现有栈同一次 `docker compose up`：构建参数 `SERVICE=XiaoShanResource`，镜像名 `urbanmanagement-xiaoshanresource`，标签仍是 `UM_TAG`。容器不依赖 `um-migrator`，不挂载共享的 `appsettings.Production.json`。`AdminSso__BaseUrl` 使用已有的 `UM_ADMIN_SSO_BASE_URL`，`AdminSso__WebProductCode` 固定为 `5041`。宿主端口是 `UM_XIAOSHAN_PUBLIC_PORT`，默认 5334，映射容器 8080。网关的 5333 仍然只到城管管理端。回退时停掉 `um-xiaoshanresource` 并删除该项目即可，不迁移数据。

## Open Questions

无。顶栏文案按参考图，登录页文案按产品名称。
