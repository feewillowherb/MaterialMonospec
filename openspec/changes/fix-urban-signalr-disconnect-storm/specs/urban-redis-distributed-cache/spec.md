## ADDED Requirements

### Requirement: Redis is the live store for connection and device current state

UrbanManagement SHALL use Redis (via ABP `IDistributedCache` / StackExchange.Redis) as the **authoritative live store** for desktop client connection state and device online current-state used by SignalR hot paths and management UI queries. The default connection SHALL target `127.0.0.1:6379`. The host SHALL use a configured key prefix (e.g. `UM:`). This capability SHALL NOT introduce a SignalR Redis backplane.

#### Scenario: Default local Redis endpoint

- **WHEN** `Redis:Configuration` is omitted or set to the documented default
- **THEN** the application SHALL connect to Redis at `127.0.0.1:6379`
- **AND** live connection/device keys SHALL be written and read through that Redis instance

#### Scenario: Windows Redis memory ceiling is an ops constraint

- **WHEN** the deployment uses [tporadowski/redis](https://github.com/tporadowski/redis) on Windows for UrbanManagement
- **THEN** operators SHALL configure Redis with approximately **100MB** `maxmemory` (and an eviction policy such as `allkeys-lru`)
- **AND** the application SHALL NOT require a second application-side memory quota that replaces that Redis server limit

#### Scenario: Live keys use TTL aligned with SignalR timeout

- **WHEN** a client is marked connected or a device status is updated in Redis
- **THEN** the corresponding live keys SHALL carry a TTL of at least approximately twice the configured `ClientTimeoutInterval` (or a documented equivalent)
- **AND** qualifying activity (connect / `UploadStatus`) SHALL refresh that TTL

#### Scenario: No SignalR Redis backplane required

- **WHEN** SignalR hubs are configured for MaterialClient device status
- **THEN** this capability SHALL NOT require `AddStackExchangeRedis` (or equivalent) as a SignalR scale-out backplane

#### Scenario: Redis unavailable is observable

- **WHEN** Redis at the configured endpoint is not running or refuses connections
- **THEN** live-store operations SHALL fail in an observable way (host logs / exceptions)
- **AND** the system SHALL NOT silently fall back to in-process memory cache
- **AND** the system SHALL NOT silently fall back to SQLite for live connection badges
