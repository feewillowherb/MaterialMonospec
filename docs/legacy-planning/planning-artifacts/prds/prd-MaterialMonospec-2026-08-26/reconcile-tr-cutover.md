# Reconcile — TR cutover research → PRD

**Input:** `technical-xiaoshanserve-urbanmanagement-iis-cutover-research-2026-08-26.md`  
**Against:** `prd.md` + `addendum.md`  
**Date:** 2026-08-26

## Coverage

| TR item | PRD landing |
|---------|-------------|
| R1 Option A dual binding | FR-1, FR-4, D3 |
| R2 ETL Guid + images | FR-8–10, FR-13, addendum D13/D14 |
| R3 SyncType policy | FR-15–16, D5 |
| R4 Access-code pre-check | FR-7, FR-14 |
| R5 YARP fallback | FR-4 |
| R6 Separate from V2 epic | Header + Out of Scope + D log P2 |
| Skip GovLog / XSS GovProject | FR-11–12, D1–D2 |
| Stop-write / runbook / rollback | FR-17–22, NFR-3, addendum C |
| Legacy ACL / no JWT block | FR-5–6 |

## Gaps (non-blocking)

1. Exact OldPort/NewPort — Open D6 (ops inventory)  
2. XSS column map — Open D7 (schema probe)  
3. Qualitative “soak duration” — not fixed in PRD; left to change ticket *[deferred]*

## Verdict

No missing P0 TR recommendations. Safe to finalize PRD.
