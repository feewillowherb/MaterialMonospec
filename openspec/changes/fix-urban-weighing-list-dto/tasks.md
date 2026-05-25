## 1. DTO 与查询契约（MaterialClient.Common）

- [ ] 1.1 新增 `GetUrbanWeighingListInput`（PageIndex、PageSize、TabFilter、SearchText、StartTime、EndTime）
- [ ] 1.2 新增 `UrbanWeighingListItemDto`（WeighingRecordId、PlateNumber、AddDate、TotalWeight、SyncStatus?）
- [ ] 1.3 将 `IUrbanWeighingExtensionService` 分页方法改为 `GetPagedListItemsAsync(GetUrbanWeighingListInput)`，返回 `PagedResultDto<UrbanWeighingListItemDto>`；移除或替换 `GetPagedWithRecordsAsync`
- [ ] 1.4 在 `UrbanWeighingExtensionService` 中 join 投影为 DTO，删除 `Record.UrbanExtension = …` 赋值

## 2. ViewModel（MaterialClient.Urban）

- [ ] 2.1 `WeighingRecords` 重命名为 `ListItems`（`ObservableCollection<UrbanWeighingListItemDto>`）
- [ ] 2.2 `SelectedRecord` 改为 `SelectedListItem`（或等价 DTO 选中属性）；`SelectRecord` 接受 DTO
- [ ] 2.3 `ReloadRecordsAsync` 使用 input DTO 调用服务，主线程更新 `ListItems`（Clear + Add）
- [ ] 2.4 `UpdatePhotoPathsAsync` 改为基于 `WeighingRecordId`，移除对 `WeighingRecord` 实体的依赖

## 3. UI（MaterialClient.Urban）

- [ ] 3.1 `UrbanAttendedWeighingWindow.axaml`：`ItemsSource="{Binding ListItems}"`，`DataTemplate` 绑定 DTO 字段与 `SyncStatus`（调整转换器/可见性）
- [ ] 3.2 `UrbanAttendedWeighingWindow.axaml.cs`：`OnRecordClick` 使用 DTO `Tag`；移除 `entities:WeighingRecord` xmlns（若不再使用）

## 4. 测试与验证

- [ ] 4.1 更新 `UrbanWeighingExtensionQueryTests`（及引用旧 API 的测试）对齐 DTO 与 input
- [ ] 4.2 运行 `MaterialClient.Common.Tests` 相关套件并通过
- [ ] 4.3 手动验证：启动 Urban 应用，列表加载、Tab 筛选、分页、行选中与侧栏照片
