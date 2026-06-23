## ADDED Requirements

### Requirement: Publish event after successful upload
The `PollingBackgroundService` SHALL publish an `UploadCompletedEventData` via `ILocalEventBus` after `SubmitRecordAsync` completes successfully for a record.

#### Scenario: Event published on successful submit
- **WHEN** `SubmitRecordAsync` returns success for a weighing record
- **THEN** `PollingBackgroundService` MUST publish `UploadCompletedEventData` with the `WeighingRecordId` of the submitted record
- **AND** the event MUST be published after the sync status has been updated to `Synced`

#### Scenario: No event on failed upload
- **WHEN** `SubmitRecordAsync` throws or returns failure for a record
- **THEN** `PollingBackgroundService` MUST NOT publish `UploadCompletedEventData` for that record
- **AND** the existing error handling (log + continue) MUST remain unchanged
