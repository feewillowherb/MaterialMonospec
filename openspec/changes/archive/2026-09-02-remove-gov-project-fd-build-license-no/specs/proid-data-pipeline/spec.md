## ADDED Requirements

### Requirement: GovProject excludes FdBuildLicenseNo from license pipeline
The proid-data-pipeline capability SHALL treat `BuildLicenseNo` as the sole persisted project-level access code on `GovProject`, `LicenseInfo`, JWT claims, and weighing submit DTOs. No entity in the weighing upload or project resolution pipeline SHALL persist or require `FdBuildLicenseNo`.

#### Scenario: Pipeline uses BuildLicenseNo only
- **WHEN** MaterialClient uploads a weighing record or UrbanManagement resolves a project for sync
- **THEN** the effective access code SHALL come from `BuildLicenseNo` / `buildLicenseNo`
- **AND** MUST NOT depend on a persisted `FdBuildLicenseNo` on any entity in the pipeline
