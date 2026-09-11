## ADDED Requirements

### Requirement: Distributed cache backed by Redis

UrbanManagement SHALL use Redis as the ABP distributed cache store for existing `IDistributedCache` usages (including device status, client connection, and client registry cache items). The default connection SHALL target the local Windows Redis instance at `127.0.0.1:6379` (Redis default port). The host SHALL continue to use the configured cache key prefix (e.g. `UM:`) and SHALL NOT introduce a SignalR Redis backplane as part of this capability.

#### Scenario: Default local Redis endpoint

- **WHEN** `Redis:Configuration` is omitted or set to the documented default
- **THEN** the application SHALL connect to Redis at `127.0.0.1:6379`
- **AND** cache keys for device/client status SHALL be written and read through that Redis instance

#### Scenario: Windows Redis memory ceiling is an ops constraint

- **WHEN** the deployment uses [tporadowski/redis](https://github.com/tporadowski/redis) on Windows for UrbanManagement
- **THEN** operators SHALL configure Redis with approximately **100MB** `maxmemory` (and an eviction policy such as `allkeys-lru`)
- **AND** the application SHALL NOT require a second application-side memory quota that replaces that Redis server limit

#### Scenario: No SignalR Redis backplane required

- **WHEN** SignalR hubs are configured for MaterialClient device status
- **THEN** this capability SHALL NOT require `AddStackExchangeRedis` (or equivalent) as a SignalR scale-out backplane
- **AND** single-host SignalR MAY continue without Redis pub/sub for hub fan-out

#### Scenario: Redis unavailable is observable

- **WHEN** Redis at the configured endpoint is not running or refuses connections
- **THEN** cache operations SHALL fail in an observable way (host logs / exceptions)
- **AND** the system SHALL NOT silently fall back to an in-process memory cache that masks the missing Redis dependency
