## 1. Service reject path

- [x] 1.1 Remove `_rejectStagingRepository` from `LegacyGovSyncAppService`; stop all `InsertAsync` on reject
- [x] 1.2 In `RejectAsync`, log Warning with reason, access code, plate, image count, de-imaged payload JSON (no Base64)
- [x] 1.3 Update `LegacyWeighingRejectStaging` entity comment to note write-idle / historical only

## 2. Tests

- [x] 2.1 Update `LegacyGovSyncAppServiceTests` constructor/helpers: no staging repo; reject cases assert failure and no DB insert dependency
- [x] 2.2 Rename/adjust reject tests that previously asserted staged Base64 rows

## 3. Verify

- [x] 3.1 Run `UrbanManagement.Core.Tests` filter `LegacyGovSyncAppServiceTests`
- [x] 3.2 `openspec validate update-legacy-reject-log-only --strict`
