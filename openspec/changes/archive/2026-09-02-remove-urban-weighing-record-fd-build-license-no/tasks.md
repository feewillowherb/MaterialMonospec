## 1. Git (Mode A)

- [x] 1.1 Before first code edit: create and checkout branch `remove-urban-weighing-record-fd-build-license-no` from trunk in MaterialMonospec, UrbanManagement, and MaterialClient

## 2. UrbanManagement — remove field

- [x] 2.1 Remove `FdBuildLicenseNo` from `UrbanWeighingRecord` entity and `UrbanWeighingRecordReceiveInputDto`
- [x] 2.2 Remove assignment in `UrbanWeighingRecordAppService.ReceiveAsync` object initializer
- [x] 2.3 Remove EF `Property`/column mapping for `UrbanWeighingRecord.FdBuildLicenseNo` in `UrbanManagementDbContext` if explicitly configured
- [x] 2.4 Add EF migration to drop `FdBuildLicenseNo` from `UrbanWeighingRecords`

## 3. MaterialClient — remove submit field

- [x] 3.1 Remove `FdBuildLicenseNo` property from `UrbanWeighingRecordSubmitDto`
- [x] 3.2 Confirm `UrbanServerUploadService` does not reference the removed property (no mapping needed)

## 4. Tests

- [x] 4.1 Update or remove any tests asserting `FdBuildLicenseNo` on weighing receive/submit DTOs or entity
- [x] 4.2 Run `dotnet test` on UrbanManagement.Core.Tests (and MaterialClient tests if touched)

## 5. Verify

- [x] 5.1 Build UrbanManagement and MaterialClient.Urban
- [x] 5.2 `openspec validate remove-urban-weighing-record-fd-build-license-no --strict`
