## Why

Admin 的项目管理页把 5001 与 5020 混在同一列表里，没有只展示资源化（5020）项目的入口。操作员需要一个与现有项目页同构、但只列出 5020 的独立页面。

## What Changes

- Admin 增加独立的资源化项目页，只查询并展示 ProductCode 5020 的项目。
- 该页沿用现有项目页的搜索、客户端状态、同步开关和设备详情，不提供城管称重入口。
- 现有 5001 项目页标题为「城管项目」，只列出 5001。资源化项目页只列出 5020。

## Capabilities

### New Capabilities

- `admin-recycle-project-page`: Admin 独立展示 5020 项目的页面。

### Modified Capabilities

## Impact

UrbanManagement Admin 导航与项目列表查询。不改 Recycle Web、目录拉取或项目绑定。
