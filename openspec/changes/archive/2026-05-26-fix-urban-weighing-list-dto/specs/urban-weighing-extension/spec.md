## MODIFIED Requirements

### Requirement: Query patterns for Urban extensions
The system SHALL provide Urban list, filter, and background-worker queries through `IUrbanWeighingExtensionService` (or methods it exposes), combining `WeighingRecord` and `UrbanWeighingExtension` data in application code. Queries MUST NOT rely on EF `Include` of a navigation property from `WeighingRecord` to `UrbanWeighingExtension`. Paged list queries intended for the Urban attended weighing UI MUST accept a single input DTO and return `PagedResultDto` of list item DTOs, not entity instances. Tab filtering for the attended weighing list MUST follow `urban-anomaly-detection` and use `IsAnomaly`, not `SyncStatus.Failed`.

#### Scenario: List query with extensions
- **WHEN** the Urban variant queries weighing records for display
- **THEN** `IUrbanWeighingExtensionService` MUST execute a join (or equivalent) by `WeighingRecordId` and project results to `UrbanWeighingListItemDto` (or equivalent)
- **AND** the DTO MUST include `IsAnomaly` from the extension row (default false when extension is missing in projection rules)
- **AND** records without an extension row MUST still be included where applicable with appropriate default fields on the DTO
- **AND** the query MUST filter parent records by `WeighingMode == UrbanMode`
- **AND** the service MUST NOT assign or expose `WeighingRecord.UrbanExtension` navigation for UI consumption

#### Scenario: Paged list API shape
- **WHEN** the Urban attended weighing ViewModel requests a page of list data
- **THEN** the service method MUST accept one `GetUrbanWeighingListInput` (or equivalent) containing pagination and filter fields
- **AND** the method MUST return `PagedResultDto<UrbanWeighingListItemDto>`
- **AND** callers MUST NOT receive `PagedResultDto<WeighingRecord>` for this UI list path

#### Scenario: Tab filter by IsAnomaly
- **WHEN** the Urban variant filters records by the「正常/异常/全部」tabs
- **THEN** the「正常」tab MUST filter `UrbanWeighingExtension.IsAnomaly == false`
- **AND** the「异常」tab MUST filter `UrbanWeighingExtension.IsAnomaly == true`
- **AND** the「全部」tab MUST show all Urban mode records without filtering on `IsAnomaly`
- **AND** the query MUST NOT use `SyncStatus == Failed` as the definition of the「异常」tab

#### Scenario: Background worker query
- **WHEN** the background sync worker scans for pending uploads
- **THEN** the query MUST filter `UrbanWeighingExtension` where `SyncStatus == Pending`
- **AND** the query MUST utilize the composite index on `(SyncStatus, WeighingRecordId)` for performance
