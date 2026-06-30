## MODIFIED Requirements

### Requirement: Real-time connection status updates via SignalR

ProjectManagement.razor SHALL subscribe to SignalR `ClientConnectionUpdate` events to refresh client connection status in real-time, with 30-second fallback polling when SignalR is disconnected.

#### Scenario: Client connects while page is open

- **WHEN** a client connects and the `ClientConnectionUpdate` SignalR event fires
- **THEN** the corresponding project row's client status badge SHALL update to "在线" without full page reload

#### Scenario: SignalR disconnected fallback

- **WHEN** SignalR connection is lost for more than 30 seconds
- **THEN** the system SHALL fall back to polling `GetClientListAsync` every 30 seconds to refresh status

#### Scenario: Browser joins client_connection group on hub connect

- **WHEN** `ProjectManagement.razor` successfully starts its HubConnection to `/hubs/devicestatus`
- **THEN** SHALL invoke Hub method `SubscribeClientConnection` to join the `client_connection` group
- **AND** SHALL re-invoke `SubscribeClientConnection` on `Reconnected`
- **AND** SHALL receive `ClientConnectionUpdate` payloads broadcast to that group
