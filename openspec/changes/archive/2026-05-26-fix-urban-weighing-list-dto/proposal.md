## Why

Urban 有人值守称重列表当前在 ViewModel / XAML 中直接绑定 `WeighingRecord` 实体，且 `GetPagedWithRecordsAsync` 通过孤立参数传参并在服务内临时挂载 `UrbanExtension` 导航属性——这与已解耦的 Urban 扩展模型冲突，并导致列表绑定脆弱。与此同时，已归档的 **`urban-anomaly-detection`** 已将「正常/异常」Tab 与列表徽章语义改为基于 **`IsAnomaly`（数据质量）**，而非 `SyncStatus.Failed`（上传失败）；本变更在引入 DTO 展示层的同时，必须与该语义对齐，避免 DTO 仍按 `SyncStatus` 过滤或绑定。

## What Changes

- 新增 `UrbanWeighingListItemDto`、`GetUrbanWeighingListInput`；服务返回 `PagedResultDto<UrbanWeighingListItemDto>`，不再向 UI 暴露实体
- **BREAKING**：`IUrbanWeighingExtensionService` 分页 API 改为 `GetPagedListItemsAsync(GetUrbanWeighingListInput)`，移除 `GetPagedWithRecordsAsync` 及 `Record.UrbanExtension = …` 临时赋值
- **对齐 urban-anomaly-detection**：
  - DTO 含 `IsAnomaly`（Tab 过滤与「正常/异常」主徽章）
  - DTO 含 `SyncStatus?`（可选，用于区分/展示上传同步状态，与数据异常分离）
  - 分页查询 Tab：`正常` → `IsAnomaly == false`，`异常` → `IsAnomaly == true`，`全部` → 不过滤 `IsAnomaly`
- `UrbanAttendedWeighingViewModel`：`WeighingRecords` → **`ListItems`**；`ReloadRecordsAsync` 使用 input DTO 并就地更新集合
- `UrbanAttendedWeighingWindow.axaml`：绑定 `ListItems` + DTO `DataTemplate`；徽章基于 `IsAnomaly`（非 `SyncStatus`）；按需展示同步失败状态
- 更新相关单元测试
- **本变更不新增数据库迁移**；依赖 `urban-anomaly-detection` 的 `IsAnomaly` 列——**EF Core 迁移由用户在本机手动生成并应用**，实现阶段不代为执行 `dotnet ef migrations add` / `database update`

## Capabilities

### New Capabilities

- `urban-weighing-list-presentation`: Urban 列表 DTO、入参 DTO、`ListItems` 绑定契约，及与 `IsAnomaly` / `SyncStatus` 的 UI 展示约定

### Modified Capabilities

- `urban-weighing-extension`: 分页列表 API 使用 input/output DTO；Tab 过滤基于 `IsAnomaly`（与 `urban-anomaly-detection` 一致），禁止为 UI 挂载导航属性
- `urban-anomaly-detection`: 列表/UI 路径通过 DTO 暴露 `IsAnomaly` 与 Tab 过滤，不再要求 View 绑定 `UrbanExtension.IsAnomaly` 导航路径（行为不变，消费方式变更）

## Impact

- **子仓库**：`repos/MaterialClient`
  - `MaterialClient.Common`：DTO、`IUrbanWeighingExtensionService` / `UrbanWeighingExtensionService`（Tab 过滤改为 `IsAnomaly`）
  - `MaterialClient.Urban`：`UrbanAttendedWeighingViewModel`、`UrbanAttendedWeighingWindow.axaml` / `.cs`、Converter
  - `MaterialClient.Common.Tests`：查询与 DTO 映射测试
- **依赖**：主 spec `urban-anomaly-detection`（`IsAnomaly` 字段与创建时检测）；实现前须确认实体与 **用户已手动应用的** 迁移已就绪
- **无** UrbanManagement 变更

### 数据库迁移（用户手动）

| 项 | 说明 |
| --- | --- |
| 本 change | 无新迁移；仅代码/DTO/UI |
| 前置 `urban-anomaly-detection` | 用户在本机执行 `dotnet ef migrations add`（如 `AddIsAnomalyToUrbanExtension`）生成脚本，并自行 `database update` 或等价部署流程 |
| 实现约定 | Agent **不**运行 EF 迁移命令；tasks 中仅标注「用户需手动完成」 |

### UI 对齐示意（与 urban-anomaly-detection 一致）

```
Tab [正常]  → 查询 IsAnomaly == false
Tab [异常]  → 查询 IsAnomaly == true
Tab [全部]  → 不过滤 IsAnomaly

列表徽章（主）: IsAnomaly ? 红色「异常」 : 绿色「正常」
（可选）同步失败: SyncStatus == Failed 时另示「同步失败」等，不与 Tab「异常」混用
```
