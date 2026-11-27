## Why

Admin 的称重记录、异常审批、卡口进出与成品进出 4 个高频核查页面仍运行在旧 Blazor Server 壳中：查看照片必须逐条点开弹窗、卡口与成品进出缺乏筛选和分页且硬编码 `min-width: 1400px` 触发横向滚动、项目搜索框截断长项目名称。

本变更为 Admin 迁 Vue 3 + Element Plus 三阶段路线的 Stage 2，补齐轻量图片 URL 懒加载端点（API-1）并将上述 4 个核查页面迁移至 Vue 3 工作台，落实 R1（行内 2 张照片 + 点击灯箱放大，移除查看照片按钮）、R2（全表滚动与表头调宽）和 R3（宽弹层长项目名搜索）。

## What Changes

- **后端轻量图片预览契约（API-1）**：
  - `UrbanWeighingRecordOutputDto` 与 `UrbanPassageListItemDto` 新增 `PreviewPhotos` 字段（最多 2 张槽位，含 `AttachmentId`、`Label`、`Url`），由列表查询一次批量查表填充，避免 N+1 请求与超大 Base64 响应；
  - `UrbanManagement.Admin` 新增受 Cookie 鉴权的 `GET /api/admin/attachments/{id:guid}` 图片输出端点，附带 `Cache-Control: private, max-age=3600`；
  - `UrbanPassageListInputDto` 与卡口/成品查询服务补齐 `ProName` 与 `SyncType` 筛选支持。
- **前端复用核查组件**：
  - 新增 `InlinePhotoPair.vue`（单列并排 2 张 `72×48px` `el-image` 懒加载缩略图 + 缺图占位 + 点击全屏灯箱放大切换）；
  - 新增 `DateRangeShortcuts.vue`（今日 / 近 3 天 / 近 7 天 / 本月 + 自定义区间）；
  - 新增 `EditHistoryDialog.vue`（修改历史时间线弹窗）。
- **迁移 4 个核心业务页至 Vue 3**：
  - `WeighingRecordView.vue`（`/urban/weighing`）：车牌 + 重量 + 现场照片（2 图）同屏扫读带，移除「查看照片」按钮，补齐日期快捷切换、空态引导、修改历史与重置同步；
  - `WeighingApprovalView.vue`（`/urban/weighing-approval`）：同构核查列 + 行内 2 图，移除「查看照片」按钮，保留审批弹窗（修正车牌/重量 + 照片核对与原生 `<input type="file">` 替换上传）；
  - `PassageListView.vue`（共享组件服务 `/urban/checkpoint-passage` 与 `/urban/finished-product-passage`）：消除两页重复代码，补齐项目/车牌/日期/同步状态筛选与分页，行内展示 2 图，移除「查看照片」按钮与 `1400px` 硬滚。

## Capabilities

### New Capabilities

### Modified Capabilities

- `admin-vue-workspace`: 扩展 Vue 3 Admin 工作台，增加行内双图预览组件、称重记录、异常审批、卡口进出与成品进出页面，以及鉴权附件图片端点。

## Impact

- 影响子仓库：`repos/UrbanManagement`（`UrbanManagement.Core`、`UrbanManagement.Admin`）。
- 兼容既有 Blazor 路由与 `/api/app/*` 字段，无数据库结构变更。
