# urban-passage-cloud Specification

## Purpose
TBD - created by archiving change add-urbanmanagement-passage-xiaoshan-upload. Update Purpose after archive.
## Requirements
### Requirement: UrbanManagement persists passage without weight

UrbanManagement SHALL persist checkpoint and finished-product rows as one entity (`UrbanPassageRecord` or equivalent) on `UrbanManagementDbContext`. The entity MUST NOT include a weight column. Source MUST be `PassageSource` checkpoint or finished-product. `UrbanInOutType` and `UrbanSiteType` MUST be stored as snapshots. Attachments MUST use logical ids with no database foreign keys or relationship navigations.

#### Scenario: One table two sources

- **WHEN** a checkpoint ingest and a finished-product ingest succeed
- **THEN** both MUST be rows of the same entity type
- **AND** MUST differ by `PassageSource`
- **AND** MUST NOT insert `UrbanWeighingRecord`

### Requirement: Independent ingest APIs from LPR checkpoint and LPR product

The system SHALL expose two ApplicationService write APIs: one for LPR checkpoint ingest and one for LPR finished-product ingest. Each API MUST create rows only of its `PassageSource`. Creation MUST use a type-owned factory. Services MUST NOT assign entity fields line by line. Writes MUST use `[UnitOfWork]`. The APIs MUST NOT share one receive method that branches on weight or `buildLicenseNo` suffix.

#### Scenario: Checkpoint ingest does not hit weighing receive

- **WHEN** the client posts a checkpoint passage payload to the checkpoint ingest API
- **THEN** the system MUST insert a checkpoint passage row
- **AND** MUST NOT call `UrbanWeighingRecordAppService.ReceiveAsync` for that payload

#### Scenario: Product ingest is a separate service

- **WHEN** the client posts a finished-product passage payload
- **THEN** the finished-product ApplicationService MUST handle it
- **AND** MUST NOT reuse the checkpoint ApplicationService method with a source flag

### Requirement: Checkpoint page and finished-product page

UrbanManagement SHALL add a checkpoint list page and a finished-product list page, not mixed into weighing approval. Each page MUST filter the passage entity by that `PassageSource`. Columns MUST include plate (store「无」shown as「未识别」), plate color, vehicle type, in/out, site type, captured time, large photo only, and Gov sync status if weighing lists show sync status. Pages MUST NOT show weight or weighing approval actions. UI MUST call ApplicationService only, never Repository or DbContext.

#### Scenario: Checkpoint page filter

- **WHEN** an operator opens the checkpoint page
- **THEN** the list MUST contain only checkpoint passage rows
- **AND** MUST NOT list finished-product or weighing rows

### Requirement: UrbanPassageRecord persists AccessCode

The `UrbanPassageRecord` entity SHALL expose the site access code as property `AccessCode` (`string?`). The database column MUST be named `AccessCode` (renamed from legacy `BuildLicenseNo`, values preserved). The entity MUST NOT expose `BuildLicenseNo`. Type-owned factories MUST assign `AccessCode` from ingest input that MAY still be named `BuildLicenseNo` on the DTO. Ingest JSON MAY keep `buildLicenseNo`.

#### Scenario: Entity property is AccessCode

- **WHEN** a checkpoint or finished-product passage row is created
- **THEN** the entity SHALL persist `AccessCode`
- **AND** MUST NOT expose `BuildLicenseNo` on the entity type

#### Scenario: Factory maps DTO BuildLicenseNo to AccessCode

- **WHEN** a passage factory receives input with `BuildLicenseNo` set
- **THEN** the created `UrbanPassageRecord.AccessCode` SHALL equal that value

#### Scenario: Column renamed with data preserved

- **WHEN** the EF migration runs on a database with passage column `BuildLicenseNo`
- **THEN** the column SHALL be renamed to `AccessCode`
- **AND** existing values MUST be preserved

