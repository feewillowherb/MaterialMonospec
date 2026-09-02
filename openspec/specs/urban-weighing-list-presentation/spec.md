## Purpose

Defines how the Urban attended weighing UI presents paged weighing list data: list item DTOs, `ListItems` binding, `IsAnomaly`-based badges and tabs (aligned with `urban-anomaly-detection`), and packaged query input from the ViewModel.
## Requirements
### Requirement: Urban weighing list item DTO
The Urban attended weighing UI SHALL bind list rows to a named list-row type in `MaterialClient.Common` (for example `UrbanAttendedListRow`), not to `WeighingRecord`, `UrbanPassageRecord`, or `UrbanWeighingExtension` entities. Weighing-kind rows MUST still carry the weighing display fields used today. Passage-kind rows MUST carry passage display fields. Anomaly tab semantics MUST remain aligned with `urban-anomaly-detection` and apply only to weighing-kind rows.

#### Scenario: DTO fields for list display
- **WHEN** a weighing-kind list row is prepared
- **THEN** the row MUST include `WeighingRecordId` (`long`), `PlateNumber`, `AddDate`, `TotalWeight`, and `IsAnomaly` (`bool`)
- **AND** the row MUST include `SyncStatus` (nullable when no extension row exists) for optional sync-state display only
- **AND** the row MUST NOT expose EF entity types or navigation properties
- **WHEN** a passage-kind list row is prepared
- **THEN** the row MUST include passage id, `PassageSource`, `CapturedAt`, `UrbanInOutType`, and display plate text
- **AND** MUST NOT require `IsAnomaly` or `TotalWeight`

#### Scenario: ViewModel collection naming
- **WHEN** `UrbanAttendedWeighingViewModel` exposes the bound collection for the vehicle list
- **THEN** the property MUST be named `ListItems` of a single `ObservableCollection` of the shared list-row type
- **AND** the ViewModel MUST NOT expose a property named `WeighingRecords` bound to entities for this list

### Requirement: Urban list UI binding
The Urban attended weighing window SHALL bind a `ListBox` to `ListItems` and use templates against the shared list-row type. The `ListBox.SelectedItem` SHALL be two-way bound to `SelectedListItem` on the ViewModel.

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
- **WHEN** a weighing-kind list row is displayed
- **THEN** the primary status badge MUST reflect `IsAnomaly` (green「正常」when false, red「异常」when true)
- **AND** the badge MUST NOT use `SyncStatus == Failed` as the definition of「异常」for the tab filter or primary badge
- **WHEN** a passage-kind list row is displayed on「全部记录」
- **THEN** the status cell MUST show「—」
- **AND** MUST NOT treat the row as anomalous

#### Scenario: Optional sync failure indication
- **WHEN** `SyncStatus == Failed` on a weighing-kind row
- **THEN** the UI MAY show a separate sync-failure indication distinct from the `IsAnomaly` data-quality badge
- **AND** such indication MUST NOT replace or conflate with the `IsAnomaly`-based「异常」tab semantics

#### Scenario: List refresh after reload
- **WHEN** `ReloadRecordsAsync` completes successfully with one or more items
- **THEN** `ListItems` MUST be updated on the UI thread so the list visually reflects the new page of DTOs
- **AND** the update MUST preserve the same `ObservableCollection` instance (clear and re-add, or equivalent in-place update)

#### Scenario: Row selection for sidebar
- **WHEN** the user selects a list row
- **THEN** the ViewModel MUST store the selected list-row DTO (via `ListBox.SelectedItem` two-way binding)
- **AND** photo path loading for weighing-kind rows MUST use `WeighingRecordId` from the DTO, not a `WeighingRecord` entity instance from the list
- **AND** photo path loading for passage-kind rows MUST use the passage record id and large-image attachment id, not a repository call from the ViewModel

#### Scenario: Action column contains interactive Button
- **WHEN** a weighing-kind list row renders the action column
- **THEN** the column MUST contain a `Button` element with text "审批"
- **AND** the Button MUST be bound to `ApproveRecordCommand` on the parent ViewModel
- **AND** the Button click MUST NOT propagate as a row selection event
- **WHEN** a passage-kind list row renders the action column
- **THEN** the column MUST NOT show a working weighing「审批」button

### Requirement: Packaged list query input from ViewModel
The ViewModel SHALL construct a single named input record when calling the Urban list service for paged data.

#### Scenario: Input built from filter state
- **WHEN** `ReloadRecordsAsync` queries the domain layer
- **THEN** it MUST pass one input record containing page index, page size, tab filter (including all-records, normal, anomaly, checkpoint, finished-product), search text, and optional start/end times
- **AND** it MUST NOT pass those values as separate positional parameters to the service method
- **AND** it MUST NOT use a C# tuple for that input

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

审批按钮 SHALL 仅对异常**称重**记录可点击；正常称重记录必须禁用审批入口。进出行 MUST NOT 提供称重审批。

#### Scenario: 异常记录按钮可用
- **WHEN** 列表项为称重且 `IsAnomaly == true`
- **THEN** 对应行的审批按钮 MUST 可点击并可触发审批命令

#### Scenario: 正常记录按钮禁用
- **WHEN** 列表项为称重且 `IsAnomaly == false`
- **THEN** 对应行的审批按钮 MUST 为禁用状态
- **AND** 点击（或触发）时 MUST NOT 执行审批命令

### Requirement: Auto-refresh list on upload completion
The `UrbanAttendedWeighingViewModel` SHALL subscribe to `UploadCompletedEventData` via `ILocalEventBus` and automatically refresh the weighing record list when the event is received.

#### Scenario: List refreshes after upload event
- **WHEN** `UploadCompletedEventData` is received by the ViewModel
- **THEN** the ViewModel MUST call `ReloadRecordsAsync()` to fetch updated list data
- **AND** `ListItems` MUST be updated on the UI thread so `UploadTime` and `SyncStatus` fields reflect the new values

#### Scenario: Error handling for upload event handler
- **WHEN** `ReloadRecordsAsync` throws during upload event handling
- **THEN** the exception MUST be caught and logged
- **AND** the ViewModel MUST remain functional (not crash or leave state inconsistent)

### Requirement: All-records mixed table with large photo only

When the Urban attended list tab is「全部记录」, `ListItems` SHALL contain a time-ordered mix of weighing and passage rows. Each row MUST carry a kind: weighing, checkpoint, or finished product. Mixed columns MUST stay visible: type, plate, weight, in/out, time, status, actions; missing values MUST show「—」rather than hiding columns. The right-side photo MUST show only the large image (empty if none). Plate color, vehicle type, and site type MUST NOT appear as mixed-table columns. Checkpoint and finished-product rows MUST NOT use `IsAnomaly` and MUST NOT show an approve button in this change.

#### Scenario: Mixed page is time-ordered

- **WHEN** the operator views「全部记录」with both weighing and passage data in the filter window
- **THEN** rows MUST interleave by record time descending (weighing time vs `CapturedAt`)
- **AND** pagination MUST apply after merging the two sources under the same filters (not one page of weighing stacked on one page of passage)

#### Scenario: Passage cells in mixed columns

- **WHEN** a mixed-table row is a passage record
- **THEN** type MUST be「卡口」or「成品」
- **AND** weight and status MUST display「—」
- **AND** in/out MUST display enter/exit from `UrbanInOutType`
- **AND** the action cell MUST NOT run weighing approval

#### Scenario: Weighing cells in mixed columns

- **WHEN** a mixed-table row is a weighing record
- **THEN** type MUST be「地磅」
- **AND** weight, status, and approve MUST follow existing weighing rules for that row
- **AND** in/out MUST show the weighing direction when the current weighing UI has one, otherwise「—」

#### Scenario: Normal and anomaly tabs stay weighing-only

- **WHEN** the operator selects「正常」or「异常」
- **THEN** the list MUST contain only weighing rows filtered by `IsAnomaly`
- **AND** MUST NOT include passage rows

#### Scenario: Sidebar photo is large only

- **WHEN** a mixed-table or weighing-tab row is selected
- **THEN** the right-side photo MUST bind the large capture/LPR image only
- **AND** MUST NOT display the small plate-crop image in that pane

