## ADDED Requirements

### Requirement: 软删主数据选型排除
系统 SHALL 在材料与供应商的选型列表、分页选择及新建/改单可选集合中排除 `IsDeleted == true` 的 `Material` 与 `Provider`。

#### Scenario: 选型列表不含软删材料
- **WHEN** 用户打开材料选择列表或分页选材
- **THEN** 结果集 SHALL NOT 包含 `IsDeleted == true` 的 Material

#### Scenario: 选型列表不含软删供应商
- **WHEN** 用户打开供应商选择列表或分页选供应商
- **THEN** 结果集 SHALL NOT 包含 `IsDeleted == true` 的 Provider

#### Scenario: 提交已软删主数据 Id 被拒绝
- **WHEN** 新建或改单请求携带的 `MaterialId` 或 `ProviderId` 对应实体存在且 `IsDeleted == true`
- **THEN** 系统 SHALL 拒绝该写入并返回明确错误
- **AND** SHALL NOT 以空名称静默落单

### Requirement: 软删主数据查询展示包含
系统 SHALL 在运单/称重列表展示、导出映射、以及按主数据名称筛选历史运单时，按 Id 解析 `Material` / `Provider`（及展示所需 `MaterialUnit`）名称时包含软删除行（`IsDeleted == true` 且行仍存在）。

#### Scenario: 列表按 Id 填出软删材料名
- **WHEN** 活跃运单的 `MaterialId` 指向 `IsDeleted == true` 的 Material，且该行仍在库中
- **THEN** 列表/详情 DTO 的材料名称字段 SHALL 为该 Material 的 `Name`
- **AND** SHALL NOT 因软删过滤而输出空字符串

#### Scenario: 列表按 Id 填出软删供应商名
- **WHEN** 活跃运单的 `ProviderId` 指向 `IsDeleted == true` 的 Provider，且该行仍在库中
- **THEN** 展示用的供应商名称 SHALL 为该 Provider 的 `ProviderName`

#### Scenario: 按软删材料名仍能筛到历史运单
- **WHEN** 用户按货名/材料名筛选，且匹配名称仅存在于已软删 Material
- **THEN** 系统 SHALL 仍返回 `MaterialId` 指向这些 Material 的历史运单

#### Scenario: 硬缺失与软删区分
- **WHEN** 运单的 `MaterialId` 或 `ProviderId` 在对应表中不存在任何行
- **THEN** 对应名称字段 SHALL 输出空字符串且不抛异常
- **AND** 该行为 SHALL NOT 适用于「行存在但 `IsDeleted == true`」的情况
