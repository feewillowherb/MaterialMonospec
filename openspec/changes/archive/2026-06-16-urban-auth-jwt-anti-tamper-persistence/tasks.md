## 1. UrbanManagement — JWT Anti-Tamper Service

- [x] 1.1 Create `JwtAntiTamperResult` DTO with Passed (bool), Reason (string?), ServerJwt (string?), and license field properties (ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime)
- [x] 1.2 Create `JwtVerificationRequest` DTO with JwtToken (string) and ProId (string)
- [x] 1.3 Create `IJwtAntiTamperService` interface with `VerifyAndCompareAsync(string jwtToken, Guid proId)` returning `JwtAntiTamperResult`
- [x] 1.4 Implement `JwtAntiTamperService`: RS256 signature validation, extract proId from JWT claims, query `GovProject` by proId via `IRepository<GovProject>`, re-sign fresh JWT from GovProject data using `IUrbanLicenseGenerator`. On pass, populate `ServerJwt` with the freshly signed JWT and license fields from GovProject

## 2. UrbanManagement — SignalR Hub Extension

- [x] 2.1 Add `VerifyJwtAsync(string jwtToken, string proId)` method to `DeviceStatusHub`, parsing proId as Guid, delegating to `IJwtAntiTamperService`, and returning `JwtAntiTamperResult`

## 3. MaterialClient — Server JWT Storage (LatestJwtToken)

- [x] 3.1 Add `LatestJwtToken` (string?) property to `LicenseInfo` entity in `MaterialClient.Common/Entities/LicenseInfo.cs`
- [x] 3.2 Add EF Core migration for `LicenseInfo.LatestJwtToken` column in MaterialClient

## 4. MaterialClient — Startup JWT Source Priority (Server JWT > .urban Bootstrap)

- [x] 4.1 Modify `MaterialClientUrbanModule.OnApplicationInitializationAsync()`: on startup, check `LicenseInfo.LatestJwtToken` first; if non-null, validate it via `StaticLicenseChecker`; if null or invalid, fall back to `.urban` file
- [x] 4.2 Ensure `StaticLicenseChecker` can accept a JWT string directly (not only file path) for validation — add `CheckLicenseFromTokenAsync` overload
- [x] 4.3 After successful JWT validation, overwrite `LicenseInfo` database record with JWT-derived claims (ProjectId, ProName, BuildLicenseNo, FdBuildLicenseNo, AuthEndTime)

## 5. MaterialClient — Anti-Tamper Online Sync Integration

- [x] 5.1 Modify `DeviceStatusSignalRClient.SyncProjectLicenseFromServerAsync()` to read local JWT (priority: `LatestJwtToken` > `.urban` file) as raw text, call `VerifyJwtAsync` via SignalR, and branch on result
- [x] 5.2 On pass: store `ServerJwt` from result to `LicenseInfo.LatestJwtToken`, derive `LicenseInfo` fields from server JWT claims, overwrite `LicenseInfo` record
- [x] 5.3 On fail: log warning, skip field sync, do NOT modify `LicenseInfo`
- [x] 5.4 Handle edge cases: no local JWT available (skip check, proceed with field sync), empty/whitespace JWT (skip check), SignalR timeout/exception (fallback to field sync only)
