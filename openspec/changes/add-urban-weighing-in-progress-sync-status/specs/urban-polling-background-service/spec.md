## MODIFIED Requirements

### Requirement: Urban PollingBackgroundService periodic upload

The MaterialClient.Urban application SHALL provide a `PollingBackgroundService` class in namespace `MaterialClient.Urban.Backgrounds` that extends Volo.Abp's `AsyncPeriodicBackgroundWorkerBase`. The worker SHALL scan locally persisted Urban weighing extensions with `SyncStatus == Pending` and invoke `IUrbanServerUploadService.SubmitRecordAsync` for each eligible record inside an ABP unit of work opened via `IUnitOfWorkManager`. Extensions in `SyncStatus.WeighingInProgress` MUST NOT be selected or uploaded.

#### Scenario: Worker executes inside unit of work

- **WHEN** `DoWorkAsync` runs on a timer tick
- **THEN** the worker SHALL execute upload logic inside `WithUow` (or equivalent `IUnitOfWorkManager` scope)
- **AND** SHALL resolve `IUrbanWeighingExtensionService` and `IUrbanServerUploadService` from the worker's service scope

#### Scenario: Pending records are uploaded

- **WHEN** one or more `UrbanWeighingExtension` rows exist with `SyncStatus == Pending`
- **THEN** the worker SHALL call `GetPendingForUploadAsync` with a batch size bounded by configuration
- **AND** SHALL call `SubmitRecordAsync` for each returned `WeighingRecordId` in the batch

#### Scenario: WeighingInProgress records are not uploaded

- **WHEN** an `UrbanWeighingExtension` has `SyncStatus == WeighingInProgress`
- **THEN** `GetPendingForUploadAsync` MUST NOT return that extension
- **AND** the worker MUST NOT call `SubmitRecordAsync` for that record

#### Scenario: Single record failure does not abort batch

- **WHEN** `SubmitRecordAsync` throws or returns failure for one record
- **THEN** the worker SHALL log the error
- **AND** SHALL continue processing remaining records in the same tick
