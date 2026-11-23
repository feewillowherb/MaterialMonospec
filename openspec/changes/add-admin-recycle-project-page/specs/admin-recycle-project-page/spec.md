## ADDED Requirements

### Requirement: Admin 独立展示 5020 项目

Admin SHALL 提供独立于城管项目页的页面，且该页面只列出 ProductCode 为 5020 的项目。页面 SHALL 提供与城管项目页相同的名称与对接码搜索、客户端在线状态筛选、同步开关和设备详情。该页面 SHALL NOT 提供进入城管称重页的操作。城管项目页标题 SHALL 为「城管项目」，并且只列出 ProductCode 5001 以及历史 ProductCode 0 的项目。未指定产品的其他项目查询 SHALL 继续同时返回 5001 与 5020。

#### Scenario: 只列出资源化项目

- **WHEN** 操作员打开资源化项目页，且本地同时存在 5001 与 5020 项目
- **THEN** 页面只展示 ProductCode 5020 的项目
- **AND** 5001 项目不出现在该页

#### Scenario: 不进入城管称重

- **WHEN** 操作员在资源化项目页查看某一 5020 项目
- **THEN** 该行不提供城管称重入口

#### Scenario: 城管项目页只列出 5001

- **WHEN** 操作员打开城管项目页，且本地同时存在 5001、历史 ProductCode 0 与 5020 项目
- **THEN** 页面标题为「城管项目」
- **AND** 列表包含 5001 与历史 ProductCode 0 的项目
- **AND** 5020 项目不出现在该页
