# Material Provider Sync

## MODIFIED Requirements

### Requirement: 同步服务用服务端返回的实体替换本地 Provider 实体
所有 Provider 推送完成后，服务 SHALL 删除所有本地 Provider 实体，并使用 `MaterialProviderListResultDto.ToEntity()` 插入新实体，保留服务端分配的 `ProviderId` 作为主键。因 `Address` 为本地专用字段（远端 DTO 不携带），服务 SHALL 在删表重建前按 `ProviderId` 快照本地 `Address`，重建后回填，SHALL NOT 丢失已录入的 `Address`。

#### Scenario: Provider 实体被服务端数据替换
- **WHEN** 服务端已返回所有本地 Provider 的 `MaterialProviderListResultDto` 响应
- **THEN** 本地 `Providers` DbSet 被清空，并通过 `ToEntity()` 转换重新填充，每个实体的 `Id` 等于服务端的 `ProviderId`

#### Scenario: 重建后保留本地 Address
- **WHEN** 本地 Provider（Id=200）已录入 `Address="杭州市西湖区某路 1 号"`，随后执行一次性同步重建
- **THEN** 重建后 Id=200 的 Provider `Address` SHALL 仍为 `"杭州市西湖区某路 1 号"`
- **AND** SHALL NOT 被远端 DTO 的空值覆盖为 null

## ADDED Requirements

### Requirement: Provider 本地 Address 字段
`Provider` 实体 SHALL 新增可空 `Address` 列（string?），作为 §2.2 `consigneeAddress` 的数据源。`Address` SHALL 为本地专用字段，SHALL NOT 进入远端 `CreateProviderInput`/`UpdateProviderInput`/`MaterialProviderListResultDto` 契约。

#### Scenario: Address 列可空
- **WHEN** 非 Recycle 场景创建 Provider
- **THEN** `Address` SHALL 允许为 null
- **AND** 数据库列 SHALL 为 nullable

#### Scenario: Recycle 内联新建供应商校验 Address 必填
- **WHEN** 在 Recycle 称重详情通过选择器内联新建供应商（`CreateNewProviderAsync`）
- **THEN** 表单 SHALL 校验 `Address` 必填
- **AND** 缺失时 SHALL 阻止创建并提示

#### Scenario: 远端创建后回填本地 Address
- **WHEN** `ProviderService.CreateProviderAsync` 携带 `Address` 调用
- **THEN** SHALL 先调用远端 `CreateProvider`（不传 Address）
- **AND** SHALL 在本地 upsert 前将 `Address` 写入返回的 Provider 实体

#### Scenario: ProviderDto 与分页查询携带 Address
- **WHEN** `ProviderService.GetPagedProvidersAsync` 执行分页投影
- **THEN** `ProviderDto` SHALL 携带 `Address`
- **AND** 选择器与管理页 SHALL 能读取该值

#### Scenario: Provider 管理页展示与编辑 Address
- **WHEN** 打开 `ProviderEditWindow`/`ProviderManagementWindow`
- **THEN** SHALL 展示 `Address` 字段
- **AND** SHALL 允许编辑（编辑结果落本地；是否同步远端遵循既有 `UpdateProvider` 约定，远端契约不新增 Address）
