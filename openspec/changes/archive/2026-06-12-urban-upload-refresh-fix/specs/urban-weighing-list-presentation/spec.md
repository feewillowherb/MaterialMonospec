## ADDED Requirements

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
