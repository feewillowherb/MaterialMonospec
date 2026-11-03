## ADDED Requirements

### Requirement: Gateway route table

The UrbanManagement repository SHALL contain a YARP gateway application `UrbanManagement.Gateway` that forwards requests to an `ingest` cluster and a `console` cluster. Path matching SHALL be case-insensitive and SHALL be evaluated in this order:

1. `/hubs/devicestatus/{**}` → console
2. `/_blazor/{**}` → console
3. `/api/urban/auth/{**}` → ingest
4. `/Api/Post` → ingest
5. `/api/urban-attachment/{**}` → ingest
6. `/api/app/urban-attachment/upload` → ingest
7. `/api/app/urban-weighing-record/receive` → ingest
8. `/api/app/urban-weighing-record/pending-server-approval-sync` → ingest
9. `/api/app/urban-weighing-record/ack-approval-sync` → ingest
10. `/api/app/urban-checkpoint-passage/receive` → ingest
11. `/api/app/urban-finished-product-passage/receive` → ingest
12. `/api/client-log/{**}` and `/ClientLogs/{**}` → console
13. `/api/{**}` → console
14. `/{**}` → console

The gateway SHALL forward the original path and query unchanged.

#### Scenario: Legacy upload path

- **WHEN** a client sends `POST /api/post`
- **THEN** the gateway SHALL forward it to the ingest cluster with path `/api/post`

#### Scenario: Weighing receive goes to ingest

- **WHEN** a client sends `POST /api/app/urban-weighing-record/receive`
- **THEN** the gateway SHALL forward it to the ingest cluster

#### Scenario: Other weighing APIs go to console

- **WHEN** a request targets `/api/app/urban-weighing-record` with any path other than routes 7–9
- **THEN** the gateway SHALL forward it to the console cluster

### Requirement: Transparent forwarding

The gateway SHALL forward the original `Host` header and add `X-Forwarded-For` and `X-Forwarded-Proto`. It SHALL NOT limit the request body size, SHALL allow a backend response activity timeout of at least 5 minutes, and SHALL support WebSocket upgrades on the console routes.

#### Scenario: tus location keeps the client host

- **WHEN** a client creates a tus upload through the gateway with `Host: 191.12.234.212:5333`
- **THEN** the `Location` header returned to the client SHALL use the host `191.12.234.212:5333`

### Requirement: Gateway health

The gateway SHALL answer `GET /health/gateway` itself with HTTP 200 whenever it is running. It SHALL actively probe `GET /health/ready` on each backend destination and stop forwarding to a destination that is reported unhealthy.

#### Scenario: Gateway liveness

- **WHEN** the gateway process is running, whatever the backend state
- **THEN** `GET /health/gateway` SHALL return HTTP 200
