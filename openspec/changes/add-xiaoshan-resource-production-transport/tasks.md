## 1. Mock API

- [x] 1.1 在 `ResourceMockStore` 增加生产管理与运输清单种子及列表读取；批量上报 / 刷新上报只改进程内状态与发送时间
- [x] 1.2 在 `ResourceMockEndpoints` 增加 `/api/productions`、`/api/transports`（GET 列表；POST 批量上报；生产行可选单条刷新上报）

## 2. Vue 外壳与路由

- [x] 2.1 `router.ts` 增加 `/productions`、`/transports`；`Shell.vue` 侧栏与页签标题映射扩展为四页
- [x] 2.2 新增 `views/Productions.vue`：筛选、表格列、合计、分页、批量上报、刷新上报，数据来自本站 API
- [x] 2.3 新增 `views/Transports.vue`：筛选、表格列（含净重与出货/收货凭证查看）、合计、分页、批量上报，数据来自本站 API
- [x] 2.4 构建 Vue 并输出到 `wwwroot`，确认登录后可打开两页且未登录仍进登录页

## 3. 验证

- [x] 3.1 本地打开生产管理与运输清单，核对筛选/分页/合计/批量上报不外呼
- [x] 3.2 运行 `openspec validate add-xiaoshan-resource-production-transport --strict`
