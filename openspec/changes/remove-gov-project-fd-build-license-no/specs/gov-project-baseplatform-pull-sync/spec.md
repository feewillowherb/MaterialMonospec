## MODIFIED Requirements

### Requirement: UrbanManagement periodically pulls project catalog from BasePlatform

UrbanManagement SHALL run a periodic background worker that calls BasePlatform.PublicApi project catalog endpoint to fetch project data over HTTPS. The fetched payload MAY include `fdBuildLicenseNo` in the wire format, but UrbanManagement MUST NOT persist `FdBuildLicenseNo` on `GovProject`. Persisted catalog fields SHALL include `ProId`, `ProName`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, and `AuthEndTime`.

#### Scenario: Worker executes on configured interval

- **WHEN** `BasePlatformSync:Enabled` is true and `PullIntervalMinutes` is configured

- **THEN** the worker SHALL execute using the configured interval

- **AND** each execution SHALL call BasePlatform with configured `BaseUrl`, `ApiKey`, and `PageSize`

### Requirement: Sync inserts only new GovProject records

UrbanManagement sync logic SHALL insert records whose `ProId` does not already exist in local `GovProject.Id`. For existing records, sync SHALL update all catalog-sourced fields from the API response (`ProName`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `AuthEndTime`) and SHALL NOT update local operational fields (`EnableSync`, `AddTime`, soft-delete state). Sync MUST NOT persist `FdBuildLicenseNo`.

#### Scenario: First pull inserts all unknown projects

- **WHEN** local `GovProject` table does not contain incoming `ProId` values

- **THEN** the sync SHALL insert new `GovProject` rows for all incoming records with all catalog-sourced fields populated except `FdBuildLicenseNo`

#### Scenario: Repeated pull updates all catalog fields for existing records

- **WHEN** a subsequent pull receives an existing `ProId` with any changed catalog-sourced field

- **THEN** the sync SHALL update `ProName`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, and `AuthEndTime` from the API response

- **AND** the sync SHALL insert zero new rows for that `ProId`

- **AND** the sync SHALL NOT modify `EnableSync`, `AddTime`, `IsDeleted`, or `DeletionTime`

- **AND** MUST NOT write `FdBuildLicenseNo`

#### Scenario: Repeated pull is idempotent when remote data unchanged

- **WHEN** a subsequent pull receives existing `ProId` values with identical catalog-sourced field values

- **THEN** the sync SHALL insert zero rows

- **AND** the sync MAY perform no-op updates for unchanged records

#### Scenario: Source project name changed remotely

- **WHEN** BasePlatform returns an existing `ProId` with changed `ProName`

- **THEN** UrbanManagement SHALL update local `ProName` to match the remote value

### Requirement: New records initialize license fields via provider abstraction

For each newly inserted `GovProject`, UrbanManagement SHALL populate `BuildLicenseNo` and `AuthEndTime` directly from the BasePlatform catalog API response fields (`buildLicenseNo`, `authEndTime`). For existing records, pull sync SHALL update these same fields from the API response. Pull sync MUST ignore `fdBuildLicenseNo` for persistence.

#### Scenario: Sync maps license fields from API response on insert

- **WHEN** pull sync inserts a new `GovProject` from a catalog item

- **THEN** `BuildLicenseNo` SHALL be set from `buildLicenseNo`

- **AND** `AuthEndTime` SHALL be set from `authEndTime`

- **AND** MUST NOT set `FdBuildLicenseNo`

#### Scenario: Sync updates license fields from API response on existing record

- **WHEN** pull sync updates an existing `GovProject` from a catalog item

- **THEN** `BuildLicenseNo` SHALL be updated from `buildLicenseNo`

- **AND** `AuthEndTime` SHALL be updated from `authEndTime`

- **AND** MUST NOT update or create `FdBuildLicenseNo`
