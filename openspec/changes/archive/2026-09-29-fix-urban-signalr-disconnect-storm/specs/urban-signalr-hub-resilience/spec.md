## ADDED Requirements

### Requirement: Disconnect path does not write SQLite

When a mapped DeviceStatus SignalR connection disconnects, UrbanManagement MUST update live offline state in Redis only and MUST NOT perform EF `SaveChanges` / repository upserts against `ClientOnlineStatus` or device-online tables on that disconnect path, so SQLite is not contended by disconnect storms.

#### Scenario: Offline update after ClientTimeoutInterval disconnect

- **WHEN** a hub connection ends with `ClientTimeoutInterval` (or equivalent connection abort)
- **AND** the connection was mapped to a valid `(ProId, ClientId)`
- **THEN** the system SHALL update that instance's live state in Redis (offline or key removal)
- **AND** SHALL NOT upsert SQLite online/device tables for that disconnect event

#### Scenario: Disconnect failures are not SQLite cancel storms

- **WHEN** disconnect handling fails (e.g. Redis I/O error)
- **THEN** the host SHALL log appropriately without generating recurring Error-level `TaskCanceledException` storms from EF `SaveChanges` on the abort token
- **AND** Redis/infrastructure failures MAY still be logged as Error/Warning

### Requirement: Configurable SignalR keep-alive and client timeout

The UrbanManagement host SHALL bind SignalR keep-alive and client timeout from the `SignalR` configuration section and apply them to the SignalR server (and Blazor hub options when separately configured), with `ClientTimeoutInterval` greater than `KeepAliveInterval`.

#### Scenario: Defaults favor fewer false timeouts under load

- **WHEN** configuration omits explicit timeout values
- **THEN** the host SHALL use defaults where keep-alive is at most half of client timeout (e.g. keep-alive 15s, client timeout 60s)
- **AND** operators MAY override both via configuration without code changes

### Requirement: Project management Web UI does not use DeviceStatus SignalR

The Blazor project management page MUST NOT open a SignalR client connection to `/hubs/devicestatus`, MUST NOT subscribe to `ClientConnectionUpdate` for automatic refresh, and MUST NOT run background polling to refresh client connection status. Client status on that page SHALL update only when the user navigates/loads the page or explicitly triggers a manual refresh (including existing user-driven actions that reload list data, such as search or paging). Live badge data SHALL come from AppService/HTTP backed by Redis. The server MUST continue to expose `DeviceStatusHub` for MaterialClient desktop clients. Blazor Server circuit transport (`MapBlazorHub`) remains required and is out of scope for removal.

#### Scenario: No browser DeviceStatus hub connection

- **WHEN** a user opens Project Management in the browser
- **THEN** the page MUST NOT start a `HubConnection` to `/hubs/devicestatus`
- **AND** MUST NOT invoke `SubscribeClientConnection`

#### Scenario: No background polling for client status

- **WHEN** Project Management remains open without user action
- **THEN** the page MUST NOT periodically call `GetClientListAsync` (or equivalent) on a timer solely to refresh connection badges

#### Scenario: Manual or navigation-driven refresh still works

- **WHEN** the user loads/reloads the page or performs an explicit refresh / search / page-change that reloads project list data
- **THEN** client connection badges SHALL reflect current live data from `IDeviceStatusAppService` (HTTP / AppService over Redis), not from a live hub push
