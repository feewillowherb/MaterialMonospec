## MODIFIED Requirements

### Requirement: Legacy reject staging table

When Legacy ingest cannot create an `UrbanWeighingRecord` (missing access code, unknown AccessCode, parse failure, or pre-receive validation failure), UrbanManagement MUST NOT insert into `LegacyWeighingRejectStaging` (or any reject staging table). The service SHALL emit a diagnostic log that includes reject reason, attempted access code, plate if present, snap image **count** (MUST NOT include Base64 image bodies), and a de-imaged business payload JSON. The HTTP response MUST still report failure (`success = false`); logging MUST NOT be treated as business success.

#### Scenario: Unknown access code rejects without staging

- **WHEN** `buildLicenseNo` does not match any `GovProject.AccessCode`
- **THEN** the system MUST NOT insert a reject staging row
- **AND** MUST NOT create `UrbanWeighingRecord`
- **AND** SHALL log the reject with de-imaged payload and without Base64 images
- **AND** the response SHALL have `success = false` with a message indicating the access code is not registered

#### Scenario: Successful ingest does not write staging

- **WHEN** Legacy ingest succeeds and creates an `UrbanWeighingRecord`
- **THEN** the system MUST NOT insert a reject staging row for that request
