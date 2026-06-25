# gov-project-baseplatform-pull-sync Delta Specification

## MODIFIED Requirements

### Requirement: UrbanManagement periodically pulls project catalog from BasePlatform
UrbanManagement SHALL run a periodic background worker that calls BasePlatform.PublicApi project catalog endpoint to fetch project data (`ProId`, `ProName`, `AccessCode`, `MachineCode`, `AuthToken`, `ProAddress`, `ShigongUnitName`, `BuildLicenseNo`, `FdBuildLicenseNo`, `AuthEndTime`) over HTTPS.

#### Scenario: Worker executes on configured interval
- **WHEN** `BasePlatformSync:Enabled` is true and `PullIntervalMinutes` is configured
- **THEN** the worker SHALL execute using the configured interval
- **AND** each execution SHALL call BasePlatform with configured `BaseUrl`, `ApiKey`, and `PageSize`
- **AND** the response SHALL include `AccessCode`, `MachineCode`, and `AuthToken` fields (new in this change)

### Requirement: Sync inserts only new GovProject records
UrbanManagement sync logic SHALL insert only records whose `ProId` does not already exist in local `GovProject.Id`, and for existing ProIds, SHALL update all catalog fields if they have changed.

#### Scenario: First pull inserts all unknown projects
- **WHEN** local `GovProject` table does not contain incoming `ProId` values
- **THEN** the sync SHALL insert new `GovProject` rows for all incoming records
- **AND** new records SHALL include `AccessCode`, `MachineCode`, and `AuthToken` fields from BasePlatform response

#### Scenario: Repeated pull updates existing projects
- **WHEN** a subsequent pull receives existing `ProId` records with changed field values
- **THEN** the sync SHALL update `GovProject` fields that have changed (including `AccessCode`, `MachineCode`, `AuthToken`)
- **AND** the sync SHALL use `ApplyRemoteFieldsIfChanged` method to compare and update fields
- **AND** the sync SHALL skip update if all values are identical (idempotent)

#### Scenario: Source project fields changed remotely
- **WHEN** BasePlatform returns an existing `ProId` with changed `ProName`, `AccessCode`, or other catalog fields
- **THEN** UrbanManagement SHALL update those fields in the local `GovProject` record
- **AND** the sync SHALL log the updated fields for audit purposes

### Requirement: New records initialize license fields from BasePlatform response
For each newly inserted `GovProject`, UrbanManagement SHALL initialize `AccessCode`, `MachineCode`, and `AuthToken` directly from BasePlatform PublicApi response fields, NOT through `IGovProjectInitFieldProvider`.

#### Scenario: BasePlatform response provides all required fields
- **WHEN** BasePlatform PublicApi returns `ProjectCatalogItemResponse` with `accessCode`, `machineCode`, `authToken` fields
- **THEN** `AccessCode` SHALL be set from `remote.AccessCode` (not `remote.BuildLicenseNo`)
- **AND** `MachineCode` SHALL be set from `remote.MachineCode`
- **AND** `AuthToken` SHALL be set from `remote.AuthToken`
- **AND** `IGovProjectInitFieldProvider` SHALL NOT be used (deprecated)

#### Scenario: BasePlatform response missing optional fields
- **WHEN** BasePlatform PublicApi returns null or empty `accessCode`, `machineCode`, or `authToken`
- **THEN** the corresponding `GovProject` fields SHALL be set to null
- **AND** the insert SHALL succeed (fields are nullable)
- **AND** the sync SHALL log a warning about missing fields

### Requirement: Pull sync handles paging and partial failures safely
UrbanManagement pull sync SHALL read remote data in pages and SHALL keep local consistency when remote calls fail, with support for normalizing invalid items and logging validation results.

#### Scenario: Multi-page pull for large dataset
- **WHEN** remote total records exceed one page size (for example ~1500 with page size 500)
- **THEN** sync SHALL continue paging until all pages are read
- **AND** merged remote set SHALL be used for deduplication and insert decisions
- **AND** each page SHALL be normalized to filter invalid items (e.g., wrong `ProductCode`)

#### Scenario: ProductCode validation during normalization
- **WHEN** `NormalizeRemoteItems` processes `ProjectCatalogItemResponse` items
- **THEN** items with `ProductCode != 5001` (Urban) SHALL be filtered out
- **AND** filtered items SHALL increment `InvalidCount`
- **AND** filtered items SHALL be logged with `ProId` and `ProductCode` for debugging

#### Scenario: Unauthorized or server failure from remote API
- **WHEN** remote API responds with 401 or 5xx during pull
- **THEN** worker SHALL log failure with actionable context
- **AND** worker SHALL stop current execution without writing partial inconsistent updates
- **AND** worker SHALL retry on next scheduled cycle

## REMOVED Requirements

### Requirement: Legacy BuildLicenseNo mapping
**Reason**: Replaced by AccessCode field mapping for clearer data semantics
**Migration**: All code reading `BuildLicenseNo` from BasePlatform response SHALL be updated to read `AccessCode` instead. The `BuildLicenseNo` field in `ProjectCatalogItemResponse` SHALL be ignored during sync (but kept for government protocol compatibility).

#### Scenario: Old BuildLicenseNo mapping removed
- **WHEN** `GovProjectPullManager` processes `ProjectCatalogItemResponse`
- **THEN** the system SHALL NOT read `remote.BuildLicenseNo` for `AccessCode` assignment
- **AND** the system SHALL read `remote.AccessCode` instead
- **AND** `BuildLicenseNo` field in response MAY be used for protocol compatibility only
