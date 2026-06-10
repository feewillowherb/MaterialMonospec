## MODIFIED Requirements

### Requirement: UI 标签页基于 IsAnomaly 过滤

系统 SHALL 将「正常/异常」标签页的过滤逻辑基于 `UrbanWeighingExtension.IsAnomaly`（或等价的列表项 DTO 字段 `IsAnomaly`），不得基于 `SyncStatus.Failed`。

#### Scenario: 正常标签页过滤
- **WHEN** 用户点击「正常」标签页
- **THEN** 查询 MUST 过滤 `IsAnomaly == false`（在领域服务 join 上过滤，或在 DTO 投影前过滤）
- **AND** MUST 仅显示 `WeighingMode == UrbanMode` 的记录

#### Scenario: 异常标签页过滤
- **WHEN** 用户点击「异常」标签页
- **THEN** 查询 MUST 过滤 `IsAnomaly == true`
- **AND** MUST 仅显示 `WeighingMode == UrbanMode` 的记录

#### Scenario: 全部标签页
- **WHEN** 用户点击「全部记录」标签页
- **THEN** 查询 MUST 显示所有 `WeighingMode == UrbanMode` 的记录
- **AND** MUST NOT 过滤 `IsAnomaly` 字段

### Requirement: UI 状态徽章区分异常和同步状态

系统 SHALL 在记录列表中通过列表项 DTO 展示数据异常状态；主徽章 MUST 绑定 DTO 的 `IsAnomaly`，不得要求 UI 绑定 `UrbanExtension` 导航属性。

#### Scenario: 数据异常徽章显示
- **WHEN** 列表项 DTO 的 `IsAnomaly == true`
- **THEN** MUST 显示红色「异常」徽章
- **AND** 徽章前景色 MUST 为 "#DC2626"

#### Scenario: 正常数据徽章显示
- **WHEN** 列表项 DTO 的 `IsAnomaly == false`
- **THEN** MUST 显示绿色「正常」徽章
- **AND** 徽章前景色 MUST 为 "#15803D"

#### Scenario: 同步状态与数据异常分离
- **WHEN** 列表项 DTO 的 `SyncStatus == Failed` 且 `IsAnomaly == false`
- **THEN** 主徽章 MUST 仍显示「正常」（数据质量正常）
- **AND** UI MAY 另行展示同步失败提示，且 MUST NOT 将该行归入「异常」Tab 的 `IsAnomaly` 过滤结果
