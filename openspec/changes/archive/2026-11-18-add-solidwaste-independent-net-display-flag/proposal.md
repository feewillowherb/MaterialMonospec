## Why

固废默认已改为派生净重（`毛′ − 皮′`）。少数历史运单在旧「各自 F2」下净重与毛−皮不等（例 `8.28 − 6.22` 显示净 `2.07`）。不改代码无法保留旧观感；需要按单开关旧显示。

## What Changes

- Waybill ExtraProperties 增加 bool：`SolidWasteInfo.UseIndependentDisplayedNet`（扩展 Get/Set）。
- 为 true 时：毛/皮仍 Displayed Round；净对外用 `Round(OrderGoodsWeight, 2)`；小票净 kg 用 `ConvertDisplayedTonToKg(库净)`。
- 为 false/缺省：保持现有派生净重。
- `WeighingListItemDto` 投影该标志，供主界面净重块与详情使用。
- **不**自动给历史单打标（运维对指定车牌+进出场时间写 ExtraProperties）；**不**改标准/Recycle/Urban。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `solidwaste-excel-export`: 增加独立 Displayed 净重开关的要求与场景。

## Impact

- MaterialClient：`SolidWasteInfoExtensions`、`WeighingListItemDto`、`SolidWasteService`、`WeighingMatchingService`、固废主界面/详情 ViewModel、测试。
- 数据：三条样例（浙A26E23 / 浙A68L08×2，2026-11-04）需人工或脚本打标后生效。
