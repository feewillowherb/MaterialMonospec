## ADDED Requirements

### Requirement: /Api/Post forwards verbatim to UrbanManagement

XiaoShanServe `ApiController.Post`（`POST /Api/Post`）SHALL read the raw request body and forward it as an HTTP POST to the configured UrbanManagement forward URL, without deserializing, field mapping, or fd-code translation. The forwarder SHALL relay the UrbanManagement response body to the caller with HTTP status 200 (legacy wire contract: business result carried in the body, transport always 200).

#### Scenario: Valid payload forwarded and UM success relayed

- **WHEN** a legacy client POSTs a valid weighing payload (城管接入码 + snapImages base64) to XiaoShanServe `/Api/Post`
- **THEN** XiaoShanServe SHALL POST the raw body unchanged to the configured UM `/Api/Post`
- **AND** SHALL return HTTP 200 with the UM response body (indicating `success = true` and `code` 200 after UM ingest)

#### Scenario: UM reject relayed as failure

- **WHEN** UM responds with a failure body (e.g. unknown access code staged into reject staging, `success = false`)
- **THEN** XiaoShanServe SHALL return HTTP 200 with that UM failure body unchanged

#### Scenario: Forward failure returns legacy failure shape

- **WHEN** the configured UM endpoint is unreachable or times out
- **THEN** XiaoShanServe SHALL return HTTP 200 with a legacy-shape failure body `{ success = false, msg containing the forward failure reason, code = -1 }`
- **AND** MUST NOT crash the process or hang the request beyond the configured HttpClient timeout

### Requirement: Forward path has no local persistence

The XiaoShanServe forward path MUST NOT insert into `GovSyncData` (`XiaoShan.db`), MUST NOT write image files to `TempUpload` (or any path under `FilesPhysicalPath`), and MUST NOT query the local `Gov_Project` table for fd-code or access-code resolution. Local ingest logic in `Post` is removed, not feature-flagged.

#### Scenario: Successful forward writes nothing locally

- **WHEN** a forwarded payload is ingested successfully by UM
- **THEN** `XiaoShan.db` `Gov_SyncData` SHALL have no new row for that request
- **AND** no new file SHALL appear under `FilesPhysicalPath` / `TempUpload`

#### Scenario: fdBuildLicenseNo-only payload is not resolved locally

- **WHEN** a payload contains only `fdBuildLicenseNo` and empty `buildLicenseNo`
- **THEN** XiaoShanServe SHALL forward the payload unchanged (no fd-code lookup, no code swap)
- **AND** the reject/accept decision SHALL be made solely by UM

### Requirement: Forward target is configurable

The UM forward URL SHALL be read from configuration (appsettings flat key `UrbanManagementForwardUrl`), following the existing `AppSettings` flat-key style. A missing or empty URL SHALL produce a startup warning and per-request legacy-shape failure responses (`success = false`, `code = -1`), not a crash.

#### Scenario: URL supplied via configuration

- **WHEN** `UrbanManagementForwardUrl` is set to `http://<host>:<portB>/Api/Post` in appsettings
- **THEN** forwarded requests SHALL target that URL without code changes or redeployment

#### Scenario: URL missing degrades to failure responses

- **WHEN** `UrbanManagementForwardUrl` is absent or empty and a legacy POST arrives
- **THEN** XiaoShanServe SHALL log a warning and return HTTP 200 with `success = false` and `code = -1`

### Requirement: Government export worker disabled by default

The in-process `ExplortStatisticBgService` outbound worker SHALL be registered only when configuration flag `EnableGovExport` is explicitly true; the default (absent) SHALL NOT register the worker. UM `GovSyncBackgroundWorker` is the sole outbound path to the government platform after this change.

#### Scenario: Default deployment has no outbound loop

- **WHEN** the app starts with no `EnableGovExport` key in configuration
- **THEN** `ExplortStatisticBgService` SHALL NOT run
- **AND** no request to the government `GovAddress` SHALL originate from XiaoShanServe

#### Scenario: Rollback window can re-enable export

- **WHEN** an operator sets `EnableGovExport` to `true` during a rollback window
- **THEN** the outbound worker SHALL resume processing pending `GovSyncData` rows
- **AND** the operator MUST first stop the UM sync worker to avoid double-reporting (ops runbook responsibility)
