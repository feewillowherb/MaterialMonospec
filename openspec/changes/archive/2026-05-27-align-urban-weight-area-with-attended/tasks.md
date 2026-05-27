## 1. 共享控件（MaterialClient.UI）

- [x] 1.1 将 `LoadingDotsAnimation` 从 `MaterialClient/Views/Controls` 迁至 `MaterialClient.UI`（命名空间与 axaml 路径一并更新）
- [x] 1.2 更新 `AttendedWeighingWindow.axaml` 的 xmlns/控件引用，确认有人值守构建通过且动画行为不变

## 2. 状态文案帮助类（MaterialClient.Common，可选）

- [x] 2.1 提取 `AttendedWeighingStatus` → 显示文案的共享方法（如 `AttendedWeighingStatusDisplay.GetStatusText`），供 Attended / Urban ViewModel 复用

## 3. ViewModel（MaterialClient.Urban）

- [x] 3.1 新增 `MostFrequentPlateNumber`；`Initialize()` 中从 `IAttendedWeighingService.GetMostFrequentPlateNumber()` 初始化
- [x] 3.2 订阅 `PlateNumberChangedMessage`，主线程更新 `MostFrequentPlateNumber`
- [x] 3.3 新增 `CurrentWeighingStatusText`、`IsWeighingActive`；在 `StatusChangedEventData` 处理中更新（替换称重区对 `WeightStatus`/`WeightStatusColor` 的依赖，列表等业务可保留原属性若仍使用）
- [x] 3.4 确认 `CurrentWeight` 仍由 `TruckScaleWeightService` 更新（绑定侧使用 F2 格式）

## 4. UI（MaterialClient.Urban）

- [x] 4.1 重写 `UrbanAttendedWeighingWindow.axaml` 的 `WeightAreaContent`：保留现有渐变背景层；内容层 `Margin="24,32"` + 三列 Grid
- [x] 4.2 左列：`MostFrequentPlateNumber` 卡片（样式对齐 Attended）
- [x] 4.3 中列：圆角重量卡，仅重量 + 单位（F2、64 号字、竖线分隔），**无** DeliveryType
- [x] 4.4 右列：`CurrentWeighingStatusText` + `LoadingDotsAnimation`（margin 与 Attended 一致）
- [x] 4.5 添加 `xmlns` 引用 `MaterialClient.UI` 中迁移后的 `LoadingDotsAnimation`

## 5. 验证

- [x] 5.1 构建 `MaterialClient.Urban` 与 `MaterialClient`
- [ ] 5.2 手动验证：渐变背景未变；车牌随 LPR 更新；重量两位小数；称重中右侧白字 + 三点动画；无 DeliveryType 控件
