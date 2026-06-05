## MODIFIED Requirements

### Requirement: Blazor 全局 Using 指令

UrbanManagement MUST 包含 `_Imports.razor` 文件定义 Blazor 组件的全局命名空间，MUST 包含按职责划分后的 Models 子目录命名空间。

#### Scenario: 全局 Using 内容

- **WHEN** 任何 Blazor 组件编译
- **THEN** `_Imports.razor` MUST 包含 `@using Microsoft.AspNetCore.Components.Routing` 和 `@using UrbanManagement.App.Pages` 命名空间
- **AND** MUST 包含 `@using UrbanManagement.Core.Models`（保持不变，所有模型文件保持同一命名空间）

## ADDED Requirements

### Requirement: Models 目录按职责划分子目录

`UrbanManagement.Core/Models/` 目录 MUST 按职责划分为 `Cache/`、`Dtos/`、`Messages/` 三个子目录，所有文件保持 `UrbanManagement.Core.Models` 命名空间不变。

#### Scenario: Cache 子目录内容

- **WHEN** 检查 `Models/Cache/` 目录
- **THEN** MUST 包含 `DeviceStatusCacheItem.cs`、`ClientRegistryCacheItem.cs`、`ClientConnectionCacheItem.cs`、`ConnectionRegistryCacheItem.cs`
- **AND** 所有文件 MUST 使用 `UrbanManagement.Core.Models` 命名空间

#### Scenario: Dtos 子目录内容

- **WHEN** 检查 `Models/Dtos/` 目录
- **THEN** MUST 包含所有 DTO 文件（ClientConnectionDto、ClientDeviceSummaryDto、DeviceStatusQueryDto、DeviceStatusListRequestDto、ClientListRequestDto、GovProjectDto、GovProjectCreateDto、GovProjectUpdateDto、GovProjectListRequestDto、GovLogDto、GovSyncDataDto、GovSyncDataQueryDtos、LegacyGovSyncDtos、LegacyGovSyncResult、PagedResult、SetSyncStatusDto、UrbanAttachmentUploadDtos、UrbanWeighingRecordDtos、UrbanWeighingRecordOutputDto）
- **AND** 所有文件 MUST 使用 `UrbanManagement.Core.Models` 命名空间

#### Scenario: Messages 子目录内容

- **WHEN** 检查 `Models/Messages/` 目录
- **THEN** MUST 包含 `DeviceStatusMessage.cs`
- **AND** 文件 MUST 使用 `UrbanManagement.Core.Models` 命名空间

#### Scenario: Models 根目录无残留模型文件

- **WHEN** 检查 `Models/` 根目录（不含子目录）
- **THEN** MUST NOT 包含任何 CacheItem、DTO 或 Message 类文件
- **AND** 所有模型文件 MUST 仅存在于对应的子目录中

#### Scenario: 命名空间保持一致

- **WHEN** 任何文件从 Models/ 根目录迁移至子目录
- **THEN** 其命名空间 MUST 保持 `UrbanManagement.Core.Models` 不变
- **AND** 所有引用该类型的文件 MUST 无需修改 using 语句
