## 1. Git (Mode A)

- [ ] 1.1 Before first code edit: create and checkout branch `add-urbanmanagement-passage-xiaoshan-upload` from trunk in MaterialMonospec, UrbanManagement, and MaterialClient (only repos that will change)

## 2. UrbanManagement persistence

- [x] 2.1 Add `UrbanPassageRecord` + `PassageSource` on `UrbanManagementDbContext`; snapshots, plate fields, `CapturedAt`, logical attachment ids; no weight, no FK, no navigations
- [x] 2.2 Type-owned `From*` factory from ingest DTO; AppService MUST NOT assign entity fields
- [x] 2.3 EF migration

## 3. UrbanManagement ingest APIs

- [x] 3.1 Checkpoint ApplicationService ingest + `[UnitOfWork]`; named DTO `record`s only
- [x] 3.2 Finished-product ApplicationService ingest (separate type, duplication allowed); MUST NOT call checkpoint methods with a flag
- [x] 3.3 Reuse multipart attachment ids on both ingest DTOs

## 4. UrbanManagement pages

- [x] 4.1 Checkpoint list page: filter `PassageSource` checkpoint; columns per spec; View → AppService only
- [x] 4.2 Finished-product list page: independent page/code; same column rules; sync status if weighing has it
- [x] 4.3 Menu/navigation entries; do not mix into weighing approval

## 5. Xiaoshan outbound (independent)

- [x] 5.1 UM Gov host configuration (scheme/host/port); optional second base address; no hardcoded demo IPs
- [x] 5.2 Weighbridge payload `record` + Converter + Refit `lantu/saveRecord`; `dataSource` constant `WEIGHBRIDGE_XIAOSHAN`; remove hardcoded `inOutType=0`
- [x] 5.3 Checkpoint payload `record` + separate Converter + Refit `inoutRecord/save`; `buildLicenseNo=L`; no `dataSource`; omit empty `goodsWeight`
- [x] 5.4 Product payload `record` + separate Converter + distinct outbound type even if same path; `ForProduct(L)` once
- [x] 5.5 Static license helper; MUST NOT register converters or mappers in DI

## 6. Gov worker

- [x] 6.1 Weighing pending path calls weighbridge client only
- [x] 6.2 Separate checkpoint pending query + forward method
- [x] 6.3 Separate finished-product pending query + forward method
- [x] 6.4 No heartbeat; success `code==200`; retry fields aligned with weighing where applicable

## 7. MaterialClient

- [x] 7.1 Upload passage attachments via existing multipart API
- [x] 7.2 Checkpoint pending rows → checkpoint ingest API; product → product ingest; weighing receive unchanged
- [ ] 7.3 Client MUST NOT HTTP to Xiaoshan Gov

## 8. Verify

- [x] 8.1 Tests or equivalent: ingest isolation, suffix rules, converter Enter/Exit, no FK
- [x] 8.2 `openspec validate add-urbanmanagement-passage-xiaoshan-upload --strict`
