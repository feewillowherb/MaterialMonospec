## ADDED Requirements

### Requirement: GovProject IsSyncEnabled is non-nullable bool

`GovProject` SHALL expose **`IsSyncEnabled`** as a non-nullable `bool` with default `false`. The database column MUST be named `IsSyncEnabled` (renamed from `EnableSync`). Historical NULL values MUST become `false` before the non-nullable constraint. The entity MUST NOT retain an `EnableSync` property.

#### Scenario: New project defaults sync off

- **WHEN** a `GovProject` is created via create or pull insert
- **THEN** `IsSyncEnabled` SHALL be `false` unless explicitly set otherwise

#### Scenario: Migration renames column and clears nulls

- **WHEN** the rename migration runs
- **THEN** former `EnableSync` NULL rows SHALL become `false`
- **AND** the persisted column name SHALL be `IsSyncEnabled`
