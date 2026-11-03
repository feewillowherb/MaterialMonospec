## MODIFIED Requirements

### Requirement: Gateway route table

The UrbanManagement repository SHALL contain a YARP gateway application `UrbanManagement.Gateway` that forwards requests to the clusters `ingest`, `attachment`, `realtime` and `admin`. The `ingest` cluster SHALL have two destinations balanced round robin; the other clusters SHALL have one destination each. Path matching SHALL be case-insensitive and SHALL be evaluated in this order:

1. `/hubs/devicestatus/{**}` → realtime
2. `/_blazor/{**}` → admin
3. `/api/urban/auth/{**}` → ingest
4. `/Api/Post` → ingest
5. `/api/urban-attachment/{**}` → attachment
6. `/api/app/urban-attachment/upload` → attachment
7. `/api/app/urban-weighing-record/receive` → ingest
8. `/api/app/urban-weighing-record/pending-server-approval-sync` → ingest
9. `/api/app/urban-weighing-record/ack-approval-sync` → ingest
10. `/api/app/urban-checkpoint-passage/receive` → ingest
11. `/api/app/urban-finished-product-passage/receive` → ingest
12. `/api/client-log/{**}`, `/ClientLogs/{**}` and `/api/app/client-log/{**}` → realtime
13. `/api/{**}` → admin
14. `/{**}` → admin

The gateway SHALL forward the original path and query unchanged, and SHALL answer any path under `/internal` with HTTP 404 without forwarding it.

#### Scenario: Legacy upload path

- **WHEN** a client sends `POST /api/post`
- **THEN** the gateway SHALL forward it to the ingest cluster with path `/api/post`

#### Scenario: Weighing receive goes to ingest

- **WHEN** a client sends `POST /api/app/urban-weighing-record/receive`
- **THEN** the gateway SHALL forward it to the ingest cluster

#### Scenario: Other weighing APIs go to admin

- **WHEN** a request targets `/api/app/urban-weighing-record` with any path other than routes 7–9
- **THEN** the gateway SHALL forward it to the admin cluster

#### Scenario: tus goes to attachment

- **WHEN** a client sends `OPTIONS /api/urban-attachment/tus/`
- **THEN** the gateway SHALL forward it to the attachment cluster

#### Scenario: Internal API is not public

- **WHEN** a client sends `GET /internal/client-log/online-clients` to the gateway
- **THEN** the gateway SHALL answer 404
