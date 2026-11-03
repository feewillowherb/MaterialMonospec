## Context

`RejectAsync` currently `InsertAsync` into `LegacyWeighingRejectStaging` with `PayloadJson` + `SnapImagesBase64Json`. Nothing queries the table. After clearing historical rows the DB is ~1GB; stopping writes prevents re-growth.

## Goals / Non-Goals

**Goals**

- Stop all reject-path DB writes to staging.
- Log enough to diagnose rejects (reason, codes, plate, payload without images).
- Keep legacy HTTP response contract.

**Non-Goals**

- Drop `LegacyWeighingRejectStagings` table / EF entity (separate cleanup if desired).
- Replay tooling, Admin UI, or MaterialClient changes.
- Change success-path ingest behavior.

## Decisions

1. **Log-only reject** — `RejectAsync` uses `ILogger` / `ApplicationService.Logger` at Warning; serialize existing `LegacyRejectPayloadSnapshot` (already image-free); log `snapImageCount` instead of Base64.
2. **Remove staging repository injection** from `LegacyGovSyncAppService` so AutoConstructor no longer depends on unused repo (minimal-di: no new services).
3. **Keep entity + DbSet** — avoids migration/risk in this change; table becomes write-idle.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Ops lose durable reject archive | Accept; table unused today; logs + log shipping replace |
| Large payload in logs | Payload is de-imaged fields only; reason truncated as today |

## Migration Plan

1. Deploy UM with log-only reject.
2. Optionally `DELETE FROM LegacyWeighingRejectStagings` + VACUUM on SQLite sites still holding history.
3. (Later) optional change to drop unused table.
