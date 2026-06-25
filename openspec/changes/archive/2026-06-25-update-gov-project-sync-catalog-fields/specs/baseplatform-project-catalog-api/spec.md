## MODIFIED Requirements

### Requirement: Project catalog API provides paged ProId and ProName
The `FdSoft.BasePlatform.PublicApi` system SHALL provide a read-only endpoint `GET /Api/ProjectCatalog/ListProjects` that returns paged project catalog data for projects authorized with `ProductCode = 5001` (Urban). Each item SHALL include `proId`, `proName`, `productCode`, `proAddress`, `shigongUnitName`, `buildLicenseNo`, `fdBuildLicenseNo`, and `authEndTime`.

#### Scenario: Return paged project catalog
- **WHEN** an authorized client calls `/Api/ProjectCatalog/ListProjects?pageIndex=1&pageSize=500`
- **THEN** the API SHALL return a success response containing `totalCount` and `items`
- **AND** each item SHALL include `proId`, `proName`, `productCode`, `proAddress`, `shigongUnitName`, `buildLicenseNo`, `fdBuildLicenseNo`, and `authEndTime`
- **AND** each item's `productCode` SHALL be `5001`
- **AND** the API SHALL NOT include sensitive fields such as secret or organization codes

#### Scenario: Exclude projects without Urban product authorization
- **WHEN** a project exists in `JC_Project` but has no `JC_ProductAuthority` row with `ProductCode = 5001`, non-empty `MachineCode`, and `DeleteStatus = 0`
- **THEN** that project SHALL NOT appear in catalog `items`
