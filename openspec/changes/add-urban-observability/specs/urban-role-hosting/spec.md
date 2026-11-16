## MODIFIED Requirements

### Requirement: Service projects

UrbanManagement SHALL consist of the shared libraries `UrbanManagement.Core`, `UrbanManagement.Hosting` and `UrbanManagement.Telemetry`, the gateway `UrbanManagement.Gateway`, and the service projects `UrbanManagement.Ingest`, `UrbanManagement.Attachment`, `UrbanManagement.Realtime`, `UrbanManagement.Admin`, `UrbanManagement.Worker` and `UrbanManagement.Migrator`, all in the UrbanManagement repository. Each service project SHALL have its own entry point and SHALL be published on its own. A service project SHALL NOT reference another service project; contracts used by more than one service SHALL live in Core. `UrbanManagement.Telemetry` SHALL NOT be a runnable service, SHALL NOT reference `UrbanManagement.Core` or `UrbanManagement.Hosting`, and SHALL be referenced by Hosting, the gateway, and `UrbanManagement.XiaoShanResource` for OpenTelemetry registration.

#### Scenario: Published service contains only its own service assembly

- **WHEN** `UrbanManagement.Ingest` is published
- **THEN** the output SHALL contain `UrbanManagement.Ingest.dll`, `UrbanManagement.Hosting.dll`, `UrbanManagement.Core.dll` and `UrbanManagement.Telemetry.dll` and no other `UrbanManagement.<Service>.dll`

#### Scenario: Package ownership

- **WHEN** the services are published
- **THEN** `tusdotnet` SHALL be present only in Attachment and the ABP Blazor Server package only in Admin

#### Scenario: Telemetry library has no database

- **WHEN** `UrbanManagement.Telemetry` is built
- **THEN** it SHALL NOT reference `UrbanManagement.Core` or `UrbanManagement.Hosting`
