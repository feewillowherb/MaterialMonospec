## MODIFIED Requirements

### Requirement: Redis is the live store for connection and device current state

UrbanManagement SHALL use Redis (via ABP `IDistributedCache` / StackExchange.Redis) as the **authoritative live store** for desktop client connection state and device online current-state on SignalR hot paths. The default connection SHALL target `127.0.0.1:6379` with a configured key prefix (e.g. `UM:`). This capability SHALL NOT introduce a SignalR Redis backplane. **Online** keys SHALL use a short live TTL; **offline** connection keys SHALL use a longer retention TTL (default seven days). Management queries MAY fall back to EF offline shells per `device-online-status-persistence` when Redis misses.

#### Scenario: Default local Redis endpoint

- **WHEN** `Redis:Configuration` is omitted or set to the documented default
- **THEN** the application SHALL connect to Redis at `127.0.0.1:6379`
- **AND** live connection/device keys SHALL be written and read through that Redis instance

#### Scenario: Online keys use short TTL aligned with SignalR timeout

- **WHEN** a client is marked connected or a qualifying `UploadStatus` refreshes an online connection entry
- **THEN** that live online key SHALL carry a TTL of at least approximately twice the configured `ClientTimeoutInterval` (or a documented equivalent)

#### Scenario: Offline keys use retention TTL

- **WHEN** a client is marked disconnected in Redis
- **THEN** that connection key SHALL remain with `IsConnected = false` and a TTL of the configured offline retention (default seven days)
- **AND** the connection registry TTL SHALL be long enough that offline entries remain discoverable for that retention window

#### Scenario: No SignalR Redis backplane required

- **WHEN** SignalR hubs are configured for MaterialClient device status
- **THEN** this capability SHALL NOT require `AddStackExchangeRedis` (or equivalent) as a SignalR scale-out backplane

#### Scenario: Redis unavailable is observable

- **WHEN** Redis at the configured endpoint is not running or refuses connections
- **THEN** live-store write operations SHALL fail in an observable way (host logs / exceptions)
- **AND** the system SHALL NOT silently fall back to in-process memory cache for live writes
- **AND** read paths MAY still use EF offline fallback for badges when Redis reads miss or fail, per `device-online-status-persistence`
