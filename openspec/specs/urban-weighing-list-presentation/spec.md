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
The Urban attended weighing window SHALL bind `ItemsControl` (or equivalent list) to `ListItems` and use compile-time `DataTemplate` typing against the list item DTO.

#### Scenario: ItemsSource binding
- **WHEN** the vehicle records list is rendered
- **THEN** `ItemsSource` MUST bind to `{Binding ListItems}`
- **AND** row templates MUST bind to DTO scalar properties without referencing `UrbanExtension` navigation paths

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
- **THEN** the ViewModel MUST store the selected `UrbanWeighingListItemDto` (or its `WeighingRecordId`)
- **AND** photo path loading MUST use `WeighingRecordId` from the DTO, not a `WeighingRecord` entity instance from the list

### Requirement: Packaged list query input from ViewModel
The ViewModel SHALL construct a single input DTO when calling the Urban extension service for paged list data.

#### Scenario: Input built from filter state
- **WHEN** `ReloadRecordsAsync` queries the domain layer
- **THEN** it MUST pass one `GetUrbanWeighingListInput` (or equivalent) containing page index, page size, tab filter, search text, and optional start/end times
- **AND** it MUST NOT pass those values as separate positional parameters to the service method
