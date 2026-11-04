## 1. MaterialMath Displayed 吨 API

- [x] 1.1 在 `MaterialMath` 抽出/公开 `RoundToDisplayedTon`（`Round(..., 2, AwayFromZero)`），并让 `ConvertDisplayedTonToKg` 委托它
- [x] 1.2 补充/调整 `MaterialMathWeightConversionTests`（6.045→6.05、6.995→7.00；Displayed→kg 与既有用例一致）

## 2. 固废导出与同源列表

- [x] 2.1 在 `SolidWasteMapToExportRow`（或 `SolidWasteExportRow` type-owned `From*`）对毛/皮/净写入 `RoundToDisplayedTon` 结果；不回写 Waybill
- [x] 2.2 确认 `ExcelExportService` 汇总行对已圆行求和（必要时加注释；行为已满足则仅复核）
- [x] 2.3 为导出映射补单元测试或最小探针：库值 6.045/6.995 → 行上 6.05/7.00

## 3. 打印路径复核

- [x] 3.1 确认 `CreateWeighingTicketDtoAsync` 仍仅调用一次 `ConvertDisplayedTonToKg`，无二次 Round
- [x] 3.2 确认 `TicketPrintingService` 整数 kg 格式化与 DTO 一致；不改 Urban 上云换算

## 4. 验证

- [x] 4.1 跑相关 Common 单元测试
- [x] 4.2 手动或对照：同一固废单 UI / 数据管理列表 / Excel / 小票毛皮净一致（例皮 6.05、净 7.00、票 6050/7000）
