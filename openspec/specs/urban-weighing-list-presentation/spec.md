## Purpose

Defines how the Urban attended weighing UI presents paged weighing list data: list item DTOs, `ListItems` binding, `IsAnomaly`-based badges and tabs (aligned with `urban-anomaly-detection`), and packaged query input from the ViewModel.

## Requirements

### Requirement: Urban weighing list item DTO
The Urban attended weighing UI SHALL bind list rows to `UrbanWeighingListItemDto` (or equivalent name in `MaterialClient.Common`), not to `WeighingRecord` or `UrbanWeighingExtension` entities. The DTO MUST align with `urban-anomaly-detection` semantics for tab filtering and primary status badges.

#### Scenario: DTO fields for list display
- **WHEN** a list row is prepared for the Urban attended weighing screen
- **THEN** the DTO MUST include `WeighingRecordId` (`long`), `PlateNumber`, `AddDate`, `TotalWeight`, and `IsAnomaly` (`bool`)
- **AND** the DTO MUST include `SyncStatus` (nullable when no extension row exists) for optional sync-state display only
- **AND** the DTO MUST NOT expose EF entity types or navigation properties

#### Scenario: ViewModel collection naming
- **WHEN** `UrbanAttendedWeighingViewModel` exposes the bound collection for the vehicle list
- **THEN** the property MUST be named `ListItems` of type `ObservableCollection<UrbanWeighingListItemDto>`
- **AND** the ViewModel MUST NOT expose a property named `WeighingRecords` bound to entities for this list

### Requirement: Urban list UI binding
The Urban attended weighing window SHALL bind a `ListBox` (replacing the previous `ItemsControl`) to `ListItems` and use compile-time `DataTemplate` typing against the list item DTO. The `ListBox.SelectedItem` SHALL be two-way bound to `SelectedListItem` on the ViewModel.

#### Scenario: ItemsSource binding
- **WHEN** the vehicle records list is rendered
- **THEN** `ItemsSource` MUST bind to `{Binding ListItems}`
- **AND** `SelectedItem` MUST bind to `{Binding SelectedListItem, Mode=TwoWay}`
- **AND** row templates MUST bind to DTO scalar properties without referencing `UrbanExtension` navigation paths

#### Scenario: ListBox custom styling
- **WHEN** the `ListBox` renders in the weighing window
- **THEN** the `ListBox` MUST have transparent background and zero border thickness
- **AND** `ListBoxItem` containers MUST have no default selection chrome, focus ring, or border
- **AND** `ListBoxItem` horizontal content alignment MUST be `Stretch` to fill the row width
- **AND** row separators MUST be rendered via `BorderThickness="0,0,0,1"` and `BorderBrush="#F1F5F9"` on the `ListBoxItem`

#### Scenario: Primary status badge from IsAnomaly
- **WHEN** a list row is displayed
- **THEN** the primary status badge MUST reflect `IsAnomaly` (green「正常」when false, red「异常」when true)
- **AND** the badge MUST NOT use `SyncStatus == Failed` as the definition of「异常」for the tab filter or primary badge

#### Scenario: Optional sync failure indication
- **WHEN** `SyncStatus == Failed` on the DTO
- **THEN** the UI MAY show a separate sync-failure indication distinct from the `IsAnomaly` data-quality badge
- **AND** such indication MUST NOT replace or conflate with the `IsAnomaly`-based「异常」tab semantics

#### Scenario: List refresh after reload
- **WHEN** `ReloadRecordsAsync` completes successfully with one or more items
- **THEN** `ListItems` MUST be updated on the UI thread so the list visually reflects the new page of DTOs
- **AND** the update MUST preserve the same `ObservableCollection` instance (clear and re-add, or equivalent in-place update)

#### Scenario: Row selection for sidebar
- **WHEN** the user selects a list row
- **THEN** the ViewModel MUST store the selected `UrbanWeighingListItemDto` (via `ListBox.SelectedItem` two-way binding)
- **AND** photo path loading MUST use `WeighingRecordId` from the DTO, not a `WeighingRecord` entity instance from the list

#### Scenario: Action column contains interactive Button
- **WHEN** a list row renders the action column
- **THEN** the column MUST contain a `Button` element with text "审批"
- **AND** the Button MUST be bound to `ApproveRecordCommand` on the parent ViewModel
- **AND** the Button click MUST NOT propagate as a row selection event

### Requirement: Packaged list query input from ViewModel
The ViewModel SHALL construct a single input DTO when calling the Urban extension service for paged list data.

#### Scenario: Input built from filter state
- **WHEN** `ReloadRecordsAsync` queries the domain layer
- **THEN** it MUST pass one `GetUrbanWeighingListInput` (or equivalent) containing page index, page size, tab filter, search text, and optional start/end times
- **AND** it MUST NOT pass those values as separate positional parameters to the service method

### Requirement: 列表展示异常原因

Urban 左侧称重记录列表 SHALL 显示异常原因字段，帮助操作员快速定位异常类型。

#### Scenario: 异常记录显示原因
- **WHEN** 列表项 `IsAnomaly == true`
- **THEN** 行模板 MUST 显示异常原因文本字段
- **AND** 文本内容 MUST 与异常判定输出一致

#### Scenario: 正常记录无异常原因
- **WHEN** 列表项 `IsAnomaly == false`
- **THEN** 行模板 MUST 显示空值或占位（如 `--`）

### Requirement: 列表展示上传时间

Urban 左侧称重记录列表 SHALL 新增上传时间字段，用于显示记录上云时间。

#### Scenario: 有上传时间
- **WHEN** 列表项存在上传时间
- **THEN** 行模板 MUST 显示上传时间
- **AND** 时间格式 MUST 与界面既有时间格式保持一致

#### Scenario: 无上传时间
- **WHEN** 列表项没有上传时间
- **THEN** 行模板 MUST 显示占位（如 `--`）

### Requirement: 仅异常可审批

审批按钮 SHALL 仅对异常记录可点击，正常记录必须禁用审批入口。

#### Scenario: 异常记录按钮可用
- **WHEN** 列表项 `IsAnomaly == true`
- **THEN** 对应行的审批按钮 MUST 可点击并可触发审批命令

#### Scenario: 正常记录按钮禁用
- **WHEN** 列表项 `IsAnomaly == false`
- **THEN** 对应行的审批按钮 MUST 为禁用状态
- **AND** 点击（或触发）时 MUST NOT 执行审批命令
