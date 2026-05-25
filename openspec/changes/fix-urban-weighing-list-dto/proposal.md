## Why

Urban 有人值守称重列表当前在 ViewModel / XAML 中直接绑定 `WeighingRecord` 实体，且 `GetPagedWithRecordsAsync` 通过孤立参数传参并在服务内临时挂载 `UrbanExtension` 导航属性——这与已解耦的 Urban 扩展模型（无 EF 导航）冲突，并导致列表绑定脆弱（`WeighingRecords` 与 `ItemsControl` 不同步、实体不适合 UI 层）。需要以 DTO 明确展示层契约，修复列表渲染并统一查询入参。

## What Changes

- 新增 Urban 称重列表项 DTO（如 `UrbanWeighingListItemDto`）及分页查询入参 DTO（如 `GetUrbanWeighingListInput`），服务返回 `PagedResultDto<UrbanWeighingListItemDto>`，不再向 UI 暴露 `WeighingRecord` / `UrbanWeighingExtension` 实体
- **BREAKING**：`IUrbanWeighingExtensionService.GetPagedWithRecordsAsync` 签名改为接受单个 input DTO，返回列表项 DTO（可重命名方法以反映语义，如 `GetPagedListItemsAsync`）
- `UrbanAttendedWeighingViewModel`：集合属性由 `WeighingRecords` 重命名为 `ListItems`（`ObservableCollection<UrbanWeighingListItemDto>`）；`ReloadRecordsAsync` 映射 DTO 并就地更新集合；选中项与侧栏照片加载基于 DTO 中的 `WeighingRecordId`
- `UrbanAttendedWeighingWindow.axaml`：`ItemsSource` 绑定 `ListItems`，`DataTemplate` 绑定 DTO 字段（含扁平化的 `SyncStatus` 等），移除对 `entities:WeighingRecord` 的编译期绑定
- 移除服务层对 `Record.UrbanExtension = …` 的临时导航赋值
- 更新相关单元测试

## Capabilities

### New Capabilities

- `urban-weighing-list-presentation`: Urban 称重列表 UI 展示 DTO、查询入参 DTO 及 ViewModel 绑定契约（`ListItems`）

### Modified Capabilities

- `urban-weighing-extension`: 分页列表查询 API 使用打包 input DTO，返回列表项 DTO 而非实体；禁止为 UI 临时挂载导航属性

## Impact

- **子仓库**：`repos/MaterialClient`
  - `MaterialClient.Common`：`IUrbanWeighingExtensionService` / `UrbanWeighingExtensionService`、新增 Dtos
  - `MaterialClient.Urban`：`UrbanAttendedWeighingViewModel`、`UrbanAttendedWeighingWindow.axaml` / `.cs`
  - `MaterialClient.Common.Tests`：Urban 扩展查询相关测试
- **无** UrbanManagement / 主仓库运行时变更
