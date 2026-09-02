## MODIFIED Requirements

### Requirement: DTO mapping for sync data

The system SHALL provide `GovSyncDataDto` with entity mapping methods for data transfer operations. `SnapTime` SHALL be `DateTime?` and `GoodsWeight` SHALL be `decimal?`, matching the entity. Mapping MUST NOT treat these fields as strings.

#### Scenario: FromEntity mapping with strong types

- **WHEN** calling `GovSyncDataDto.FromEntity(entity)`
- **THEN** system creates DTO with `SnapTime` and `GoodsWeight` copied as `DateTime?` and `decimal?` respectively
- **AND** other fields continue to map as before (`ProId` as `Guid`, `SyncType` as `SyncStatus`, `RetryCount` as `int`, etc.)

#### Scenario: Read-only list API exposes strong types

- **WHEN** a client queries `GovSyncData` via `GovSyncDataAppService` list/get
- **THEN** the JSON payload SHALL serialize `snapTime` as a date-time (or null) and `goodsWeight` as a number (or null)
- **AND** MUST NOT serialize those two fields as free-form weight/time strings for newly mapped DTOs
