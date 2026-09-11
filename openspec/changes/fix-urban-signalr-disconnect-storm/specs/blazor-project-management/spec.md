## MODIFIED Requirements

### Requirement: Real-time client status via SignalR

ProjectManagement.razor MUST NOT subscribe to DeviceStatus SignalR for client status updates and MUST NOT use polling fallback. Client status badges SHALL be loaded via `IDeviceStatusAppService` (live state from Redis) when the page loads or when the user explicitly refreshes list data (manual refresh and/or user-driven reload such as search/paging). See `project-client-merge` for merge semantics.

#### Scenario: Status loaded without live hub push

- **WHEN** the project management page loads or the user triggers a manual/list reload
- **THEN** the corresponding project row client status badges SHALL update from AppService data backed by Redis live state
- **AND** MUST NOT require a `ClientConnectionUpdate` SignalR event
