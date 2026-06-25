## ADDED Requirements

### Requirement: Sync persists project address and construction unit name
UrbanManagement SHALL persist `ProAddress` and `ShigongUnitName` from the catalog API when inserting new `GovProject` records and when updating existing records during pull sync.

#### Scenario: Address and unit name mapped on insert
- **WHEN** pull sync inserts a new `GovProject` from a catalog item containing `proAddress` and `shigongUnitName`
- **THEN** `GovProject.ProAddress` SHALL be set from `proAddress`
- **AND** `GovProject.ShigongUnitName` SHALL be set from `shigongUnitName`
