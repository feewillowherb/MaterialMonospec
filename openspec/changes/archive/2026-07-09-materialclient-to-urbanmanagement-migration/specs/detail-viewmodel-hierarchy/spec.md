## ADDED Requirements

### Requirement: Recycle 模式使用 SolidWaste DetailViewModel
当 `WeighingMode` 为 `Recycle`（301）时，系统 SHALL 复用 `SolidWasteWeighingDetailViewModel` 作为称重详情 ViewModel，因为 Recycle 前端功能与 SolidWaste 完全一致。

#### Scenario: Recycle 模式创建 SolidWaste DetailViewModel
- **WHEN** `AttendedWeighingViewModel.OpenDetail` 收到一个 `WeighingMode.Recycle` 的项目
- **THEN** SHALL 通过 DI 创建 `SolidWasteWeighingDetailViewModel` 实例
- **AND** SHALL NOT 创建 `StandardWeighingDetailViewModel`

#### Scenario: SolidWaste 模式行为不变
- **WHEN** `AttendedWeighingViewModel.OpenDetail` 收到一个 `WeighingMode.SolidWaste` 的项目
- **THEN** SHALL 通过 DI 创建 `SolidWasteWeighingDetailViewModel` 实例（行为不变）
