## MODIFIED Requirements

### Requirement: Common is the kernel baseline assembly

`MaterialClient.Common` SHALL contain kernel domain entities, kernel Service APIs, and shared non-product infrastructure. It MUST NOT contain Urban, Recycle, Standard, or SolidWaste product entities, product `DbContext` types, or product EF migrations.

#### Scenario: Standard host does not reference product Common

- **WHEN** the standard `MaterialClient` executable project is inspected
- **THEN** it MUST NOT have a `ProjectReference` to `MaterialClient.Common.Urban`, `MaterialClient.Common.Recycle`, or `MaterialClient.Common.SolidWaste`

#### Scenario: Kernel assembly has no product persistence types

- **WHEN** `MaterialClient.Common` is compiled for the standard host
- **THEN** it MUST NOT expose `UrbanDbContext`, `RecycleDbContext`, `StandardDbContext`, or `SolidWasteDbContext`
- **AND** MUST NOT map product extension entities in the kernel model

### Requirement: Product Common assemblies own customization

The system SHALL provide `MaterialClient.Common.Urban`, `MaterialClient.Common.Recycle`, `MaterialClient.Common.Standard`, and `MaterialClient.Common.SolidWaste` class libraries that contain the corresponding product entities, product `DbContext`, product migrations, and product Service interfaces and implementations. Product WinExe projects SHALL compose UI and host modules only and MUST NOT own product table Fluent mappings.

#### Scenario: Urban product Common is loaded only by Urban host

- **WHEN** `MaterialClient.Urban` initializes ABP
- **THEN** it SHALL depend on `MaterialClientCommonUrbanModule` (or equivalent module in `MaterialClient.Common.Urban`)
- **AND** `MaterialClient.UI` MUST NOT reference `MaterialClient.Common.Urban`

#### Scenario: Recycle product Common is loaded only by Recycle host

- **WHEN** `MaterialClient.Recycle` initializes ABP
- **THEN** it SHALL depend on the Recycle product Common module
- **AND** MUST NOT depend on `MaterialClient.Common.Urban`

#### Scenario: SolidWaste product Common is loaded only by SolidWaste host

- **WHEN** `MaterialClient.SolidWaste` initializes ABP
- **THEN** it SHALL depend on the SolidWaste product Common module
- **AND** the standard `MaterialClient` host MUST NOT depend on that module

#### Scenario: New product follows the same layer

- **WHEN** a future product client is added
- **THEN** product tables and product Service APIs SHALL be added as `MaterialClient.Common.{Product}`
- **AND** MUST NOT be added under `MaterialClient.Common` entity folders
