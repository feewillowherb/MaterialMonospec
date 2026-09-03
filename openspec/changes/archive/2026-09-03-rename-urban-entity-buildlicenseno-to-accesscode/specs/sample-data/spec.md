## MODIFIED Requirements

### Requirement: SampleDataProvider returns hardcoded sync data

`SampleDataProvider` SHALL return at least 5 sample `GovSyncData` records with varied SyncType values (Pending, Success, Failed), associated ProName and **AccessCode** (entity property; MUST NOT use entity property name `BuildLicenseNo`).

#### Scenario: Sync data includes various statuses

- **WHEN** `GetPagedSyncDataAsync(1, 10)` is called
- **THEN** the result SHALL contain records with SyncType values of 0, 1, and 2

#### Scenario: Sync data includes image references

- **WHEN** a sample sync data record is inspected
- **THEN** `SnapImages` SHALL contain at least one image path (can be placeholder)

#### Scenario: Sync data uses AccessCode on entity

- **WHEN** a sample `GovSyncData` record is constructed
- **THEN** the access-code field SHALL be set on property `AccessCode`
- **AND** the entity type MUST NOT expose `BuildLicenseNo`

## ADDED Requirements

### Requirement: GovSyncData entity column AccessCode

The `GovSyncData` entity SHALL persist the site access code as `AccessCode`. The database column MUST be renamed from `BuildLicenseNo` to `AccessCode` with values preserved. Historical rows remain read-only per existing initiative rules; this change MUST NOT resume inserts into `GovSyncData`.

#### Scenario: Column rename preserves values

- **WHEN** migration renames `GovSyncData.BuildLicenseNo` to `AccessCode`
- **THEN** existing values MUST remain readable via `AccessCode`
