# urban-gateway Delta Specification

## ADDED Requirements

### Requirement: Static Velopack OTA Update Feed Hosting

`UrbanManagement.Gateway` SHALL serve static Velopack OTA release assets under `/updates` from the directory configured by `OtaFeed:RootPath` (defaulting to `{ContentRootPath}/Updates`), supporting `.json`, `.nupkg`, `.exe`, `.zip`, and extensionless `RELEASES` files, and SHALL return `404 Not Found` for missing `/updates/**` paths without proxying them to `um-admin`.

#### Scenario: Velopack release manifest and package served under /updates/urban

- **WHEN** a client requests `GET /updates/urban/releases.win.json` or `GET /updates/urban/MaterialClient.Urban-2.0.1-full.nupkg` and the file exists under `OtaFeed:RootPath`
- **THEN** `UrbanManagement.Gateway` SHALL return `200 OK` with the file contents
- **AND** manifest responses (`*.json`, `RELEASES`) SHALL include `Cache-Control: no-cache`

#### Scenario: Missing OTA asset returns 404 instead of Blazor fallback HTML

- **WHEN** a client requests `GET /updates/urban/non-existent.nupkg`
- **THEN** `UrbanManagement.Gateway` SHALL return `404 Not Found` directly without forwarding the request to the `admin` YARP cluster
