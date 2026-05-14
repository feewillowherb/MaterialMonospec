## ADDED Requirements

### Requirement: ISampleDataProvider interface defines data access methods
The system SHALL define `ISampleDataProvider` interface in the Core project with methods: `GetPagedProjectsAsync(int page, int limit)`, `GetPagedSyncDataAsync(int page, int limit)`, `GetSyncLogsAsync(int syncDataId)`, and `GetDashboardStatsAsync()`.

#### Scenario: Interface is defined in Core project
- **WHEN** the Core project is compiled
- **THEN** `ISampleDataProvider` SHALL be resolvable from `UrbanManagement.Core.Services` namespace

### Requirement: SampleDataProvider returns hardcoded project data
`SampleDataProvider` SHALL implement `ISampleDataProvider` and return at least 3 sample `GovProject` records with varied data (different ProName, BuildLicenseNo, SyncStatus values).

#### Scenario: Project list returns multiple records
- **WHEN** `GetPagedProjectsAsync(1, 10)` is called
- **THEN** it SHALL return at least 3 sample GovProject records

#### Scenario: Pagination returns correct page
- **WHEN** `GetPagedProjectsAsync(1, 2)` is called
- **THEN** it SHALL return exactly 2 records and indicate total count is >= 3

### Requirement: SampleDataProvider returns hardcoded sync data
`SampleDataProvider` SHALL return at least 5 sample `GovSyncData` records with varied SyncType values (Pending, Success, Failed), associated ProName and BuildLicenseNo.

#### Scenario: Sync data includes various statuses
- **WHEN** `GetPagedSyncDataAsync(1, 10)` is called
- **THEN** the result SHALL contain records with SyncType values of 0, 1, and 2

#### Scenario: Sync data includes image references
- **WHEN** a sample sync data record is inspected
- **THEN** `SnapImages` SHALL contain at least one image path (can be placeholder)

### Requirement: SampleDataProvider returns hardcoded sync logs
`SampleDataProvider` SHALL return at least 2 sample `GovLog` records per sync data entry, with SyncTime, SyncNumber, SyncResult, and SyncMsg fields populated.

#### Scenario: Logs are returned for a sync data entry
- **WHEN** `GetSyncLogsAsync(1)` is called
- **THEN** it SHALL return at least 2 GovLog records with different SyncTime values

### Requirement: SampleDataProvider is registered as transient via ABP
`SampleDataProvider` SHALL implement `ITransientDependency` and use `[AutoConstructor]` for dependency injection, following the FluentSample service registration pattern.

#### Scenario: Service is injectable in controllers
- **WHEN** a controller constructor accepts `ISampleDataProvider`
- **THEN** ABP SHALL inject a `SampleDataProvider` instance

### Requirement: Sample data uses PascalCase property names
All DTO and entity objects returned by `SampleDataProvider` SHALL use PascalCase property names. JSON serialization from controllers SHALL use camelCase to match the original AJAX response format expected by LayUI views.

#### Scenario: JSON response uses camelCase for frontend compatibility
- **WHEN** a controller returns sample data as JSON
- **THEN** property names SHALL be camelCase (e.g., `proName`, `buildLicenseNo`) matching the LayUI table column field names
