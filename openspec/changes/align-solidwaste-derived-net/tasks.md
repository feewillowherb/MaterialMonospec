## 1. MaterialMath

- [x] 1.1 新增 `DeriveDisplayedNetTon(gross, tare)`（先 Round 再相减；缺一侧返回 null）
- [x] 1.2 单测：13.04/6.045 → 净 6.99

## 2. 导出与打印

- [x] 2.1 `SolidWasteMapToExportRow` 净重改派生
- [x] 2.2 `CreateWeighingTicketDtoAsync` 净 kg = 毛 kg − 皮 kg
- [x] 2.3 更新 `SolidWasteMapToExportRowWeightTests`

## 3. UI（仅 SolidWaste）

- [x] 3.1 主界面净重块：SolidWaste 用派生；Recycle 保持原样
- [x] 3.2 `SolidWasteWeighingDetailViewModel`：GoodsWeight 按 Displayed 毛−皮

## 4. 验证

- [x] 4.1 跑相关 Common 单测
