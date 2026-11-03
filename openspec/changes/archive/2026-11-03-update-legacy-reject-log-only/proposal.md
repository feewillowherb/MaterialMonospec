## Why

`LegacyWeighingRejectStagings` has ballooned production SQLite (~90GB) with Base64 images and full payloads that no product path ever reads. Reject diagnostics still matter, but must not grow the database.

## What Changes

- Legacy ingest reject path **MUST NOT** insert into `LegacyWeighingRejectStaging` (no images, no payload, no staging row).
- On reject, UrbanManagement **SHALL** write a structured log: reject reason, attempted access code, plate if present, image **count** (not Base64), and de-imaged business payload JSON.
- HTTP legacy failure shape (`success = false`) unchanged.
- Entity/table may remain in schema for this change (no drop migration); writing stops immediately.
- Unit tests updated to assert no staging insert.

## Capabilities

### New Capabilities

- (none)

### Modified Capabilities

- `urban-legacy-weighing-ingest`: replace reject staging persistence with log-only reject diagnostics (no Base64 / no DB row).

## Impact

- **UrbanManagement**: `LegacyGovSyncAppService` reject path; `LegacyGovSyncAppServiceTests`; entity comment optional.
- **MaterialClient / clients**: no change (still receive `success=false`).
- **Ops**: existing staging rows may be deleted out-of-band; new rejects no longer accumulate.
