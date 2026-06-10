## ADDED Requirements

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
