## MODIFIED Requirements

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
