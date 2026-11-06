## 1. ExtraProperties API

- [x] 1.1 `SolidWasteInfoExtensions` 增加 `UseIndependentDisplayedNet` Get/Set（Waybill）
- [x] 1.2 `WeighingListItemDto` 增加标志并从 `FromWaybill` 投影

## 2. 消费分支

- [x] 2.1 `SolidWasteMapToExportRow` 按标志选派生或 `Round(OrderGoodsWeight)`
- [x] 2.2 `CreateWeighingTicketDtoAsync` 按标志选净 kg 算法
- [x] 2.3 主界面固废净重块按 DTO 标志分支
- [x] 2.4 固废详情 `ComputeGoodsWeight`：独立模式用 Round(库净)

## 3. 测试与打标说明

- [x] 3.1 单测：标志 true → 净 2.07；false → 派生
- [x] 3.2 打标说明（运维，不自动写库）：

样例（`_tmp/117/old-mode-data.txt`）需对匹配运单设  
`ExtraProperties["SolidWasteInfo.UseIndependentDisplayedNet"] = true`：

1. 车牌 浙A26E23，进场 2026-11-04 07:51:17，出场 2026-11-04 07:54:33  
2. 车牌 浙A68L08，进场 2026-11-04 09:31:57，出场 2026-11-04 09:34:31  
3. 车牌 浙A68L08，进场 2026-11-04 10:27:49，出场 2026-11-04 10:36:04  

可用应用内调试写回，或按 ABP ExtraProperties JSON 结构更新 SQLite `Waybills` 行。
