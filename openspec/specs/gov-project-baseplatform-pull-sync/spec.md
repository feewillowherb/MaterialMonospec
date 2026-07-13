# gov-project-baseplatform-pull-sync Specification

## Purpose
TBD - created by archiving change sync-gov-project-from-baseplatform-publicapi. Update Purpose after archive.
## Requirements
### Requirement: UrbanManagement periodically pulls project catalog from BasePlatform

UrbanManagement SHALL run a periodic background worker that calls BasePlatform.PublicApi project catalog endpoint to fetch project data over HTTPS. The fetched payload SHALL include `ProId`, `ProName`, `ProductCode`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `FdBuildLicenseNo`, and `AuthEndTime`.

#### Scenario: Worker executes on configured interval

- **WHEN** `BasePlatformSync:Enabled` is true and `PullIntervalMinutes` is configured

- **THEN** the worker SHALL execute using the configured interval

- **AND** each execution SHALL call BasePlatform with configured `BaseUrl`, `ApiKey`, and `PageSize`

### Requirement: Sync inserts only new GovProject records

UrbanManagement sync logic SHALL insert records whose `ProId` does not already exist in local `GovProject.Id`. For existing records, sync SHALL update all catalog-sourced fields from the API response (`ProName`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `FdBuildLicenseNo`, `AuthEndTime`) and SHALL NOT update local operational fields (`EnableSync`, `AddTime`, soft-delete state).

#### Scenario: First pull inserts all unknown projects

- **WHEN** local `GovProject` table does not contain incoming `ProId` values

- **THEN** the sync SHALL insert new `GovProject` rows for all incoming records with all catalog-sourced fields populated

#### Scenario: Repeated pull updates all catalog fields for existing records

- **WHEN** a subsequent pull receives an existing `ProId` with any changed catalog-sourced field

- **THEN** the sync SHALL update `ProName`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `FdBuildLicenseNo`, and `AuthEndTime` from the API response

- **AND** the sync SHALL insert zero new rows for that `ProId`

- **AND** the sync SHALL NOT modify `EnableSync`, `AddTime`, `IsDeleted`, or `DeletionTime`

#### Scenario: Repeated pull is idempotent when remote data unchanged

- **WHEN** a subsequent pull receives existing `ProId` values with identical catalog-sourced field values

- **THEN** the sync SHALL insert zero rows

- **AND** the sync MAY perform no-op updates for unchanged records

#### Scenario: Source project name changed remotely

- **WHEN** BasePlatform returns an existing `ProId` with changed `ProName`

- **THEN** UrbanManagement SHALL update local `ProName` to match the remote value

### Requirement: New records initialize license fields via provider abstraction

For each newly inserted `GovProject`, UrbanManagement SHALL populate `BuildLicenseNo`, `FdBuildLicenseNo`, and `AuthEndTime` directly from the BasePlatform catalog API response fields of the same names (camelCase JSON: `buildLicenseNo`, `fdBuildLicenseNo`, `authEndTime`). For existing records, pull sync SHALL update these same fields from the API response.

#### Scenario: Sync maps license fields from API response on insert

- **WHEN** pull sync inserts a new `GovProject` from a catalog item

- **THEN** `BuildLicenseNo` SHALL be set from `buildLicenseNo`

- **AND** `FdBuildLicenseNo` SHALL be set from `fdBuildLicenseNo`

- **AND** `AuthEndTime` SHALL be set from `authEndTime`

#### Scenario: Sync updates license fields from API response on existing record

- **WHEN** pull sync updates an existing `GovProject` from a catalog item

- **THEN** `BuildLicenseNo` SHALL be updated from `buildLicenseNo`

- **AND** `FdBuildLicenseNo` SHALL be updated from `fdBuildLicenseNo`

- **AND** `AuthEndTime` SHALL be updated from `authEndTime`

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

### Requirement: Sync validates product code at boundary without persisting

UrbanManagement SHALL validate remote catalog `productCode` at the pull-sync boundary against `ProductCode.Urban` (5001) and SHALL NOT persist `productCode` on `GovProject`.

#### Scenario: Urban product code accepted

- **WHEN** pull sync receives a catalog item with `productCode = 5001`

- **THEN** the sync SHALL proceed with insert or full catalog-field update processing for that item

- **AND** SHALL NOT write `productCode` to any `GovProject` database column

#### Scenario: Non-Urban product code is skipped

- **WHEN** pull sync receives a catalog item with `productCode` not equal to `5001`

- **THEN** the sync SHALL NOT insert or update a `GovProject` for that item

- **AND** SHALL log a warning including `proId` and the unexpected `productCode`

### Requirement: Sync persists project address and construction unit name

UrbanManagement SHALL persist `ProAddress` and `ShigongUnitName` from the catalog API when inserting new `GovProject` records and when updating existing records during pull sync.

#### Scenario: Address and unit name mapped on insert

- **WHEN** pull sync inserts a new `GovProject` from a catalog item containing `proAddress` and `shigongUnitName`

- **THEN** `GovProject.ProAddress` SHALL be set from `proAddress`

- **AND** `GovProject.ShigongUnitName` SHALL be set from `shigongUnitName`

#### Scenario: Address and unit name updated on sync for existing record

- **WHEN** pull sync updates an existing local `GovProject` from a catalog item

- **THEN** `GovProject.ProAddress` SHALL be updated from `proAddress`

- **AND** `GovProject.ShigongUnitName` SHALL be updated from `shigongUnitName`

