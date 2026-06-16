## 1. UrbanManagement — JWT Persistence Entity & Repository

- [ ] 1.1 Create `PersistedJwtToken` entity in `UrbanManagement.Core/Entities/` with ProId (Guid PK), JwtToken (string), ExpiresAt (DateTime), and ABP audit properties
- [ ] 1.2 Register `DbSet<PersistedJwtToken>` in `UrbanManagementDbContext`
- [ ] 1.3 Create `IPersistedJwtTokenRepository` interface extending `IRepository<PersistedJwtToken>` with `GetByProIdAsync(Guid proId)` method
- [ ] 1.4 Add EF Core migration for `PersistedJwtTokens` table

## 2. UrbanManagement — JWT Anti-Tamper Service

- [ ] 2.1 Create `JwtAntiTamperResult` DTO with Passed (bool), Reason (string?), ServerJwt (string?), and license field properties (ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime)
- [ ] 2.2 Create `IJwtAntiTamperService` interface with `VerifyAndCompareAsync(string jwtToken, Guid proId)` returning `JwtAntiTamperResult`
- [ ] 2.3 Implement `JwtAntiTamperService`: RS256 signature validation, ProId query against `IPersistedJwtTokenRepository`, raw text equality comparison, expiry check. On pass, populate `ServerJwt` with the persisted JWT text

## 3. UrbanManagement — License Generation Persistence Integration

- [ ] 3.1 Modify `UrbanLicenseGenerator.GenerateLicenseToken()` to call `IPersistedJwtTokenRepository` upsert after successful JWT generation (inject repository via constructor)

## 4. UrbanManagement — SignalR Hub Extension

- [ ] 4.1 Add `VerifyJwtAsync(string jwtToken, string proId)` method to `DeviceStatusHub`, parsing proId as Guid, delegating to `IJwtAntiTamperService`, and returning `JwtAntiTamperResult`

## 5. MaterialClient — Server JWT Storage (LatestJwtToken)

- [ ] 5.1 Add `LatestJwtToken` (string?) property to `LicenseInfo` entity in `MaterialClient.Common/Entities/LicenseInfo.cs`
- [ ] 5.2 Add EF Core migration for `LicenseInfo.LatestJwtToken` column in MaterialClient

## 6. MaterialClient — Startup JWT Source Priority (Server JWT > .urban Bootstrap)

- [ ] 6.1 Modify `MaterialClientUrbanModule.OnApplicationInitializationAsync()`: on startup, check `LicenseInfo.LatestJwtToken` first; if non-null, validate it via `StaticLicenseChecker`; if null or invalid, fall back to `.urban` file
- [ ] 6.2 Ensure `StaticLicenseChecker` can accept a JWT string directly (not only file path) for validation — add overload or modify to accept both sources
- [ ] 6.3 After successful JWT validation, overwrite `LicenseInfo` database record with JWT-derived claims (ProjectId, ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime)

## 7. MaterialClient — Anti-Tamper Online Sync Integration

- [ ] 7.1 Modify `DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync()` to read local JWT (priority: `LatestJwtToken` > `.urban` file) as raw text, call `VerifyJwtAsync` via SignalR, and branch on result
- [ ] 7.2 On pass: store `ServerJwt` from result to `LicenseInfo.LatestJwtToken`, derive `LicenseInfo` fields from server JWT claims, overwrite `LicenseInfo` record
- [ ] 7.3 On fail: log warning, skip field sync, do NOT modify `LicenseInfo`
- [ ] 7.4 Handle edge cases: no local JWT available (skip check, proceed with field sync), empty/whitespace JWT (skip check), SignalR timeout/exception (fallback to field sync only)
