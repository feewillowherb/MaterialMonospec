## 0. 前置（urban-anomaly-detection）

- [x] 0.1 确认 `UrbanWeighingExtension.IsAnomaly`、`IUrbanAnomalyDetector` 及创建流程已落地（见主 spec `urban-anomaly-detection` / 归档 `2026-05-26-urban-anomaly-detection`）
- [ ] 0.2 **用户手动**：在 `MaterialClientDbContext` 配置完成后，执行 `dotnet ef migrations add`（如 `AddIsAnomalyToUrbanExtension`）生成迁移脚本，并自行应用至数据库（`database update` 或部署流程）；实现方不代为运行迁移命令
- [ ] 0.3 确认数据库已存在 `IsAnomaly` 列及索引后再开始本 change 的 DTO/UI 实现

## 1. DTO 与查询契约（MaterialClient.Common）

- [x] 1.1 新增 `GetUrbanWeighingListInput`（PageIndex、PageSize、TabFilter、SearchText、StartTime、EndTime）
- [x] 1.2 新增 `UrbanWeighingListItemDto`（WeighingRecordId、PlateNumber、AddDate、TotalWeight、**IsAnomaly**、SyncStatus?）
- [x] 1.3 将 `IUrbanWeighingExtensionService` 分页方法改为 `GetPagedListItemsAsync(GetUrbanWeighingListInput)`，返回 `PagedResultDto<UrbanWeighingListItemDto>`；移除 `GetPagedWithRecordsAsync`
- [x] 1.4 在 `UrbanWeighingExtensionService` 中 join 投影为 DTO；Tab 过滤改为 **IsAnomaly**（正常/异常/全部）；删除 `Record.UrbanExtension = …`

## 2. ViewModel（MaterialClient.Urban）

- [x] 2.1 `WeighingRecords` 重命名为 `ListItems`（`ObservableCollection<UrbanWeighingListItemDto>`）
- [x] 2.2 `SelectedRecord` 改为 `SelectedListItem`；`SelectRecord` 接受 DTO
- [x] 2.3 `ReloadRecordsAsync` 使用 `GetUrbanWeighingListInput` 调用服务，主线程更新 `ListItems`（Clear + Add）
- [x] 2.4 `UpdatePhotoPathsAsync` 仅依赖 `WeighingRecordId`，移除实体依赖

## 3. UI（MaterialClient.Urban）

- [x] 3.1 `UrbanAttendedWeighingWindow.axaml`：`ItemsSource="{Binding ListItems}"`，`DataTemplate` 绑定 DTO；主徽章绑定 **IsAnomaly**（替换 `SyncStatus` / `UrbanExtension` 路径）
- [x] 3.2 （可选）`SyncStatus == Failed` 时展示与数据异常分离的同步失败提示
- [x] 3.3 更新/新增 Converter（如 `BoolConverters.Not` 用于 `IsAnomaly`）；`axaml.cs` 的 `OnRecordClick` 使用 DTO `Tag`

## 4. 测试与验证

- [x] 4.1 更新 `UrbanWeighingExtensionQueryTests`：DTO 映射、**IsAnomaly** Tab 过滤（非 SyncStatus）
- [x] 4.2 运行 `MaterialClient.Common.Tests` 相关套件并通过
- [ ] 4.3 手动验证：列表加载与 `ListItems` 刷新；Tab 正常/异常/全部；空车牌或超重记录出现在「异常」Tab；`IsAnomaly=false` 且 `SyncStatus=Failed` 时主徽章仍为「正常」（若实现同步提示则一并确认）
