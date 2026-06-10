## Context

`UrbanAttendedWeighingViewModel` 当前绑定 `WeighingRecord` 实体；XAML 使用 `UrbanExtension.SyncStatus` 驱动「正常/异常」Tab 与徽章。`IUrbanWeighingExtensionService.GetPagedWithRecordsAsync` 使用多参数入参并在结果上赋值 `Record.UrbanExtension`，与 **解耦后的实体模型**（无 EF 导航）不一致。

已归档变更 **`2026-05-26-urban-anomaly-detection`**（主 spec：`urban-anomaly-detection`）规定：

- `UrbanWeighingExtension.IsAnomaly` 在创建时由 `IUrbanAnomalyDetector` 写入
- 「正常/异常」Tab 过滤与列表主徽章基于 **`IsAnomaly`**，不再用 `SyncStatus.Failed` 表示数据异常
- 数据异常与上传失败为两个关注点

本变更在 DTO 层落实展示契约，并一次性修正列表渲染（`ListItems` + 就地更新集合）。

## Goals / Non-Goals

**Goals:**

- UI 仅绑定 `UrbanWeighingListItemDto`；分页入参为 `GetUrbanWeighingListInput`
- Tab 过滤与服务投影与 **`urban-anomaly-detection`** 一致（`IsAnomaly`）
- DTO 扁平携带 `IsAnomaly`、`SyncStatus?`，支持主徽章 + 可选同步状态展示
- `ListItems` + `ReloadRecordsAsync` 稳定刷新列表

**Non-Goals:**

- 不重复实现 `IUrbanAnomalyDetector` 或 `IsAnomaly` 判定规则（属 `urban-anomaly-detection`）
- 不修改 `appsettings.json` 异常阈值配置
- 不重构 MaterialClient 主程序 AttendedWeighing 列表
- 审批按钮、日期筛选 TextBox 完整绑定可留待后续 change

## Decisions

### 1. 与 urban-anomaly-detection 的分工

| 能力 | 归属 change / spec |
|------|-------------------|
| `IsAnomaly` 实体字段、检测服务、创建时写入 | `urban-anomaly-detection`（已实现/主 spec） |
| 分页查询 Tab 按 `IsAnomaly` 过滤 | **本 change**（`GetPagedListItemsAsync`） |
| 列表 DTO、ViewModel `ListItems`、XAML 绑定 | **本 change** |

### 2. `UrbanWeighingListItemDto` 字段

| 字段 | 用途 |
|------|------|
| `WeighingRecordId` | 选中行、附件查询 |
| `PlateNumber` | 列表列 |
| `AddDate` | 列表列 |
| `TotalWeight` | 列表列 |
| `IsAnomaly` | Tab 过滤语义；主状态徽章（正常/异常） |
| `SyncStatus?` | 无扩展行时为 null；用于可选「同步失败」展示，**不**驱动 Tab「异常」 |

投影示例（服务层 join 后）：

```csharp
new UrbanWeighingListItemDto
{
    WeighingRecordId = r.Id,
    PlateNumber = r.PlateNumber,
    AddDate = r.AddDate,
    TotalWeight = r.TotalWeight,
    IsAnomaly = e?.IsAnomaly ?? false,
    SyncStatus = e?.SyncStatus
};
```

### 3. Tab 过滤（替换 SyncStatus 过滤）

```csharp
joined = input.TabFilter switch
{
    "正常" => joined.Where(x => x.Extension != null && !x.Extension.IsAnomaly),
    "异常" => joined.Where(x => x.Extension != null && x.Extension.IsAnomaly),
    _ => joined  // 全部
};
```

无扩展行的记录在「正常/异常」Tab 下的可见性：与 `urban-anomaly-detection` 一致——仅 `WeighingMode == UrbanMode` 的 Urban 记录在创建时应有扩展；若 join 为空扩展，投影 `IsAnomaly = false` 并仅在「全部」中合理展示（实现时与现有 join 语义保持一致）。

### 4. 服务 API

```csharp
Task<PagedResultDto<UrbanWeighingListItemDto>> GetPagedListItemsAsync(GetUrbanWeighingListInput input);
```

删除 `GetPagedWithRecordsAsync`；禁止 `Record.UrbanExtension = …`。

### 5. ViewModel / XAML

- `ObservableCollection<UrbanWeighingListItemDto> ListItems`
- `SelectedListItem`；照片加载用 `WeighingRecordId`
- XAML：`ItemsSource="{Binding ListItems}"`，`x:DataType` 为 DTO
- 主徽章：`IsAnomaly` → `BoolConverters.Not` 或等价（绿色「正常」/ 红色「异常」）
- 可选：`SyncStatus == Failed` 时显示次要「同步失败」提示（不与 `IsAnomaly` 混为同一 Tab 语义）

### 6. DTO 位置

`MaterialClient.Common/Dtos/Urban/`（服务与测试共用）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| `urban-anomaly-detection` 代码未合并 | 实现前检查 `UrbanWeighingExtension.IsAnomaly`；迁移由用户手动应用后再联调 |
| 旧测试仍断言 `SyncStatus` Tab 过滤 | 更新为 `IsAnomaly` 用例 |
| 双状态 UI 增加 XAML 复杂度 | 主徽章仅 `IsAnomaly`；同步状态为可选次要展示 |

## Migration Plan

### 数据库（用户手动，本 change 不新增迁移）

1. **用户**在 `MaterialClient.Common` 完成 `IsAnomaly` 实体与 `DbContext` 配置后，**手动**执行例如：
   - `dotnet ef migrations add AddIsAnomalyToUrbanExtension --project src/MaterialClient.Common/...`
   - `dotnet ef database update`（或部署环境等价步骤）
2. 实现与联调前确认数据库已包含 `IsAnomaly` 列及索引；Agent **不**代为执行上述命令。

### 应用代码（本 change）

1. 新增 DTO + 替换分页 API + Tab 过滤改为 `IsAnomaly`
2. ViewModel / XAML / Converter
3. 测试 + 手动验证 Tab（正常/异常/全部）与列表刷新

## Open Questions

- 无
