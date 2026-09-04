## Context

UrbanManagement Blazor 当前以 `Dashboard.razor`（`@page "/"`）为首页，侧栏第一项为「仪表盘」；`ProjectManagement.razor` 在 `/projects`，列表仅支持 `SearchText`，服务端按 `CreationTime` 降序分页。客户端连接状态（在线 / 离线 / 未注册）由页面合并 `GetListAsync` 与 `GetClientListAsync`，使用 `ProjectClientConnectionAggregate` 判定，**不参与**服务端过滤与排序。

本变更仅触及 `repos/UrbanManagement` 的 App 布局/页面与 Core 项目列表查询。

## Goals / Non-Goals

**Goals:**

- `/` 直接进入项目管理；侧栏与「首页」标签不再出现仪表盘。
- 列表可按连接状态过滤：全部 / 在线 / 离线 / 未注册（与现有徽章语义一致）。
- 默认排序：在线 → 离线 → 未注册；过滤与搜索可组合，分页总数正确。
- 称重记录等其它对 `GetListAsync` 的调用在不传状态过滤时行为兼容（仅默认排序变更需评估影响）。

**Non-Goals:**

- 不重做仪表盘统计/ECharts；不迁移仪表盘数据到其它页。
- 不按单台秤/摄像头等设备类型过滤；过滤对象是项目级客户端连接聚合状态。
- 不引入数据库外键；不新增 mapper / 纯映射 DI Service。
- 不改 SignalR 实时刷新协议本身（过滤后刷新仍走现有加载路径即可）。

## Decisions

### 1. 路由：项目管理接管 `/`，保留 `/projects` 别名

- `ProjectManagement.razor` 同时声明 `@page "/"` 与 `@page "/projects"`（或 `/projects` 永久重定向到 `/`）。
- 删除或停用 `Dashboard.razor`（移除 `@page "/"`；文件可删除以免死路由）。
- `AdminLayout` 导航第一项改为「项目管理」且 `Route = "/"`；去掉「仪表盘」项；持久「首页」标签标题改为「项目管理」或保持「首页」但指向 `/` 的项目管理内容。

**备选**：仅 `/` → `/projects` 重定向。弃用原因：侧栏仍会高亮二级路由，首页语义不如直接接管 `/` 清晰。

### 2. 状态过滤与排序下沉到 `GovProjectAppService.GetListAsync`

- 在 `GovProjectListRequestDto` 增加可选字段，例如 `ClientConnectionStatusFilter?`（枚举：`Online` / `Offline` / `Unregistered`；`null` = 全部）。
- `GetListAsync` 在应用 `SearchText` 后：
  1. 读取 `ClientOnlineStatus`（或经既有 `IDeviceStatusService` 查询连接列表），按 `ProId` 聚合为与 UI 相同的三级状态；
  2. 若指定 filter，则只保留匹配状态的项目；
  3. **默认**按状态优先级排序（Online=0, Offline=1, Unregistered=2），同档次要键建议仍用 `CreationTime` 降序以保证稳定；
  4. 再 `Skip`/`Take` 分页。

**备选 A**：仅在 Blazor 端拉全量再过滤排序。弃用原因：破坏现有服务端分页与 `TotalCount`。  
**备选 B**：新建独立 list API。弃用原因：现有 `GetListAsync` 已是项目列表唯一入口，扩展 DTO 即可。

聚合规则必须与 `ProjectClientConnectionAggregate` 一致：无连接行 → 未注册；任一行 `IsConnected` → 在线；否则离线。

### 3. UI 过滤控件

- 在项目管理卡片头搜索区旁增加状态筛选（分段按钮或下拉）：全部 / 在线 / 离线 / 未注册。
- 变更过滤时重置到第 1 页并重新加载；与搜索条件同时传入 DTO。
- 文案使用「在线 / 离线 / 未注册」，与现有客户端列徽章一致（需求口语中的「设备」对应此列，非设备弹窗内单设备类型）。

### 4. 其它调用方兼容

- `WeighingRecord` / `WeighingApproval` 等拉取项目列表时不传 status filter。
- 其结果顺序会变为「按连接状态优先」。若下拉仅需名称且数据量小，可接受；若需按名称稳定排序，可在这些调用显式传 `Sorting` 或后续加参数——本变更默认接受全局默认排序变更，除非实现时发现下拉依赖创建时间（则对这些调用保留 `CreationTime` 排序覆盖）。

### 5. Spec / 能力退役

- `blazor-dashboard`：REMOVED 全部现行首页要求，并注明产品路径不再提供仪表盘页。
- `blazor-admin-layout` / `project-client-merge`：导航与首页场景改为项目管理。

## Risks / Trade-offs

- [列表量大时内存聚合排序] → 当前部署项目量通常有限；若后续增长，再改为 SQL 侧 CASE 排序；仍禁止引擎 FK，可用逻辑 `ProId` join。
- [默认排序影响项目下拉] → 实现时快速核对称重/审批下拉；必要时对这些调用覆盖 Sorting。
- [SignalR 状态变化后当前页空/乱序] → 过滤开启时，连接状态变更后应重新 `LoadDataAsync`（可沿用现有刷新路径），避免当前页无匹配项却仍显示旧行。
- [用户书签 `/` 期望仪表盘] → BREAKING，属本需求意图；无兼容页。

## Migration Plan

1. 合入后重启 UrbanManagement App；访问 `/` 应为项目管理。
2. 确认侧栏无「仪表盘」；`/projects` 仍可用。
3. 验证三种过滤与默认排序；验证未传 filter 的其它页面列表仍可用。
4. 回滚：恢复 `Dashboard.razor` 路由与布局导航，回退 DTO/服务排序逻辑。

## Open Questions

- 无阻塞项。若产品坚持「设备」指弹窗内任一设备 Online，需另开 change；本设计按客户端列三级状态实现。
