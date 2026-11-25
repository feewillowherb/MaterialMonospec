# materialclient-code-hygiene Specification

## Purpose
TBD - created by archiving change refactor-cleanup-materialclient-hygiene. Update Purpose after archive.
## Requirements
### Requirement: ViewModels and Views MUST NOT access repositories directly
All ViewModels and Avalonia code-behind classes in `MaterialClient` MUST perform data access through application or domain services rather than injecting or resolving `IRepository<,>` or `DbContext`.

#### Scenario: Detail ViewModel loads or abolishes a weighing record
- **WHEN** `AttendedWeighingDetailViewModelBase` loads a weighing record for manual matching or deletes a weighing record on abolish
- **THEN** it delegates to `IWeighingRecordService` instead of resolving `IRepository<WeighingRecord, long>`

#### Scenario: Manual match ViewModel resolves provider name
- **WHEN** `ManualMatchWindowViewModel` loads the display name for `CurrentRecord.ProviderId`
- **THEN** it delegates to `IProviderService` instead of resolving `IRepository<Provider, int>`

### Requirement: Client C# methods MUST use named records instead of tuples
Methods in `MaterialClient` source projects MUST return named `record` types rather than C# `ValueTuple` / `Tuple` types.

#### Scenario: Image viewer computes fit size
- **WHEN** `ImageViewerWindow` calculates the fit maximum width and height for the viewport
- **THEN** `GetFitMaxSize` returns a named `FitMaxSize` record

#### Scenario: Hikvision LPR service parses listen endpoint URL
- **WHEN** `HikvisionLprService` parses the configured listen URL into host IP and port
- **THEN** `ParseUrl` returns a named `ParsedListenEndpoint` record

### Requirement: MaterialClient repository root MUST NOT keep retired scaffolding or archive blobs
The `MaterialClient` repository root MUST NOT track deprecated `.specify/` scaffolding or historical `archive/` tarballs, while preserving each product's EF Core `Migrations/` directories.

#### Scenario: Root directory audit
- **WHEN** inspecting tracked files at the root of `repos/MaterialClient`
- **THEN** `.specify/` and `archive/` are absent, and each product's `Migrations/` directories remain intact

