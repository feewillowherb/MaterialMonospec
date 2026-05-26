## MODIFIED Requirements

### Requirement: Vehicle record row selection via Button Command

The vehicle record list in UrbanAttendedWeighingWindow SHALL use `ListBox` with `SelectedItem` two-way binding for row selection. Each row SHALL be a `ListBoxItem` container with custom inline styling to remove default selection chrome. The `SelectedItem` property SHALL bind to `SelectedListItem` on the ViewModel.

#### Scenario: User clicks on a vehicle record row
- **WHEN** user clicks anywhere on a vehicle record row (not on an interactive child element)
- **THEN** the `ListBox.SelectedItem` SHALL be set to the clicked item
- **AND** `SelectedListItem` on the ViewModel SHALL be updated via two-way binding

#### Scenario: Click on action button does not change selection
- **WHEN** user clicks on the "审批" Button within a row
- **THEN** the `ApproveRecordCommand` SHALL execute with the row's item as parameter
- **AND** the `ListBox.SelectedItem` SHALL NOT change as a side-effect of the button click

### Requirement: Selected row visual highlighting

The currently selected vehicle record row SHALL display a distinct background color (`#E3F2FD`) via `ListBoxItem` container style. Unselected rows SHALL have a transparent background.

#### Scenario: Row becomes selected
- **WHEN** a vehicle record row is selected (item equals SelectedListItem)
- **THEN** the `ListBoxItem` container background SHALL change to `#E3F2FD`

#### Scenario: Previously selected row becomes deselected
- **WHEN** a different row is selected
- **THEN** the previously selected row background SHALL revert to transparent
- **AND** the newly selected row background SHALL change to `#E3F2FD`

#### Scenario: Hover visual feedback
- **WHEN** the user hovers over an unselected row
- **THEN** the row background SHALL change to `#F0F7FF`
- **AND** the hover effect SHALL NOT apply to the currently selected row

### Requirement: SelectListItem generates ReactiveCommand

The `SelectListItem` method and its generated `SelectListItemCommand` on `UrbanAttendedWeighingViewModel` SHALL be removed. Row selection SHALL be handled entirely by `ListBox.SelectedItem` two-way binding.

#### Scenario: No SelectListItemCommand exists
- **WHEN** the ViewModel is compiled
- **THEN** no `SelectListItemCommand` property SHALL exist
- **AND** no `[ReactiveCommand] SelectListItem` method SHALL exist
- **AND** `SelectedListItem` SHALL remain as a `[Reactive]` property that the `ListBox` binds to

### Requirement: Approval column uses interactive Button

The "审批" (approval) column in the vehicle record list SHALL use a `Button` element bound to `ApproveRecordCommand` on the parent ViewModel, passing the current item as `CommandParameter`.

#### Scenario: Approval button is interactive
- **WHEN** the vehicle record list renders
- **THEN** the approval column SHALL display "审批" as a `Button`
- **AND** clicking the button SHALL execute `ApproveRecordCommand` with the current `UrbanWeighingListItemDto` as parameter
- **AND** the click SHALL NOT trigger row selection

#### Scenario: Approval button styled as primary action
- **WHEN** the approval button renders
- **THEN** it SHALL use the `primary-button` style class
- **AND** it SHALL be centered in the action column

### Requirement: No code-behind event handler for row selection

The `UrbanAttendedWeighingWindow.axaml.cs` code-behind SHALL NOT contain any `OnRecordClick` or `PointerPressed` event handler for row selection. All selection logic SHALL be handled through `ListBox.SelectedItem` MVVM binding.

#### Scenario: Code-behind is clean
- **WHEN** the code-behind file is inspected
- **THEN** no `OnRecordClick` method or `PointerPressed` event handler related to record selection SHALL exist
