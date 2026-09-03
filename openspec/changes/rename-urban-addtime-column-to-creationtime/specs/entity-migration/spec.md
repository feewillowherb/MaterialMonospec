## ADDED Requirements

### Requirement: Audited CreationTime column is CreationTime

UrbanManagement entities that inherit ABP audited bases (`GovProject`, `GovSyncData`, `UrbanWeighingRecord`, `AttachmentFile`) SHALL persist `CreationTime` in a database column named `CreationTime`. The EF model MUST NOT map `CreationTime` to a column named `AddTime`. A migration MUST rename existing `AddTime` columns to `CreationTime` while preserving values. Tables already using column `CreationTime` (including `UrbanPassageRecords`) MUST NOT be renamed.

#### Scenario: Column renamed with data preserved

- **WHEN** the EF migration for this change runs on a database that had column `AddTime` on `GovProjects`, `GovSyncData`, `UrbanWeighingRecords`, or `AttachmentFiles`
- **THEN** each such column SHALL be named `CreationTime`
- **AND** existing cell values MUST be preserved

#### Scenario: Fluent mapping has no AddTime alias

- **WHEN** `UrbanManagementDbContext` is inspected
- **THEN** it MUST NOT call `HasColumnName("AddTime")` on `CreationTime`
