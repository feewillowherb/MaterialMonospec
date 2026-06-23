## ADDED Requirements

### Requirement: Immediate single-record upload on approval via event

MaterialClient.Urban SHALL support triggering immediate upload for one weighing record after client-side approval, without waiting for the next `PollingBackgroundService` timer tick. The approval UI command path MUST NOT synchronously await `SubmitRecordAsync`; it SHALL publish an event and delegate HTTP to a background handler.

#### Scenario: Approval publishes upload requested event

- **WHEN** client-side approval completes successfully via `UpdateWeighingRecordAsync`
- **AND** the record's `UrbanWeighingExtension` has `SyncStatus == Pending` and `IsAnomaly == false`
- **THEN** `UrbanAttendedWeighingViewModel` SHALL publish `UrbanWeighingUploadRequestedEventData` via `ILocalEventBus` with the `WeighingRecordId`
- **AND** SHALL NOT synchronously await `IUrbanServerUploadService.SubmitRecordAsync` in the approval command handler

#### Scenario: Event handler uploads single record immediately

- **WHEN** `UrbanWeighingUploadRequestedEventData` is published
- **THEN** `UrbanWeighingUploadRequestedEventHandler` (or equivalent `ILocalEventHandler`) SHALL execute `SubmitRecordAsync` for that `WeighingRecordId` inside an ABP unit of work
- **AND** SHALL use the same upload pipeline as `PollingBackgroundService` (attachments + `ReceiveWeighingRecordAsync`)

#### Scenario: Successful immediate upload publishes UploadCompletedEventData

- **WHEN** the event handler's `SubmitRecordAsync` succeeds for the requested record
- **THEN** the handler SHALL publish `UploadCompletedEventData` with the same `WeighingRecordId`
- **AND** `UrbanAttendedWeighingViewModel` list refresh behavior SHALL remain unchanged

#### Scenario: Failed immediate upload leaves Pending for polling retry

- **WHEN** the event handler's `SubmitRecordAsync` throws or returns failure
- **THEN** the handler SHALL log the error
- **AND** SHALL leave `SyncStatus` as `Pending` for that record
- **AND** `PollingBackgroundService` SHALL retry the record on a subsequent timer tick

#### Scenario: Anomalous record does not publish immediate upload

- **WHEN** client-side approval completes but `IsAnomaly == true`
- **THEN** the system SHALL NOT publish `UrbanWeighingUploadRequestedEventData`
- **AND** SHALL NOT call `SubmitRecordAsync` until anomaly is cleared (consistent with polling skip rules)

#### Scenario: Polling worker remains fallback

- **WHEN** `BackgroundServices:Polling` is enabled
- **THEN** `PollingBackgroundService` SHALL continue periodic scanning of all `SyncStatus == Pending` and non-anomalous records
- **AND** immediate upload on approval SHALL NOT replace or disable the polling worker
