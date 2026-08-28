## 1. Git (Mode A)

- [ ] 1.1 Before first code edit: create and checkout branch `add-urbanmanagement-passage-xiaoshan-upload` from trunk in MaterialMonospec, UrbanManagement, and MaterialClient (only repos that will change)

## 2. UrbanManagement persistence

- [ ] 2.1 Add `UrbanPassageRecord` + `PassageSource` on `UrbanManagementDbContext`; snapshots, plate fields, `CapturedAt`, logical attachment ids; no weight, no FK, no navigations
- [ ] 2.2 Type-owned `From*` factory from ingest DTO; AppService MUST NOT assign entity fields
- [ ] 2.3 EF migration

## 3. UrbanManagement ingest APIs

- [ ] 3.1 Checkpoint ApplicationService ingest + `[UnitOfWork]`; named DTO `record`s only
- [ ] 3.2 Finished-product ApplicationService ingest (separate type, duplication allowed); MUST NOT call checkpoint methods with a flag
- [ ] 3.3 Reuse multipart attachment ids on both ingest DTOs

## 4. UrbanManagement pages

- [ ] 4.1 Checkpoint list page: filter `PassageSource` checkpoint; columns per spec; View → AppService only
- [ ] 4.2 Finished-product list page: independent page/code; same column rules; sync status if weighing has it
- [ ] 4.3 Menu/navigation entries; do not mix into weighing approval

## 5. Xiaoshan outbound (independent)

- [ ] 5.1 UM Gov host configuration (scheme/host/port); optional second base address; no hardcoded demo IPs
- [ ] 5.2 Weighbridge payload `record` + Converter + Refit `lantu/saveRecord`; `dataSource` constant `WEIGHBRIDGE_XIAOSHAN`; remove hardcoded `inOutType=0`
- [ ] 5.3 Checkpoint payload `record` + separate Converter + Refit `inoutRecord/save`; `buildLicenseNo=L`; no `dataSource`; omit empty `goodsWeight`
- [ ] 5.4 Product payload `record` + separate Converter + distinct outbound type even if same path; `ForProduct(L)` once
- [ ] 5.5 Static license helper; MUST NOT register converters or mappers in DI

## 6. Gov worker

- [ ] 6.1 Weighing pending path calls weighbridge client only
- [ ] 6.2 Separate checkpoint pending query + forward method
- [ ] 6.3 Separate finished-product pending query + forward method
- [ ] 6.4 No heartbeat; success `code==200`; retry fields aligned with weighing where applicable

## 7. MaterialClient

- [ ] 7.1 Upload passage attachments via existing multipart API
- [ ] 7.2 Checkpoint pending rows → checkpoint ingest API; product → product ingest; weighing receive unchanged
- [ ] 7.3 Client MUST NOT HTTP to Xiaoshan Gov

## 8. Verify

- [ ] 8.1 Tests or equivalent: ingest isolation, suffix rules, converter Enter/Exit, no FK
- [ ] 8.2 `openspec validate add-urbanmanagement-passage-xiaoshan-upload --strict`
