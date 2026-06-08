## ADDED Requirements

### Requirement: Project catalog API provides paged ProId and ProName
The `FdSoft.BasePlatform.PublicApi` system SHALL provide a read-only endpoint `GET /Api/ProjectCatalog/ListProjects` that returns paged project catalog data containing only `ProId` and `ProName`.

#### Scenario: Return paged project catalog
- **WHEN** an authorized client calls `/Api/ProjectCatalog/ListProjects?pageIndex=1&pageSize=500`
- **THEN** the API SHALL return a success response containing `totalCount` and `items`
- **AND** each item SHALL include `proId` and `proName`
- **AND** the API SHALL NOT include sensitive fields such as secret or organization codes

### Requirement: Project catalog API requires service API key
The project catalog API SHALL require a valid `X-Api-Key` header and SHALL reject unauthorized requests.

#### Scenario: Request without API key
- **WHEN** a client calls `/Api/ProjectCatalog/ListProjects` without `X-Api-Key`
- **THEN** the API SHALL return HTTP 401
- **AND** the response SHALL indicate unauthorized access

#### Scenario: Request with invalid API key
- **WHEN** a client calls `/Api/ProjectCatalog/ListProjects` with an invalid `X-Api-Key`
- **THEN** the API SHALL return HTTP 401
- **AND** the request SHALL NOT reach the controller action

#### Scenario: Request with valid API key
- **WHEN** a client calls `/Api/ProjectCatalog/ListProjects` with a valid `X-Api-Key`
- **THEN** the API SHALL pass authorization middleware and execute the catalog query

### Requirement: Project catalog API enforces pagination bounds
The project catalog API SHALL apply bounded pagination with default and maximum page size constraints.

#### Scenario: Missing paging parameters
- **WHEN** a client omits `pageIndex` or `pageSize`
- **THEN** the API SHALL use default values (`pageIndex=1`, `pageSize=500`)

#### Scenario: Oversized page request
- **WHEN** a client requests `pageSize` above the configured maximum
- **THEN** the API SHALL clamp to the maximum allowed size before querying data
