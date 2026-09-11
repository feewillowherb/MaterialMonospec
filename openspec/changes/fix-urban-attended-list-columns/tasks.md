## 1. Data model (MaterialClient)

- [x] 1.1 Add nullable `UploadedAt` on `UrbanPassageRecord` with type-owned set-on-sync method; map to `UrbanAttendedListRow.UploadTime` in `FromPassage`
- [x] 1.2 Add nullable `UrbanInOutType` on `UrbanWeighingExtension` with type-owned writer; project to `InOutText` in `FromWeighing` / list query
- [x] 1.3 Add Urban SQLite migrations (no DB FK / no EF relationships); verify with `dotnet build … -o .build-verify`

## 2. Write paths

- [x] 2.1 On passage mark-synced success path, call type-owned method to set `UploadedAt` (Service MUST NOT assign fields)
- [x] 2.2 When creating/updating weighing extension from LPR/weigh side effects, persist device `UrbanInOutType` when known

## 3. UI (UrbanAttendedWeighingWindow)

- [x] 3.1 Mixed/weighing header: rename「时间」→「抓拍时间」; add「上传时间」column; bind row `UploadTime`
- [x] 3.2 Checkpoint/finished-product header: keep dedicated columns; add「上传时间」; add matching dedicated row `Grid` bound to plate/color/vehicle/in-out/site/`SortTime`/`UploadTime`
- [x] 3.3 Ensure dedicated row template visibility follows `IsPassageDedicatedTab` (RelativeSource to Window VM); mixed tab still uses weighing/passage-mixed templates

## 4. Verify

- [x] 4.1 Manually check「正常」「异常」: 进出 shows 进/出 when extension has value, else「—」; 抓拍时间 + 上传时间 columns visible
- [x] 4.2 Manually check「卡口」「成品」: 场地 = 工地/消纳, 抓拍时间 = CapturedAt, not swapped
- [x] 4.3 `openspec validate fix-urban-attended-list-columns --strict`
