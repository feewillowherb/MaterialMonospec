## ADDED Requirements

### Requirement: 固废独立 Displayed 净重开关
Waybill MUST 支持 ExtraProperties 键 `SolidWasteInfo.UseIndependentDisplayedNet`（bool）。为 `true` 时，固废对外净重（Excel / `SolidWasteExportRow`、小票千克、主界面净重块、固废详情净重）MUST 使用对库内 `OrderGoodsWeight` 的独立 Displayed 舍入（`Round(..., 2, AwayFromZero)` / `ConvertDisplayedTonToKg`），MUST NOT 使用 `毛′ − 皮′` 派生。为 `false` 或未设置时，MUST 保持派生净重行为。毛重、皮重在两种模式下均 MUST 使用 Displayed Round。MUST NOT 因本开关回写毛/皮/净库值。

#### Scenario: 开关开启时导出保留独立净重
- **WHEN** 运单 `UseIndependentDisplayedNet` 为 true，库内毛/皮/净使 Displayed 后毛−皮 ≠ Round(库净)
- **THEN** 导出行净重 MUST 等于 `Round(OrderGoodsWeight, 2)`，MUST NOT 等于 Displayed 毛减皮

#### Scenario: 开关关闭或缺省时仍派生净重
- **WHEN** 运单未设置该键或为 false，库内毛 `13.04`、皮 `6.045`、净 `6.995`
- **THEN** 导出行净重 MUST 为 `6.99`

#### Scenario: 开关开启时小票净千克独立换算
- **WHEN** `UseIndependentDisplayedNet` 为 true 且 `OrderGoodsWeight` 为 `2.07`（Displayed 吨）
- **THEN** 票据 DTO 净重 MUST 为 `ConvertDisplayedTonToKg(2.07)`，MUST NOT 为毛 kg 减皮 kg
