# Implementation Tasks: Remove GovLog

## 1. Data Layer Cleanup

- [x] 1.1 Delete `GovLog.cs` entity class
- [x] 1.2 Remove `DbSet<GovLog>` property from `UrbanManagementDbContext`
- [x] 1.3 Remove `GovLog` entity configuration from `UrbanManagementDbContext.OnModelCreating()`
- [ ] 1.4 Note: EF Core migration will be handled manually by the user

## 2. DTO Layer Cleanup

- [x] 2.1 Delete `GovLogDto.cs` class
- [x] 2.2 Delete `GovSyncDataLogsInputDto` class from `GovSyncDataQueryDtos.cs`

## 3. Service Layer Modification

- [x] 3.1 Remove `IRepository<GovLog, int>` dependency from `GovSyncManager` constructor
- [x] 3.2 Delete `InsertLogAsync()` method from `GovSyncManager`
- [x] 3.3 Remove all `InsertLogAsync()` calls in `GovSyncManager.ProcessRecordAsync()`
- [x] 3.4 Add `LogInformation` call for successful sync with RecordId, Code, Msg, and Payload
- [x] 3.5 Add `LogWarning` call for failed sync with RecordId, Code, Msg, and Payload
- [x] 3.6 Verify `LogError` call exists for exception handling (no change needed)
- [x] 3.7 Remove `GetLogsAsync()` method from `IGovSyncDataAppService` interface
- [x] 3.8 Remove `GetLogsAsync()` method from `GovSyncDataAppService` class
- [x] 3.9 Remove `IRepository<GovLog, int>` dependency from `GovSyncDataAppService` constructor

## 4. Spec Update

- [x] 4.1 Apply delta spec to `openspec/specs/gov-sync-worker/spec.md` (remove Sync logging requirement)

## 5. Testing

- [ ] 5.1 Verify government sync functionality works without GovLog
- [ ] 5.2 Verify Serilog logs contain RecordId, Code, Msg, and Payload for successful sync
- [ ] 5.3 Verify Serilog logs contain RecordId, Code, Msg, and Payload for failed sync
- [ ] 5.4 Verify Serilog logs contain RecordId and exception details for errors
- [ ] 5.5 Test that deleted API endpoint returns 404
- [ ] 5.6 Note: Database migration will be verified manually by the user

## 6. Verification

- [x] 6.1 Search codebase for any remaining `GovLog` references
- [x] 6.2 Confirm frontend has no calls to deleted API endpoint
- [x] 6.3 Review Serilog configuration (no changes needed, but verify)
