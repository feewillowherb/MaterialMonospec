## ADDED Requirements

### Requirement: Legacy Post converts to UrbanWeighingRecord

`LegacyGovSyncAppService` SHALL accept legacy weighing payloads (萧山/`mGovRequestWeight` shape), resolve `GovProject` by `buildLicenseNo` as `AccessCode`, persist images via `IFileService` with `AttachType.Lpr` for every image, invoke `IUrbanWeighingRecordAppService.ReceiveAsync` with `IngestSource = Legacy` and a new `ClientRecordId` (`Guid.NewGuid()`), and MUST NOT insert into `GovSyncData`. The service MUST ignore `fdBuildLicenseNo` (no lookup, no mapping onto AccessCode).

#### Scenario: Successful legacy ingest

- **WHEN** a client POSTs a valid body with non-empty `buildLicenseNo` matching a UM `GovProject.AccessCode` and one or more `snapImages`
- **THEN** the system SHALL create AttachmentFile rows with `AttachType.Lpr`
- **AND** SHALL create an `UrbanWeighingRecord` with `IngestSource = Legacy`, `AccessCode` equal to that code, and non-empty `ClientRecordId`
- **AND** MUST NOT insert into `GovSyncData`
- **AND** the HTTP response SHALL indicate success in the legacy `{ success, msg, code }` shape with `code` 200

#### Scenario: Gross weight overrides goods weight

- **WHEN** the payload includes `grossWeight` greater than 0 and a `goodsWeight` value
- **THEN** the persisted `TotalWeight` SHALL equal the kilogram value derived from `grossWeight` (same priority as historical XiaoShanServe)

#### Scenario: fdBuildLicenseNo ignored

- **WHEN** the payload includes only `fdBuildLicenseNo` and empty `buildLicenseNo`
- **THEN** the system SHALL treat the request as rejected (missing access code)
- **AND** MUST NOT resolve a project via any凡东码 table

### Requirement: Legacy reject staging table

When Legacy ingest cannot create an `UrbanWeighingRecord` (missing access code, unknown AccessCode, parse failure, or pre-receive validation failure), UrbanManagement SHALL insert a row into a temporary reject staging entity (e.g. `LegacyWeighingRejectStaging`) that stores reject reason, attempted codes, plate if present, and snap image Base64 payload. The staging table MUST NOT have business indexes beyond the primary key. The HTTP response MUST still report failure (`success = false`); writing the staging row MUST NOT be treated as business success.

#### Scenario: Unknown access code stages reject with images

- **WHEN** `buildLicenseNo` does not match any `GovProject.AccessCode`
- **THEN** the system SHALL insert a reject staging row including Base64 image data when present
- **AND** MUST NOT create `UrbanWeighingRecord`
- **AND** the response SHALL have `success = false` with a message indicating the access code is not registered

#### Scenario: Successful ingest does not write staging

- **WHEN** Legacy ingest succeeds and creates an `UrbanWeighingRecord`
- **THEN** the system MUST NOT insert a reject staging row for that request

### Requirement: Legacy Post is anonymous

`POST /Api/Post` on `LegacyApiController` SHALL be callable without authentication (e.g. `AllowAnonymous`). The endpoint MUST remain the thin wrapper that parses JSON and returns the legacy response shape.

#### Scenario: Unauthenticated post accepted for processing

- **WHEN** an unauthenticated client POSTs to `/Api/Post` with a legacy weighing body
- **THEN** the request SHALL reach `LegacyGovSyncAppService` without requiring a login token
