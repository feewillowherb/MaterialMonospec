## MODIFIED Requirements

### Requirement: Real-time connection status updates via SignalR

ProjectManagement.razor MUST NOT subscribe to SignalR `ClientConnectionUpdate` events and MUST NOT fall back to timed polling for client connection status. Connection badges SHALL refresh only when list data is loaded through user navigation or an explicit manual refresh (including user-driven search/paging reloads). Desktop clients continue to use `DeviceStatusHub` independently of the Blazor page.

#### Scenario: Status refresh without SignalR while page is open

- **WHEN** a desktop client connects or disconnects while Project Management is open
- **THEN** the project row badge is NOT required to update until the user reloads list data manually or via an explicit refresh action
- **AND** the page MUST NOT auto-update solely from a `ClientConnectionUpdate` event

#### Scenario: No SignalR disconnected polling fallback

- **WHEN** the project management page is open
- **THEN** the system MUST NOT poll `GetClientListAsync` every 30 seconds (or any similar background interval) to refresh connection status
