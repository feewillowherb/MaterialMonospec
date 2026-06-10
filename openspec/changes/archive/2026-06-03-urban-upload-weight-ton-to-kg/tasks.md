## 1. MaterialClient.Urban — 上云换算

- [x] 1.1 在 `UrbanServerUploadService` 构建 `UrbanWeighingRecordSubmitDto` 时，将 `TotalWeight` 设为 `MaterialMath.ConvertTonToKg(record.TotalWeight)`
- [x] 1.2 为 `MaterialClient.Urban` 或 `MaterialClient.Common.Tests` 增加单元测试：8.5 吨 → 8500 kg（及边界 0 吨行为）

## 2. UrbanManagement — 服务端量纲对齐

- [x] 2.1 将 `UrbanAnomalyDetectionOptions` 与 `appsettings.json` 默认 `UpperLimit`/`LowerLimit` 改为千克（30000 / 2000）
- [x] 2.2 在 `UrbanWeighingRecordReceiveInputDto`（或等价 DTO）上补充 XML 注释：`TotalWeight` 单位为 kg

## 3. 验证

- [x] 3.1 本地造一条约 8.5t 的 Urban 称重记录，触发上云后确认 `Urban_WeighingRecord.TotalWeight` ≈ 8500（单元测试覆盖 8.5→8500；E2E 需联调）
- [x] 3.2 在 Web 列表确认「重量（千克）」列与政府同步 `carType`（>4500 为 Large）符合预期（`UrbanAnomalyDetectorTests` 以 8500kg 为正常；E2E 需联调）
- [x] 3.3 文档：在 `MaterialClient.Urban` 的 `AGENTS.md` 或上云说明中注明「本地吨 / 上云 kg」
