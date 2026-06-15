## Why

`EditHistoryJson` 作为专用 JSON 字段存储在 `UrbanWeighingRecord`（UrbanManagement）和 `UrbanWeighingExtension`（MaterialClient）的实体中，增加了 schema 复杂度且不符合 ABP 框架通过 `IHasExtraProperties` 动态扩展属性的惯例模式。项目中 `WeighingRecord`、`Waybill` 等实体已广泛采用 `IHasExtraProperties`，将编辑历史数据统一到 `ExtraProperties` 字典可降低维护成本并保持架构一致性。

## What Changes

- **移除** `UrbanWeighingRecord.EditHistoryJson` 字段（UrbanManagement），改为通过 `IHasExtraProperties.ExtraProperties` 存储
- **移除** `UrbanWeighingExtension.EditHistoryJson` 字段（MaterialClient），改为通过 `IHasExtraProperties.ExtraProperties` 存储
- **移除** `UrbanWeighingExtension.EditHistory` `[NotMapped]` 计算属性，改用 `ExtraProperties` 上的辅助方法访问
- **重构** `EditEntry` 模型：从增量字段模式（Field/OldValue/NewValue）改为完整快照模式，每条记录包含修改时间、车牌号、重量、异常原因四个字段
- **移除** `UrbanWeighingRecordReceiveInputDto.EditHistoryJson` 属性和 `UrbanWeighingRecordOutputDto.EditHistoryJson` 属性，改为通过 `ExtraProperties` 传递
- **移除** `UrbanWeighingRecordSubmitDto.EditHistoryJson` 属性（MaterialClient），改用 `ExtraProperties` 传递
- **新增** 数据库迁移：UrbanManagement 删除 `EditHistoryJson` 列；MaterialClient 删除 `EditHistoryJson` 列
- **更新** `UrbanWeighingRecordAppService.ApproveAsync` 中对 `EditHistoryJson` 的读写逻辑，改为读写 `ExtraProperties`
- **更新** `UrbanServerUploadService.SubmitRecordAsync` 中 DTO 映射逻辑
- **更新** `WeighingApproval.razor` 中编辑历史时间线的反序列化逻辑
- **BREAKING**: API DTO 结构变更（`EditHistoryJson` 属性移除，数据移至 `extraProperties` 字典）

## Capabilities

### New Capabilities
_(无新增能力)_

### Modified Capabilities
- `urban-weighing-extension`: `UrbanWeighingExtension` 实体移除 `EditHistoryJson` 字段，改用 `IHasExtraProperties`；新增 `EditHistoryJson` 读取/写入辅助方法通过 `ExtraProperties` 操作
- `urban-weighing-record-reception`: `UrbanWeighingRecord` 实体和 DTO 移除 `EditHistoryJson` 字段，改用 `IHasExtraProperties`；接收 API 的 `EditHistoryJson` 属性移除，编辑历史数据通过 `extraProperties` 字典传递
- `urbanmanagement-weighing-record-approval`: 审批服务中 `EditHistoryJson` 读写逻辑改为通过 `ExtraProperties` 操作；输出 DTO 通过 `ExtraProperties` 暴露编辑历史

## Impact

### UrbanManagement (`repos/UrbanManagement`)

| File | Change |
|------|--------|
| `Core/Entities/UrbanWeighingRecord.cs` | 移除 `EditHistoryJson` 属性，实现 `IHasExtraProperties` |
| `Core/Models/UrbanWeighingRecordDtos.cs` | `ReceiveInputDto` 移除 `EditHistoryJson` 属性，从 `ExtraProperties` 读取 |
| `Core/Models/UrbanWeighingRecordOutputDto.cs` | 移除 `EditHistoryJson` 属性，从 `ExtraProperties` 读取 |
| `Core/Services/UrbanWeighingRecordAppService.cs` | `ApproveAsync` / `ReceiveAsync` 改用 `ExtraProperties` 读写编辑历史 |
| `Core/EntityFrameworkCore/UrbanManagementDbContext.cs` | 移除 `EditHistoryJson` 列配置，配置 `ExtraProperties` JSON 列 |
| `App/Pages/WeighingApproval.razor` | 从 `ExtraProperties` 反序列化编辑历史 |
| EF Core Migration | 新增迁移删除 `EditHistoryJson` 列，新增 `ExtraProperties` 列 |

### MaterialClient (`repos/MaterialClient`)

| File | Change |
|------|--------|
| `Common/Entities/Urban/UrbanWeighingExtension.cs` | 移除 `EditHistoryJson` 属性和 `EditHistory` 计算属性，实现 `IHasExtraProperties` |
| `Common/Entities/Urban/EditEntry.cs` | 重构为快照模型：字段改为 ChangedAt、PlateNumber、TotalWeight、AnomalyReason；移除 Field/OldValue/NewValue |
| `Common/EntityFrameworkCore/MaterialClientDbContext.cs` | 移除 `EditHistoryJson` 列配置，配置 `ExtraProperties` JSON 列 |
| `Common/Services/Urban/IUrbanWeighingExtensionService.cs` | `AppendEditEntryAsync` 方法签名更新：接收完整快照（PlateNumber、TotalWeight、AnomalyReason），内部改为操作 `ExtraProperties` |
| `Urban/Services/UrbanServerUploadService.cs` | DTO 映射从 `EditHistory` 改为 `ExtraProperties` |
| `Urban/Dtos/UrbanWeighingRecordSubmitDto.cs` | 移除 `EditHistoryJson` 属性，新增 `ExtraProperties` 或 `Dictionary<string, object>` |
| EF Core Migration | 新增迁移删除 `EditHistoryJson` 列，新增 `ExtraProperties` 列 |
