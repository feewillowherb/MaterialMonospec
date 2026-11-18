## Why

固废对外毛/皮/净各自 `Round(库值, 2)` 后会出现 `毛′ − 皮′ ≠ 净′`（例 13.04/6.05/7.00）。产品要求**逻辑一致性**优先于各自保留库净精度：净重应由显示精度下的毛、皮派生。

## What Changes

- 固废 Excel / 数据管理列表：`净′ = Round(毛,2) − Round(皮,2)`，不再 `Round(库净,2)`。
- 固废小票：净 kg = 毛 kg − 皮 kg（毛/皮仍 Displayed→kg）。
- 固废主界面净重块：同派生公式（仅 `WeighingMode.SolidWaste`；Recycle 暂不动）。
- 固废详情毛/皮/净：净随显示精度毛−皮，避免 F2 后三列不恒等。
- **不**回写 Waybill；**不**改标准模式 / Urban 上云。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `solidwaste-excel-export`: 净重改为 Displayed 毛−皮派生；小票净 kg 同理；废止「可毛−皮≠净」场景。

## Impact

- MaterialClient：`MaterialMath`（可选 helper）、`SolidWasteService`、`WeighingMatchingService`、`AttendedWeighingViewModel`、`SolidWasteWeighingDetailViewModel`、相关测试。
- 推翻归档 change `align-solidwaste-weights-ui-f2` 中「各字段独立 F2」对净重的约定。
