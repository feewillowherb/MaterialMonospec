## ADDED Requirements

### Requirement: GovSyncData SnapTime and GoodsWeight are strongly typed

`GovSyncData` SHALL expose **`SnapTime`** as `DateTime?` and **`GoodsWeight`** as `decimal?`. The database columns MUST retain the same names. Historical string values MUST be migrated by best-effort parse; values that cannot be parsed MUST become `NULL`. The entity MUST NOT keep these two properties as `string?`. The table remains **read-only** for new business inserts (no new rows from modern or Legacy paths as established by prior changes).

#### Scenario: Entity property types

- **WHEN** `GovSyncData.cs` is inspected
- **THEN** `SnapTime` SHALL be `DateTime?`
- **AND** `GoodsWeight` SHALL be `decimal?`

#### Scenario: Migration parses or nulls historical strings

- **WHEN** the strong-type migration runs against existing `GovSyncData` rows
- **THEN** parseable `SnapTime` strings SHALL become `DateTime` values
- **AND** parseable `GoodsWeight` strings SHALL become `decimal` values
- **AND** unparseable values SHALL become `NULL`
- **AND** column names SHALL remain `SnapTime` and `GoodsWeight`

#### Scenario: Fluent configuration matches types

- **WHEN** `UrbanManagementDbContext` configures `GovSyncData`
- **THEN** it MUST NOT apply string `HasMaxLength` constraints to `SnapTime` or `GoodsWeight`
