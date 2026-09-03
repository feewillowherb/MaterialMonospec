## ADDED Requirements

### Requirement: Weighing persist and output use CreationTime

The `UrbanWeighingRecords` table MUST store server ingestion time in column `CreationTime` (renamed from `AddTime` with values preserved). `UrbanWeighingRecordOutputDto` SHALL expose property `CreationTime` (JSON `creationTime`) mapped from `entity.CreationTime`. The output DTO MUST NOT expose `AddTime`. Receive input DTOs are unchanged (they do not carry ingestion time).

#### Scenario: List JSON uses creationTime

- **WHEN** `GetListAsync` returns a weighing record
- **THEN** the serialized item SHALL include `creationTime`
- **AND** MUST NOT include `addTime`

#### Scenario: Column rename preserves rows

- **WHEN** the rename migration runs
- **THEN** `UrbanWeighingRecords.CreationTime` SHALL exist
- **AND** `UrbanWeighingRecords.AddTime` MUST NOT exist
- **AND** row count MUST be unchanged
