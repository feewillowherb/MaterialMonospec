## 1. Entity & Data Model Updates

- [x] 1.1 Add `AttachType` enum to `UrbanManagement.Core/Entities/Enums/` with values `Lrp = 5` and `UrbanPhoto = 6`
- [x] 1.2 Create `AttachmentFile` entity in `UrbanManagement.Core/Entities/` with Id (Guid), FileName, LocalPath, AttachType, AddTime fields, inheriting `Entity<Guid>`
- [x] 1.3 Create `UrbanWeighingRecordAttachment` entity in `UrbanManagement.Core/Entities/` with Id (Guid), UrbanWeighingRecordId (long), AttachmentFileId (Guid) fields, inheriting `Entity<Guid>`
- [x] 1.4 Extend `UrbanWeighingRecord` entity (currently `Entity<long>`): add VehicleColor, PlateColor, VehicleType, DeviceId, BuildLicenseNo, SiteType, ProId, ProName, IsAnomaly, ClientSyncType, ClientSyncTime, ClientRetryCount, ClientLastErrorTime, SyncTime, RetryCount, LastErrorTime fields; remove SnapImages field
- [x] 1.5 Add `IsAnomaly` field to `GovSyncData` entity (currently `Entity<int>`); verify all other forwarding fields are present
- [x] 1.6 Update `UrbanManagementDbContext`: register AttachmentFile and UrbanWeighingRecordAttachment DbSets; add indexes on GovProject.BuildLicenseNo, GovProject.FdBuildLicenseNo, UrbanWeighingRecord.SyncType, UrbanWeighingRecord.ClientSyncType, UrbanWeighingRecord.ProId, UrbanWeighingRecord.AddTime, GovLog.SyncId; update UrbanWeighingRecord column mappings to remove SnapImages and add new columns
- [x] 1.7 Add EF Core migration for all entity changes

## 2. Configuration & Infrastructure

- [x] 2.1 Create `StorageOptions` class in `UrbanManagement.Core/Configuration/` with FilesPhysicalPath, CompressImage, GovAddress properties
- [x] 2.2 Add StorageOptions section to `UrbanManagement.App/appsettings.json` with default values (FilesPhysicalPath: "Uploads/", CompressImage: 200, GovAddress: "")
- [x] 2.3 Bind StorageOptions via `Configure<StorageOptions>` in `UrbanManagementCoreModule.ConfigureServices`
- [x] 2.4 Add custom `DateTimeJsonConverter` to handle `yyyy-MM-dd HH:mm:ss` format from legacy client; register in `UrbanManagementAppModule.ConfigureServices` JSON options

## 3. Core Services (UrbanManagement.Core)

- [x] 3.1 Create `IGovProjectManager` / `GovProjectManager` in `UrbanManagement.Core/Services/` implementing dual access-code validation: fdBuildLicenseNo priority, buildLicenseNo fallback, null rejection; error messages matching old system
- [x] 3.2 Create `IFileService` / `FileService` in `UrbanManagement.Core/Services/` implementing Base64 decode → save to `{FilesPhysicalPath}/TempUpload/{buildLicenseNo}/{ticks}_{i}.jpg` → compress if > threshold → create AttachmentFile entities; also implement ReadAttachmentFilesAsync to load files and return Base64
- [x] 3.3 Create `ILegacyGovSyncAppService` / `LegacyGovSyncAppService` in `UrbanManagement.Core/Services/` orchestrating: access-code validation via IGovProjectManager → image processing via IFileService → GovSyncData construction (grossWeight > 0 overrides goodsWeight, sourceData with snapImages cleared) → repository insert
- [x] 3.4 Extend `IUrbanWeighingRecordAppService` / `UrbanWeighingRecordAppService` to accept extended fields (VehicleColor, PlateColor, etc.), sync state fields (ClientSyncType, etc.), and optional AttachmentFile ID list; create UrbanWeighingRecordAttachment join records on receive
- [x] 3.5 Create `IGovSyncHttpClient` Refit interface in `UrbanManagement.Core/Services/` with `[Post("")] Task<GovResponseBase<string>> PostWeightAsync([Body] object payload)`
- [x] 3.6 Create `GovSyncBackgroundWorker` in `UrbanManagement.Core/Services/` extending `AsyncPeriodicBackgroundWorkerBase` with 5-second period: query pending UrbanWeighingRecord (SyncType!=1, RetryCount<10, IsAnomaly=false, active project), read attachments as Base64, assemble GovSyncData + mGovRequestWeight payload, forward via IGovSyncHttpClient, update SyncType/RetryCount, insert GovLog entries

## 4. Refit & Polly Registration (UrbanManagement.App)

- [x] 4.1 Add Refit.HttpClientFactory and Microsoft.Extensions.Http.Polly NuGet package references to UrbanManagement.App project
- [x] 4.2 Register IGovSyncHttpClient via Refit in `UrbanManagementAppModule.ConfigureServices` with Polly retry policy (3 attempts, exponential backoff) and base address from StorageOptions.GovAddress
- [x] 4.3 Register `GovSyncBackgroundWorker` with ABP background worker infrastructure in module configuration

## 5. API Controllers (UrbanManagement.App)

- [x] 5.1 Create `GovRequestWeightDto` in `UrbanManagement.App/Models/` with camelCase properties matching old mGovRequestWeight: carNo, carColor, carNoColor, buildLicenseNo, fdBuildLicenseNo, inOutType, equipmentNumber, equipmentType, grossWeight, tareWeight, snapTime, snapImages (string?[]), carType, deviceID, siteType, goodsWeight; use `[JsonPropertyName]` for explicit field mapping
- [x] 5.2 Create `GovResponseBase<T>` in `UrbanManagement.App/Models/` with Success, Msg, Code, Data properties for consistent API response wrapping
- [x] 5.3 Create `LegacyApiController` in `UrbanManagement.App/Controllers/` with `[Route("Api/[action]")]`, `[HttpPost] Post([FromBody] JsonElement model)` → parse fields → call ILegacyGovSyncAppService → return `{ success, msg, code, data }` format
- [x] 5.4 Update `UrbanWeighingRecordDto` to include extended fields (VehicleColor, PlateColor, VehicleType, DeviceId, BuildLicenseNo, SiteType, ProId, ProName, IsAnomaly, ClientSyncType, ClientSyncTime, ClientRetryCount, ClientLastErrorTime) and optional AttachmentIds list
- [x] 5.5 Update `UrbanWeighingRecordController.Receive` to pass extended DTO fields to the updated AppService

## 6. Management Controllers (Mock → Real DB)

- [x] 6.1 Refactor `ProjectController` to inject `IRepository<GovProject, Guid>` and implement PageList, Add, SetStatus, Del with real database operations
- [x] 6.2 Refactor `SyncInfoController` to inject `IRepository<GovSyncData, int>` and `IRepository<GovLog, int>` and implement PageList and LogList with real database operations
- [x] 6.3 Remove `ISampleDataProvider` interface and `SampleDataProvider` class from `UrbanManagement.Core/Services/`

## 7. MaterialClient.Urban Integration

- [x] 7.1 Create `IUrbanManagementApi` Refit interface in MaterialClient.Urban with `POST /api/urban/weighing-records` mapped to the extended UrbanWeighingRecordDto; register in MaterialClient.Urban DI
- [x] 7.2 Verify `UrbanWeighingExtension` entity in MaterialClient.Common maps sync-state fields correctly to server-side UrbanWeighingRecord (SyncStatus→ClientSyncType, RetryCount→ClientRetryCount, LastErrorTime→ClientLastErrorTime)
- [x] 7.3 Update the Urban weighing completion flow in MaterialClient.Urban ViewModels to submit weighing records via IUrbanManagementApi after local save, including Lrp attachment references

## 8. Build Verification

- [x] 8.1 Build and verify UrbanManagement.sln compiles without errors: `dotnet build repos/UrbanManagement/UrbanManagement.sln`
- [x] 8.2 Build and verify MaterialClient.sln compiles without errors: `dotnet build repos/MaterialClient/MaterialClient.sln`
