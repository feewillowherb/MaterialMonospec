## MODIFIED Requirements

### Requirement: Sync inserts only new GovProject records

UrbanManagement sync logic SHALL insert records whose `ProId` does not already exist in local `GovProject.Id`. For existing records, sync SHALL update all catalog-sourced fields from the API response (`ProName`, `ProAddress`, `ShigongUnitName`, access-code / license fields, `AuthEndTime`) and SHALL NOT update local operational fields (**`IsSyncEnabled`**, `AddTime`, soft-delete state).

#### Scenario: First pull inserts all unknown projects

- **WHEN** local `GovProject` table does not contain incoming `ProId` values
- **THEN** the sync SHALL insert new `GovProject` rows for all incoming records with all catalog-sourced fields populated
- **AND** `IsSyncEnabled` SHALL be initialized to `false`

#### Scenario: Repeated pull updates all catalog fields for existing records

- **WHEN** a subsequent pull receives an existing `ProId` with any changed catalog-sourced field
- **THEN** the sync SHALL update catalog-sourced fields from the API response
- **AND** the sync SHALL insert zero new rows for that `ProId`
- **AND** the sync SHALL NOT modify `IsSyncEnabled`, `AddTime`, `IsDeleted`, or `DeletionTime`

#### Scenario: Repeated pull is idempotent when remote data unchanged

- **WHEN** a subsequent pull receives existing `ProId` values with identical catalog-sourced field values
- **THEN** the sync SHALL insert zero rows
- **AND** the sync MAY perform no-op updates for unchanged records

#### Scenario: Source project name changed remotely

- **WHEN** BasePlatform returns an existing `ProId` with changed `ProName`
- **THEN** UrbanManagement SHALL update local `ProName` to match the remote value
- **AND** SHALL leave `IsSyncEnabled` unchanged
