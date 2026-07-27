# Detail ViewModel Hierarchy

## Purpose

Defines the inheritance hierarchy for attended weighing detail ViewModels, separating shared behavior into an abstract base class with mode-specific implementations for Standard and SolidWaste weighing modes.
## Requirements
### Requirement: ViewModel inheritance hierarchy
The system SHALL define an abstract base class `AttendedWeighingDetailViewModelBase` inheriting from `ViewModelBase`, with concrete subclasses: `StandardWeighingDetailViewModel`, `SolidWasteWeighingDetailViewModel`, and `RecycleWeighingDetailViewModel`.

#### Scenario: Base class instantiation blocked
- **WHEN** code attempts to instantiate `AttendedWeighingDetailViewModelBase` directly
- **THEN** compilation fails because the class is abstract

#### Scenario: Standard mode creates correct subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.Standard`
- **THEN** it creates an instance of `StandardWeighingDetailViewModel` via DI

#### Scenario: SolidWaste mode creates correct subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.SolidWaste`
- **THEN** it creates an instance of `SolidWasteWeighingDetailViewModel` via DI

#### Scenario: Recycle mode creates Recycle subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.Recycle`
- **THEN** it creates an instance of `RecycleWeighingDetailViewModel` via DI
- **AND** SHALL NOT create `SolidWasteWeighingDetailViewModel`

### Requirement: Shared properties in base class
The base class SHALL expose all properties shared between modes: `AllWeight`, `TruckWeight`, `GoodsWeight`, `PlateNumber`, `Remark`, `JoinTime`, `OutTime`, `Operator`, `WeighingRecordId`, `SelectedDeliveryType`, `DeliveryTypeOptions`, `IsWeighingRecord`, `IsMatchButtonVisible`, `IsCompleteButtonVisible`, `PlateNumberError`, `MaterialItems`, `ProviderLabelText`, `DeliveryTypeTitleText`, `CompleteButtonText`, `DeliveryTypeDisplayText`.

#### Scenario: All shared properties accessible via base class
- **WHEN** a View binds to any shared property through `x:DataType="vm:AttendedWeighingDetailViewModelBase"`
- **THEN** the binding resolves correctly for both Standard and SolidWaste subclass instances

### Requirement: Mode-specific abstract property
The base class SHALL declare `abstract bool IsSolidWasteMode { get; }` to support View-layer mode switching.

#### Scenario: Standard subclass returns false
- **WHEN** `IsSolidWasteMode` is read on a `StandardWeighingDetailViewModel` instance
- **THEN** it returns `false`

#### Scenario: SolidWaste subclass returns true
- **WHEN** `IsSolidWasteMode` is read on a `SolidWasteWeighingDetailViewModel` instance
- **THEN** it returns `true`

### Requirement: Shared commands in base class
The base class SHALL provide shared commands: `AbolishAsync`, `Close`, `MatchAsync`. These commands SHALL work identically to the current implementation.

#### Scenario: Abolish command works for both modes
- **WHEN** user clicks "废单" button in either Standard or SolidWaste mode
- **THEN** the record is deleted and `AbolishCompleted` event fires with correct item info

#### Scenario: Close command works for both modes
- **WHEN** user clicks "下一个" button in either mode
- **THEN** `CloseRequested` event fires

### Requirement: Shared events in base class
The base class SHALL define events: `SaveCompleted`, `AbolishCompleted`, `CloseRequested`, `MatchCompleted`, `CompleteCompleted`, `ManualMatchSaveCompleted`. Event signatures SHALL remain unchanged.

#### Scenario: Parent ViewModel subscribes to base class events
- **WHEN** `AttendedWeighingViewModel` subscribes to events on a subclass instance
- **THEN** all event handlers receive `ItemOperationCompletedEventArgs` with correct data

### Requirement: Template method pattern for Save
The base class SHALL implement `SaveAsync` as a template method: validate plate number → call `SaveModeSpecificAsync()` (abstract) → call `OnSaveCompletedAsync()` (shared tail).

#### Scenario: Standard save flow
- **WHEN** user clicks save in Standard mode
- **THEN** base validates plate number, `StandardWeighingDetailViewModel.SaveModeSpecificAsync()` executes `UpdateListItemAsync`, then shared tail handles BillPhoto/events/notification

#### Scenario: SolidWaste save flow
- **WHEN** user clicks save in SolidWaste mode
- **THEN** base validates plate number, `SolidWasteWeighingDetailViewModel.SaveModeSpecificAsync()` executes `UpdateSolidWasteModeAsync`, then shared tail handles BillPhoto/events/notification

### Requirement: Template method pattern for Complete
The base class SHALL implement `CompleteAsync` as a template method: validate plate number → call `CompleteModeSpecificAsync()` (abstract) → handle BillPhoto → fire `CompleteCompleted` event.

#### Scenario: Standard complete flow
- **WHEN** user clicks complete in Standard mode
- **THEN** base validates plate number, `StandardWeighingDetailViewModel.CompleteModeSpecificAsync()` validates supplier/material/unit/quantity then calls Update+CompleteOrder, then shared tail fires event

#### Scenario: SolidWaste complete flow
- **WHEN** user clicks complete in SolidWaste mode
- **THEN** base validates plate number, `SolidWasteWeighingDetailViewModel.CompleteModeSpecificAsync()` validates supplier/material/street/type/orderNumber then calls Save+CompleteOrder, then shared tail fires event

### Requirement: InitializeData split
`InitializeData` SHALL be split into `InitializeCommonData` (base class, sets shared properties) + `LoadModeSpecificDataAsync` (virtual, overridden by subclasses).

#### Scenario: Standard mode loads recommendation and MaterialItemRows
- **WHEN** `StandardWeighingDetailViewModel.LoadModeSpecificDataAsync()` executes
- **THEN** it loads recommendation data by plate number and initializes each MaterialItemRow with material/units

#### Scenario: SolidWaste mode loads ExtraProperties
- **WHEN** `SolidWasteWeighingDetailViewModel.LoadModeSpecificDataAsync()` executes
- **THEN** it reads SolidWaste data from `WeighingRecord` or `Waybill` ExtraProperties and populates SolidWaste-specific fields

### Requirement: No IsSolidWasteMode if/else branching
After refactoring, the codebase SHALL NOT contain any `if (IsSolidWasteMode)` conditional branches in the ViewModel layer. All mode-specific behavior SHALL be determined by polymorphism.

#### Scenario: Codebase search finds no mode branching
- **WHEN** searching all ViewModel files for the pattern `if.*IsSolidWasteMode`
- **THEN** zero matches are found

### Requirement: View DataType compatibility
All views that bind to the detail ViewModel SHALL use `x:DataType="vm:AttendedWeighingDetailViewModelBase"` for compiled bindings in shared popup/container scope. Views that are strictly mode-specific MAY use their concrete subclass DataType only inside the mode-specific view boundary.

#### Scenario: Shared popup bindings compile against base type
- **WHEN** `AttendedWeighingDetailPopup` (and any shared child controls) is compiled with Avalonia compiled bindings
- **THEN** shared bindings resolve against `AttendedWeighingDetailViewModelBase` and do not require casting to a concrete mode subclass

#### Scenario: Standard mode concrete bindings stay in standard view boundary
- **WHEN** standard-only properties are bound in `StandardModeFormView`
- **THEN** those bindings are compiled and resolved within standard view scope without affecting shared popup binding contract

#### Scenario: SolidWaste mode concrete bindings stay in solid-waste view boundary
- **WHEN** solid-waste-only properties are bound in `SolidWasteModeFormView`
- **THEN** those bindings are compiled and resolved within solid-waste view scope without affecting shared popup binding contract

#### Scenario: SolidWaste popup open does not throw cast exception
- **WHEN** detail popup is opened with `SolidWasteWeighingDetailViewModel` as DataContext
- **THEN** no `InvalidCastException` is thrown from compiled binding accessors and popup renders normally

### Requirement: MaterialItemRow independence
`MaterialItemRow` SHALL be defined in its own file (`ViewModels/MaterialItemRow.cs`) and remain shared by both modes via the base class `MaterialItems` collection.

#### Scenario: MaterialItemRow accessible from both subclasses
- **WHEN** either `StandardWeighingDetailViewModel` or `SolidWasteWeighingDetailViewModel` accesses `MaterialItems`
- **THEN** `MaterialItemRow` instances function identically to the current implementation

### Requirement: DI registration via ITransientDependency
Both subclasses SHALL implement `ITransientDependency` for automatic ABP DI registration.

#### Scenario: DI resolves Standard subclass
- **WHEN** `_serviceProvider.GetRequiredService<StandardWeighingDetailViewModel>()` is called
- **THEN** a new transient instance is returned with all dependencies injected

#### Scenario: DI resolves SolidWaste subclass
- **WHEN** `_serviceProvider.GetRequiredService<SolidWasteWeighingDetailViewModel>()` is called
- **THEN** a new transient instance is returned with all dependencies injected

### Requirement: Recycle 独立客户端挂载 Attended 称重 UI
Recycle 独立客户端（`MaterialClient.Recycle`）SHALL 在启动成功后显示与 SolidWaste 等价的 Attended 称重主界面，而非占位窗口。

#### Scenario: 主界面为 AttendedWeighingWindow
- **WHEN** Recycle 应用完成授权与登录
- **THEN** 主窗口 SHALL 为 `AttendedWeighingWindow`（或 UI 共享层等价类型）
- **AND** SHALL NOT 以仅显示「称重数据上报管线已就绪」的占位 UI 作为生产主界面

#### Scenario: Recycle 模式创建称重记录
- **WHEN** 用户在 Recycle 客户端完成一次称重并保存
- **THEN** 创建的 `WeighingRecord.WeighingMode` SHALL 为 `WeighingMode.Recycle`
- **AND** 该记录 SHALL 可被 `RecycleDataSyncService` 扫描上报

#### Scenario: Recycle 详情弹窗复用 SolidWaste ViewModel
- **WHEN** 用户在 Recycle 客户端打开称重详情
- **THEN** SHALL 使用 `SolidWasteWeighingDetailViewModel`（与 `WeighingMode.Recycle` 分支一致）
- **AND** SHALL NOT 使用 `StandardWeighingDetailViewModel`

### Requirement: Auth 与 Login 窗口 UI 共享
Auth 与 Login 窗口及 ViewModel SHALL 位于 Recycle 可引用的程序集（`MaterialClient.UI` 或 Recycle 项目内），使独立 Recycle exe 无需引用 MaterialClient 主程序项目。

#### Scenario: Recycle 项目可解析 Auth 窗口
- **WHEN** `MaterialClient.Recycle` 编译
- **THEN** SHALL 可 DI 解析授权码窗口与 ViewModel
- **AND** SHALL NOT 项目引用 `MaterialClient` 主程序 csproj

#### Scenario: 主程序 5000/5010 仍可启动
- **WHEN** UI 共享迁移完成后 MaterialClient 主程序启动
- **THEN** 5000/5010 授权与登录流程 SHALL 保持可用

### Requirement: Standard mode material grid single-click material selection
`StandardModeFormView` SHALL open the material selection Popup with a single click on the material name cell, without requiring a prior row-selection click.

#### Scenario: Single click opens material popup
- **WHEN** user clicks the material name cell in the Standard mode DataGrid
- **THEN** the material selection Popup SHALL open immediately
- **AND** `StandardWeighingDetailViewModel.IsMaterialPopupOpen` SHALL be `true`

#### Scenario: Popup reopens after light dismiss
- **WHEN** user opens the material selection Popup
- **AND** user dismisses the Popup by clicking outside (light dismiss)
- **AND** user clicks the material name cell again
- **THEN** the Popup SHALL open again on the first click

### Requirement: Standard mode material popup close state synchronization
When the material selection Popup closes for any reason without confirming a material, the system SHALL reset popup-related ViewModel state so subsequent opens work correctly.

#### Scenario: Light dismiss resets popup state
- **WHEN** user dismisses the material selection Popup via light dismiss
- **THEN** `IsMaterialPopupOpen` SHALL become `false`
- **AND** `CurrentMaterialRow` SHALL be cleared

#### Scenario: Confirmed selection closes popup
- **WHEN** user selects a material from the Popup
- **THEN** `IsMaterialPopupOpen` SHALL become `false`
- **AND** the target `MaterialItemRow.SelectedMaterial` SHALL be updated

### Requirement: Standard mode unit column inline editing with material prerequisite
The unit column in `StandardModeFormView` SHALL use inline editing (editor in `CellTemplate`, column marked read-only to DataGrid) and SHALL NOT enter DataGrid cell edit mode. The unit selector SHALL be disabled until a material is selected.

#### Scenario: Unit selector disabled without material
- **WHEN** a DataGrid row has no `SelectedMaterial`
- **THEN** the unit ComboBox in that row SHALL be disabled
- **AND** clicking the unit cell SHALL NOT block interaction with other DataGrid cells

#### Scenario: Unit selector enabled after material selected
- **WHEN** a DataGrid row has a `SelectedMaterial` and loaded `MaterialUnits`
- **THEN** the unit ComboBox SHALL be enabled
- **AND** user SHALL be able to change `SelectedMaterialUnit` via the inline ComboBox

#### Scenario: Other columns remain clickable after unit cell interaction
- **WHEN** user clicks the unit cell on a row without a selected material
- **THEN** user SHALL still be able to click material name, waybill quantity, or other rows without extra dismiss steps

