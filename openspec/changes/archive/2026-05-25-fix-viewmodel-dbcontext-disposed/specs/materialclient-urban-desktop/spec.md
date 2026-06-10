## MODIFIED Requirements

### Requirement: Use Common entities in Urban ViewModel

The Urban ViewModel MUST use `MaterialClient.Common.Entities.WeighingRecord` directly, MUST NOT use local duplicate entity models. The ViewModel MUST NOT directly inject `IRepository<WeighingRecord, long>` or any other Repository — all data access SHALL go through `IWeighingRecordService`.

#### Scenario: ViewModel imports Common entity
- **WHEN** the ViewModel references a weighing record
- **THEN** it SHALL use `MaterialClient.Common.Entities.WeighingRecord`
- **AND** MUST NOT import from `MaterialClient.Urban.Models`

#### Scenario: XAML bindings use Common entity properties
- **WHEN** the XAML binds to a weighing record
- **THEN** plate number SHALL bind to `PlateNumber` property
- **AND** weight SHALL bind to `TotalWeight` property
- **AND** time SHALL bind to `AddDate` property
- **AND** status SHALL derive from `SyncStatus` enum

#### Scenario: ViewModel uses Service for data access
- **WHEN** the ViewModel needs to query weighing records
- **THEN** it SHALL use `IWeighingRecordService.GetPagedUrbanWeighingRecordsAsync`
- **AND** MUST NOT inject `IRepository<WeighingRecord, long>` or any Repository
- **AND** MUST NOT import `Volo.Abp.Domain.Repositories`
- **AND** MUST NOT import `Microsoft.EntityFrameworkCore`
