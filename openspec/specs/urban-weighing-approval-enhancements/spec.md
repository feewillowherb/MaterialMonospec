## Purpose

Defines enhancements to the Urban weighing record approval workflow: license plate validation during approval, anomaly flag updates after record edits, and DateTimePicker controls for the weighing time filter UI.

## Requirements

### Requirement: License plate validation during approval
The system SHALL validate that the `PlateNumber` value is a valid Chinese license plate before persisting approval changes.

#### Scenario: Valid license plate accepted
- **WHEN** the operator edits a record and enters a valid Chinese license plate (e.g., "京A12345", "粤B88888", "沪AD12345")
- **THEN** the validation SHALL pass
- **AND** `UpdateWeighingRecordAsync` SHALL be called with the validated plate number
- **AND** the record SHALL be persisted

#### Scenario: Invalid license plate rejected
- **WHEN** the operator enters an invalid license plate (e.g., "ABC123", empty string, "京A1234", "挂12345")
- **THEN** the validation SHALL fail
- **AND** an error message SHALL be displayed indicating the license plate format is invalid
- **AND** `UpdateWeighingRecordAsync` SHALL NOT be called
- **AND** the dialog SHALL remain open

#### Scenario: Null license plate handling
- **WHEN** the operator clears the PlateNumber field (null or empty)
- **THEN** the validation SHALL fail
- **AND** an error message SHALL indicate that a license plate is required

### Requirement: DateTimePicker for weighing time filter
The system SHALL provide `<u:DateTimePicker>` controls for the weighing time filter in `UrbanAttendedWeighingWindow`.

#### Scenario: DateTimePicker controls replace TextBox
- **WHEN** the Urban weighing window loads
- **THEN** the weighing time filter section SHALL display two `<u:DateTimePicker>` controls (start and end)
- **AND** the Ursa namespace SHALL be declared: `xmlns:u="https://irihi.tech/ursa"`
- **AND** the controls SHALL be bound to `StartTime` and `EndTime` properties on the ViewModel
- **AND** the display format SHALL be "MM-dd HH:mm"
- **AND** the panel format SHALL be "yyyy-MM-dd HH:mm"

#### Scenario: Date-time range filtering
- **WHEN** the operator selects a start date-time and/or end date-time
- **THEN** the selected values SHALL be bound to the ViewModel properties
- **AND** clicking "搜索" SHALL trigger `SearchAsync`
- **AND** the query SHALL filter records by `AddDate >= StartTime` and `AddDate <= EndTime`
- **AND** the list SHALL refresh with filtered results

#### Scenario: Reset clears date-time filters
- **WHEN** the operator clicks "重置"
- **THEN** `StartTime` and `EndTime` SHALL be set to null
- **AND** the DateTimePicker controls SHALL display empty state
- **AND** the list SHALL refresh with all records (no date-time filter)

#### Scenario: Time-only input compatibility
- **WHEN** the operator only changes the time portion (leaving date as default)
- **THEN** the system SHALL interpret this as today's date with the selected time
- **AND** the query SHALL execute correctly with the implied date
