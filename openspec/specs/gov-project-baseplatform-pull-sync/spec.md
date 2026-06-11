# Gov Project BasePlatform Pull Sync

## Purpose

Enables UrbanManagement to periodically pull project catalog data from BasePlatform.PublicApi and import new `GovProject` records with initialized license fields, using idempotent insert-only semantics within this change scope.

## Requirements

### Requirement: UrbanManagement periodically pulls project catalog from BasePlatform
UrbanManagement SHALL run a periodic background worker that calls BasePlatform.PublicApi project catalog endpoint to fetch project data (`ProId`, `ProName`) over HTTPS.

#### Scenario: Worker executes on configured interval
- **WHEN** `BasePlatformSync:Enabled` is true and `PullIntervalMinutes` is configured
- **THEN** the worker SHALL execute using the configured interval
- **AND** each execution SHALL call BasePlatform with configured `BaseUrl`, `ApiKey`, and `PageSize`

### Requirement: Sync inserts only new GovProject records
UrbanManagement sync logic SHALL insert only records whose `ProId` does not already exist in local `GovProject.Id`, and SHALL NOT update or delete existing rows.

#### Scenario: First pull inserts all unknown projects
- **WHEN** local `GovProject` table does not contain incoming `ProId` values
- **THEN** the sync SHALL insert new `GovProject` rows for all incoming records

#### Scenario: Repeated pull is idempotent
- **WHEN** a subsequent pull receives the same `ProId` set as existing local data
- **THEN** the sync SHALL insert zero rows
- **AND** the sync SHALL NOT modify existing `GovProject` fields

#### Scenario: Source project name changed remotely
- **WHEN** BasePlatform returns an existing `ProId` with changed `ProName`
- **THEN** UrbanManagement SHALL skip that record for update in this change scope

### Requirement: New records initialize license fields via provider abstraction
For each newly inserted `GovProject`, UrbanManagement SHALL initialize `BuildLicenseNo` and `FdBuildLicenseNo` through `IGovProjectInitFieldProvider`.

#### Scenario: Default provider returns placeholder constants
- **WHEN** default provider implementation is used
- **THEN** `BuildLicenseNo` SHALL be set from configured default constant
- **AND** `FdBuildLicenseNo` SHALL be set from configured default constant
- **AND** implementation SHALL retain `// TODO` markers for future real mapping logic

### Requirement: Pull sync handles paging and partial failures safely
UrbanManagement pull sync SHALL read remote data in pages and SHALL keep local consistency when remote calls fail.

#### Scenario: Multi-page pull for large dataset
- **WHEN** remote total records exceed one page size (for example ~1500 with page size 500)
- **THEN** sync SHALL continue paging until all pages are read
- **AND** merged remote set SHALL be used for deduplication and insert decisions

#### Scenario: Unauthorized or server failure from remote API
- **WHEN** remote API responds with 401 or 5xx during pull
- **THEN** worker SHALL log failure with actionable context
- **AND** worker SHALL stop current execution without writing partial inconsistent updates
- **AND** worker SHALL retry on next scheduled cycle
