## 1. 首页路由与布局

- [ ] 1.1 将 `ProjectManagement.razor` 设为 `@page "/"`，并保留 `@page "/projects"`（或等价重定向）
- [ ] 1.2 移除/停用 `Dashboard.razor`（去掉 `/` 路由，删除或清空页面以免残留入口）
- [ ] 1.3 更新 `AdminLayout.razor`：侧栏去掉「仪表盘」，「项目管理」指向 `/`；首页持久标签与导航激活逻辑对齐

## 2. 列表查询：状态过滤与默认排序

- [ ] 2.1 扩展 `GovProjectListRequestDto`：可选客户端连接状态过滤（Online / Offline / Unregistered / null=全部）；禁止使用 tuple
- [ ] 2.2 在 `GovProjectAppService.GetListAsync` 中按 `ProjectClientConnectionAggregate` 语义聚合 `ClientOnlineStatus`，应用过滤，默认排序在线→离线→未注册（同档次要键稳定），再分页；不引入引擎 FK / mapper DI
- [ ] 2.3 核对称重记录/审批等其它 `GetListAsync` 调用：不传 filter 时可用；若下拉依赖旧排序则对这些调用覆盖 Sorting

## 3. 项目管理 UI

- [ ] 3.1 在 `ProjectManagement.razor` 搜索区增加状态筛选控件（全部 / 在线 / 离线 / 未注册）
- [ ] 3.2 加载、搜索、翻页、SignalR/轮询刷新路径均传入当前 filter；变更 filter 时重置到第 1 页并刷新 `TotalCount`

## 4. 验证

- [ ] 4.1 手动验证：`/` 为项目管理；侧栏无仪表盘；三种过滤与默认排序正确；`/projects` 仍可用
- [ ] 4.2 确认其它页面项目列表在无 filter 时仍正常
