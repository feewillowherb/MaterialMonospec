## Why

运营人员打开 UrbanManagement 后首先看到的是无业务价值的仪表盘占位页，真正高频使用的项目管理被挤到二级入口；项目列表也无法按客户端在线状态筛选，且默认按创建时间排序，难以优先处理在线/离线设备。需要把首页改为项目管理，并按在线状态过滤与默认排序。

## What Changes

- 移除仪表盘页面与侧栏「仪表盘」入口；应用首页（`/`）改为项目管理。
- **BREAKING**：原 `/` 仪表盘路由与侧栏首页语义变更；访问 `/` 展示项目管理而非统计卡片/图表。
- 项目管理列表新增客户端连接状态过滤：在线、离线、未注册（可与「全部」切换；与现有搜索可组合）。
- 项目管理默认排序改为：在线优先，其次离线，再次未注册；同档内保持稳定次要排序。
- 同步更新布局「首页」标签与导航激活逻辑，使其指向项目管理首页。

## Capabilities

### New Capabilities

- （无）

### Modified Capabilities

- `blazor-dashboard`：移除仪表盘作为首页/可用页面的要求（退役该能力在产品路径上的生效）。
- `blazor-project-management`：首页路由、状态过滤、默认排序要求。
- `blazor-admin-layout`：侧栏与首页标签改为项目管理，去掉仪表盘导航项。
- `project-client-merge`：侧栏三项导航中的「仪表盘」改为项目管理作为首页；过滤语义与现有在线/离线/未注册徽章一致。

## Impact

- **仓库**：`repos/UrbanManagement`（仅 App/Core Blazor 与列表查询）。
- **页面**：`Pages/Dashboard.razor`（移除或停用）、`Pages/ProjectManagement.razor`（路由、过滤 UI、加载参数）、`Pages/AdminLayout.razor`（导航与首页标签）。
- **服务/DTO**：`GovProjectListRequestDto`、`GovProjectAppService.GetListAsync`（状态过滤与排序；需结合 `ClientOnlineStatus` / 既有聚合语义）；其它调用方（称重记录/审批里的项目下拉）须保持兼容（默认不过滤、不破坏分页）。
- **规范**：上述四个现有 capabilities 的 delta；不新增跨仓依赖。
