## 1. Entity Layer Implementation

- [x] 1.1 Create `MaterialClient.Common/Entities/Urban/` folder structure
- [x] 1.2 Create `UrbanWeighingExtension.cs` entity with WeighingRecordId foreign key, SyncStatus, RetryCount, and LastErrorTime properties
- [x] 1.3 Remove `SyncStatus` property from `WeighingRecord.cs` entity
- [x] 1.4 Add nullable navigation property `UrbanExtension` to `WeighingRecord.cs`

## 2. Data Layer Configuration

- [x] 2.1 Add `DbSet<UrbanWeighingExtension> UrbanWeighingExtensions` property to `MaterialClientDbContext.cs`
- [x] 2.2 Configure 1:0..1 relationship using Fluent API in `MaterialClientDbContext.OnModelCreating()`
- [x] 2.3 Add unique index constraint on `UrbanWeighingExtension.WeighingRecordId`
- [x] 2.4 Add composite index on `(SyncStatus, WeighingRecordId)` for background worker query performance
- [x] 2.5 Create EF Core migration for `UrbanWeighingExtensions` table creation

## 3. Business Layer Updates

- [x] 3.1 Update `UrbanAttendedWeighingViewModel.ReloadRecordsAsync()` query to use LEFT JOIN pattern with `.Include(wr => wr.UrbanExtension)`
- [x] 3.2 Modify tab filter logic in `UrbanAttendedWeighingViewModel` to filter by `extension.SyncStatus` instead of `record.SyncStatus`
- [x] 3.3 Update record creation logic in attended weighing service to create extension row transactionally with `WeighingRecord`
- [x] 3.4 Add extension creation logic to set initial state: `SyncStatus.Pending`, `RetryCount = 0`, `LastErrorTime = null`
- [x] 3.5 Update background sync worker queries to scan `UrbanWeighingExtensions` table using new indexes

## 4. UI Layer Updates

- [x] 4.1 Update XAML binding in `UrbanAttendedWeighingWindow.axaml` from `{Binding SyncStatus}` to `{Binding UrbanExtension.SyncStatus}`
- [x] 4.2 Add null-safe value converter or fallback logic for XAML bindings when `UrbanExtension` is null
- [x] 4.3 Update status badge visibility logic to check extension property existence
- [x] 4.4 Verify all Urban UI components referencing `SyncStatus` are updated to use extension path

## 5. Testing and Validation

- [x] 5.1 Write unit tests for `UrbanWeighingExtension` entity properties and validation
- [x] 5.2 Write unit tests for 1:0..1 relationship configuration and navigation properties
- [x] 5.3 Write integration tests for LEFT JOIN query patterns and tab filtering
- [x] 5.4 Write integration test for transactional record+extension creation
- [ ] 5.5 Manually test Urban record creation and verify extension row is created
- [ ] 5.6 Manually test tab filtering (全部/正常/异常) displays correct records
- [ ] 5.7 Manually test status badges display correctly based on extension data
- [ ] 5.8 Run background sync worker query performance benchmarks before and after migration
- [ ] 5.9 Test migration script on sample database with existing Urban records
- [ ] 5.10 Verify rollback capability by executing migration `Down()` method

## 6. Documentation and Cleanup

- [x] 6.1 Update entity relationship diagram to reflect 1:0..1 pattern
- [x] 6.2 Add XML documentation comments to `UrbanWeighingExtension` entity
- [x] 6.3 Update AGENTS.md or project documentation with Urban extension pattern for future variant reference
