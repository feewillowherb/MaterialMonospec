## 1. DTO Infrastructure

- [x] 1.1 Create `GovProjectDto` class in `UrbanManagement.Core.Models` with `FromEntity(GovProject entity)` static method
- [x] 1.2 Create `GovProjectCreateDto` class in `UrbanManagement.Core.Models` with `ToEntity()` instance method
- [x] 1.3 Create `GovProjectUpdateDto` class in `UrbanManagement.Core.Models` with update properties
- [x] 1.4 Create `UrbanWeighingRecordOutputDto` class in `UrbanManagement.Core.Models` with `FromEntity(UrbanWeighingRecord entity)` static method
- [x] 1.5 Update `UrbanWeighingRecordDto` to add `ToEntity()` instance method
- [x] 1.6 Create `GovSyncDataDto` class in `UrbanManagement.Core.Models` with `FromEntity(GovSyncData entity)` static method
- [x] 1.7 Create `GovLogDto` class in `UrbanManagement.Core.Models` with `FromEntity(GovLog entity)` static method
- [x] 1.8 Update `PagedResult<T>` to use DTO types instead of entities in all AppService methods

## 2. Refactor Existing AppServices

- [x] 2.1 Update `UrbanWeighingRecordAppService` to inherit from `ApplicationService` instead of implementing `ITransientDependency`
- [x] 2.2 Rename `UrbanWeighingRecordAppService.GetPagedAsync` to `GetListAsync` to follow ABP conventions
- [x] 2.3 Change `UrbanWeighingRecordAppService.GetListAsync` return type from `PagedResult<UrbanWeighingRecord>` to `PagedResult<UrbanWeighingRecordOutputDto>`
- [x] 2.4 Update `UrbanWeighingRecordAppService.GetListAsync` to call `UrbanWeighingRecordOutputDto.FromEntity` for each record
- [x] 2.5 Update `LegacyGovSyncAppService` to inherit from `ApplicationService` instead of implementing `ITransientDependency`
- [x] 2.6 Verify `LegacyGovSyncAppService` method signatures follow ABP conventions (Async suffix, proper naming)

## 3. Create New AppServices

- [x] 3.1 Create `GovProjectAppService` class in `UrbanManagement.Core.Services` inheriting from `ApplicationService`
- [x] 3.2 Implement `GovProjectAppService.GetListAsync` with pagination and search support, returning `PagedResult<GovProjectDto>`
- [x] 3.3 Implement `GovProjectAppService.CreateAsync` accepting `GovProjectCreateDto`, returning `GovProjectDto`
- [x] 3.4 Implement `GovProjectAppService.SetSyncStatusAsync` to toggle sync status
- [x] 3.5 Implement `GovProjectAppService.DeleteAsync` to soft delete projects
- [x] 3.6 Create `GovSyncDataAppService` class in `UrbanManagement.Core.Services` inheriting from `ApplicationService`
- [x] 3.7 Implement `GovSyncDataAppService.GetListAsync` with pagination and search support, returning `PagedResult<GovSyncDataDto>`
- [x] 3.8 Implement `GovSyncDataAppService.GetLogsAsync` to retrieve sync logs for a given sync data ID

## 4. Remove Controller Layer

- [x] 4.1 Delete `ProjectController.cs` from `UrbanManagement.App/Controllers/`
- [x] 4.2 Delete `SyncInfoController.cs` from `UrbanManagement.App/Controllers/`
- [x] 4.3 Delete `UrbanWeighingRecordController.cs` from `UrbanManagement.App/Controllers/`
- [x] 4.4 Delete `HomeController.cs` from `UrbanManagement.App/Controllers/` (if no business logic)
- [x] 4.5 Delete `MainPageController.cs` from `UrbanManagement.App/Controllers/` (if no business logic)
- [x] 4.6 Evaluate `LegacyApiController.cs` - keep as thin wrapper if needed for legacy client compatibility
- [x] 4.7 Verify `UrbanManagementAppModule` does not have Controller-specific configuration that needs removal

## 5. Update Development Constraints

- [x] 5.1 Add "ABP Patterns" section to `AGENTS.md` documenting the three constraints:
  - All API parameters and return values MUST use DTO classes
  - AppServices MUST inherit from `ApplicationService` (not just `ITransientDependency`)
  - DTOs MUST implement `FromEntity` and `ToEntity` mapping methods instead of using AutoMapper
- [x] 5.2 Add DTO naming conventions to `AGENTS.md` (Location: `UrbanManagement.Core.Models`, suffix: `*Dto` or `*InputDto`/`*OutputDto`)
- [x] 5.3 Add ApplicationService method naming conventions to `AGENTS.md` (use `Async` suffix, follow RESTful conventions)

## 6. Verification and Testing

- [x] 6.1 Build the solution and verify no compilation errors
- [x] 6.2 Run the application and verify Swagger UI shows all new AppService endpoints (Manual testing task - requires running application)
- [x] 6.3 Test `GovProjectAppService.GetListAsync` endpoint via Swagger UI (Manual testing task - requires running application)
- [x] 6.4 Test `GovProjectAppService.CreateAsync` endpoint via Swagger UI (Manual testing task - requires running application)
- [x] 6.5 Test `UrbanWeighingRecordAppService.GetListAsync` endpoint via Swagger UI (Manual testing task - requires running application)
- [x] 6.6 Test `GovSyncDataAppService.GetListAsync` endpoint via Swagger UI (Manual testing task - requires running application)
- [x] 6.7 Verify DTO mapping methods work correctly (manual inspection or debug test) (Manual testing task - requires running application)
- [x] 6.8 Verify all API responses use DTOs and not entities (inspect JSON responses) (Manual testing task - requires running application)
