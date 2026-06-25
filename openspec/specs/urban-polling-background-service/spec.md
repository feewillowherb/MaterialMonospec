# Urban Polling Background Service

## Purpose

Defines MaterialClient.Urban periodic background upload of weighing records with `SyncStatus == Pending`, using the same ABP worker pattern as the main application but implemented in the Urban assembly.
## Requirements
### Requirement: Urban PollingBackgroundService periodic upload

The MaterialClient.Urban application SHALL provide a `PollingBackgroundService` class in namespace `MaterialClient.Urban.Backgrounds` that extends Volo.Abp's `AsyncPeriodicBackgroundWorkerBase`. The worker SHALL scan locally persisted Urban weighing extensions with `SyncStatus == Pending` and invoke `IUrbanServerUploadService.SubmitRecordAsync` for each eligible record inside an ABP unit of work opened via `IUnitOfWorkManager`.

#### Scenario: Worker executes inside unit of work

- **WHEN** `DoWorkAsync` runs on a timer tick
- **THEN** the worker SHALL execute upload logic inside `WithUow` (or equivalent `IUnitOfWorkManager` scope)
- **AND** SHALL resolve `IUrbanWeighingExtensionService` and `IUrbanServerUploadService` from the worker's service scope

#### Scenario: Pending records are uploaded

- **WHEN** one or more `UrbanWeighingExtension` rows exist with `SyncStatus == Pending` and `IsAnomaly == false`
- **THEN** the worker SHALL call `GetPendingForUploadAsync` with a batch size bounded by configuration
- **AND** SHALL call `SubmitRecordAsync` for each returned `WeighingRecordId` in the batch

#### Scenario: Anomalous records are skipped

- **WHEN** a pending extension has `IsAnomaly == true`
- **THEN** the worker SHALL NOT call `SubmitRecordAsync` for that record

#### Scenario: Single record failure does not abort batch

- **WHEN** `SubmitRecordAsync` throws or returns failure for one record
- **THEN** the worker SHALL log the error
- **AND** SHALL continue processing remaining records in the same tick

### Requirement: Urban polling configuration

The Urban worker SHALL honor configuration for enablement, period, and batch size.

#### Scenario: Worker disabled by configuration

- **WHEN** `BackgroundServices:Polling` is `false`
- **THEN** `MaterialClientUrbanModule` SHALL NOT register `PollingBackgroundService`
- **AND** no periodic upload SHALL run

#### Scenario: Worker period from configuration

- **WHEN** `BackgroundServices:Polling` is `true` and `Urban:UploadPollingPeriodMs` is set
- **THEN** the worker's `Timer.Period` SHALL use the configured milliseconds value
- **AND** if the key is absent, the period SHALL default to 600000 (10 minutes)

#### Scenario: Batch size from configuration

- **WHEN** the worker queries pending uploads
- **THEN** it SHALL pass a take/limit derived from `Urban:UploadBatchSize`
- **AND** if the key is absent, the default batch size SHALL be 50

### Requirement: Urban module registers background worker

`MaterialClientUrbanModule` SHALL depend on `AbpBackgroundWorkersModule` and register the Urban `PollingBackgroundService` when polling is enabled.

#### Scenario: Module dependency includes background workers

- **WHEN** the ABP application initializes with `MaterialClientUrbanModule`
- **THEN** the module SHALL declare a dependency on `AbpBackgroundWorkersModule`

#### Scenario: Worker registered when polling enabled

- **WHEN** `BackgroundServices:Polling` is `true` during application initialization
- **THEN** the module SHALL register `MaterialClient.Urban.Backgrounds.PollingBackgroundService` via `AddBackgroundWorkerAsync`
- **AND** MUST NOT register `MaterialClient.Backgrounds.PollingBackgroundService` from the main application assembly

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

