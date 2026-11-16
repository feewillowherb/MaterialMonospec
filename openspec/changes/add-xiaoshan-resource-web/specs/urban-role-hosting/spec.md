## MODIFIED Requirements

### Requirement: Service projects

UrbanManagement SHALL consist of the shared libraries `UrbanManagement.Core` and `UrbanManagement.Hosting`, the gateway `UrbanManagement.Gateway`, and the service projects `UrbanManagement.Ingest`, `UrbanManagement.Attachment`, `UrbanManagement.Realtime`, `UrbanManagement.Admin`, `UrbanManagement.Worker`, `UrbanManagement.Migrator`, and `UrbanManagement.XiaoShanResource`, all in the UrbanManagement repository. Each service project SHALL have its own entry point and SHALL be published on its own. A service project SHALL NOT reference another service project; contracts used by more than one service SHALL live in Core. `UrbanManagement.XiaoShanResource` SHALL NOT reference `UrbanManagement.Admin`, `UrbanManagement.Hosting`, or `UrbanManagement.Core`. Its SSO login types SHALL stay inside that project.

#### Scenario: Published service contains only its own service assembly

- **WHEN** `UrbanManagement.Ingest` is published
- **THEN** the output SHALL contain `UrbanManagement.Ingest.dll`, `UrbanManagement.Hosting.dll` and `UrbanManagement.Core.dll` and no other `UrbanManagement.<Service>.dll`

#### Scenario: Package ownership

- **WHEN** the services are published
- **THEN** `tusdotnet` SHALL be present only in Attachment and the ABP Blazor Server package only in Admin

#### Scenario: XiaoShanResource publish has no other service assembly

- **WHEN** `UrbanManagement.XiaoShanResource` is published
- **THEN** the output SHALL contain `UrbanManagement.XiaoShanResource.dll`
- **AND** the output SHALL NOT contain `UrbanManagement.Admin.dll`, `UrbanManagement.Hosting.dll`, or `UrbanManagement.Core.dll`

### Requirement: Service-owned endpoints and auto API

Each service SHALL expose ABP auto API controllers only for its own Core application service types. Ingest SHALL expose `UrbanWeighingRecordAppService`, `UrbanCheckpointPassageAppService` and `UrbanFinishedProductPassageAppService`. Attachment SHALL expose `UrbanAttachmentAppService`. Realtime SHALL expose `ClientLogAppService`. Admin SHALL expose every Core application service except `ClientLogAppService` and `UrbanAuthActivateAppService`. Worker SHALL expose none. XiaoShanResource SHALL expose no Core application service. Only Attachment SHALL map tus. Only Realtime SHALL map `/hubs/devicestatus` and `/ClientLogs`. Only Admin SHALL map the Blazor hub and the Blazor fallback page. Every web service SHALL map `/health/live` and `/health/ready`. XiaoShanResource SHALL map those health endpoints without requiring the UrbanManagement database.

#### Scenario: Realtime has no admin pages

- **WHEN** `GET /` is sent to the Realtime service
- **THEN** it SHALL answer 404

#### Scenario: Ingest has no tus

- **WHEN** `OPTIONS /api/urban-attachment/tus/` is sent to the Ingest service
- **THEN** it SHALL NOT be answered by a tus endpoint

#### Scenario: XiaoShanResource has no Blazor hub

- **WHEN** a request is sent to `/_blazor` on XiaoShanResource
- **THEN** it SHALL NOT be served by a Blazor hub
