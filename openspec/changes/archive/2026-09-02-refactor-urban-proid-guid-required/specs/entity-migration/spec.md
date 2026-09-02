## MODIFIED Requirements

### Requirement: GovSyncData entity uses ABP Entity base class
`GovSyncData` SHALL inherit from `Entity<int>` with properties including `ProId` as **non-nullable `Guid`** (legacy read-only rows). Other legacy string fields remain until a separate strong-type change. The entity SHALL NOT receive new inserts in Modern or Legacy WIP paths.

#### Scenario: GovSyncData ProId is Guid column

- **WHEN** the EF Core model for `GovSyncData` is configured
- **THEN** `ProId` SHALL map to a non-nullable Guid-compatible column
- **AND** historical string values SHALL be converted in migration where parseable

#### Scenario: Entity has no SqlSugar dependencies

- **WHEN** `GovSyncData.cs` is inspected
- **THEN** it SHALL NOT import any `SqlSugar` namespace
