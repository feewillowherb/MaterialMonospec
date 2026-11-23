## MODIFIED Requirements

### Requirement: Project catalog API provides paged ProId and ProName
`GET /Api/ProjectCatalog/ListProjects` SHALL accept optional `productCode` with values 5001 and 5020 and return the existing paged response shape for the requested product. Eligible projects SHALL have a valid project GUID, a non-deleted project and a non-deleted product authorization with a non-empty access code. When the same product has multiple authorizations the catalog SHALL use the latest one.

#### Scenario: Legacy catalog request
- **WHEN** an authorized consumer omits `productCode` or explicitly selects 5001
- **THEN** the response SHALL contain only eligible 5001 projects in area 330109

#### Scenario: Recycle catalog request
- **WHEN** a Recycle catalog consumer selects 5020
- **THEN** the response SHALL contain only eligible 5020 projects in the configured project allowlist
- **AND** an authorization for product 5001 on the same project SHALL NOT be returned

#### Scenario: Unsupported product
- **WHEN** an authorized catalog consumer supplies an invalid or unsupported `productCode`
- **THEN** the API SHALL return HTTP 400

### Requirement: Project catalog API requires service API key
Requests for 5001 SHALL follow the existing service-auth policy for `X-Api-Key`. Requests for 5020 SHALL use a dedicated 5020 catalog API key in that header, even if general service authentication is disabled. A shared or missing 5020 key SHALL NOT grant Recycle catalog access.

#### Scenario: Existing service key
- **WHEN** a consumer supplies the existing valid service key for a 5001 request
- **THEN** the request SHALL execute the existing catalog query

#### Scenario: Recycle catalog key
- **WHEN** a consumer requests 5020 with the distinct configured Recycle catalog key
- **THEN** the request SHALL execute the allowlisted catalog query

#### Scenario: Unauthorized Recycle request
- **WHEN** a consumer requests 5020 with a missing or invalid key, or the Recycle key is unconfigured or equals the general service key
- **THEN** the API SHALL return HTTP 401 without querying the catalog
